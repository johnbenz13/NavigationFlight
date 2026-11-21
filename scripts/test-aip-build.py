"""Exercise chart staging and the one-command build with disposable tiny releases."""

from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import importlib.util
import json
from pathlib import Path
from subprocess import CompletedProcess
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "prepare_aip_charts", Path(__file__).with_name("prepare-aip-charts.py")
)
charts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(charts)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class AIPBuildTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        (self.root / "Config").mkdir()
        self.generated = self.root / ".generated"
        self.cache = self.generated / "AIPCharts"
        self.pin_path = self.root / "Config/aip-charts-pin.json"
        self.first, self.first_pdf = self.seed("domestic-aip-fixture")
        self.requests = []
        self.assets = self.first

    def seed(self, release, sequence=1):
        pdf = f"%PDF-1.4\n{release}\n%%EOF\n".encode()
        manifest = json.dumps({
            "schemaVersion": 2,
            "releaseId": release,
            "artifacts": [{
                "id": "fixture",
                "destination": "AIPCharts/pdf/fixture.pdf",
                "representation": "pdf",
                "bytes": len(pdf),
                "sha256": sha256(pdf),
            }],
        }).encode()
        base = charts.RELEASES + release
        self.pin_path.write_text(json.dumps({
            "schemaVersion": 1,
            "releaseId": release,
            "sequence": sequence,
            "manifestUrl": base + "/manifest.json",
            "manifestSha256": sha256(manifest),
        }))
        return {base + "/manifest.json": manifest, base + "/artifact-fixture": pdf}, pdf

    def fetch(self, url, destination, limit):
        self.requests.append(url)
        self.assertIn(url, self.assets)
        data = self.assets[url]
        self.assertLessEqual(len(data), limit)
        destination.write_bytes(data)

    def prepare(self, fetch=None):
        with charts.checkout_lock(self.root):
            charts.prepare(self.root, self.fetch if fetch is None else fetch)

    def test_cold_build_uses_exact_pin_and_warm_cache_needs_no_requests(self):
        self.assets["https://example.invalid/latest"] = b"new edition"
        self.prepare()
        self.assertEqual(self.requests, list(self.first)[:2])
        self.assertEqual((self.cache / "pdf/fixture.pdf").read_bytes(), self.first_pdf)
        self.assertIn(
            "$(SRCROOT)/.generated/AIPCharts/pdf/fixture.pdf",
            (self.generated / "AIPCharts.xcfilelist").read_text(),
        )
        offline = Mock(side_effect=OSError("chart endpoint unavailable"))
        (self.generated / "AIPCharts.xcfilelist").unlink()
        self.prepare(offline)
        offline.assert_not_called()
        self.assertTrue((self.generated / "AIPCharts.xcfilelist").is_file())

    def test_corrupt_cache_is_repaired(self):
        self.prepare()
        (self.cache / "pdf/fixture.pdf").write_bytes(b"!" * len(self.first_pdf))
        self.requests.clear()
        self.prepare()
        self.assertEqual(self.requests, list(self.first))
        self.assertEqual((self.cache / "pdf/fixture.pdf").read_bytes(), self.first_pdf)

    def test_failed_replacement_preserves_previous_snapshot_and_can_retry(self):
        self.prepare()
        previous_index = (self.cache / "index.json").read_bytes()
        inputs = (self.generated / "AIPCharts.xcfilelist").read_bytes()
        self.assets, next_pdf = self.seed("domestic-aip-next", sequence=2)
        pdf_url = next(url for url in self.assets if url.endswith("artifact-fixture"))
        self.assets[pdf_url] = b"!" * len(next_pdf)
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.prepare()
        self.assertEqual((self.cache / "index.json").read_bytes(), previous_index)
        self.assertEqual((self.cache / "pdf/fixture.pdf").read_bytes(), self.first_pdf)
        self.assertEqual((self.generated / "AIPCharts.xcfilelist").read_bytes(), inputs)
        self.assets[pdf_url] = next_pdf
        self.prepare()
        self.assertEqual((self.cache / "pdf/fixture.pdf").read_bytes(), next_pdf)
        self.assertFalse((self.generated / "AIPCharts.previous").exists())

    def test_cold_failure_leaves_no_bundle_and_never_invokes_xcode(self):
        fetch = Mock(side_effect=OSError("chart endpoint unavailable"))
        with self.assertRaisesRegex(OSError, "endpoint unavailable"):
            self.prepare(fetch)
        self.assertFalse(self.cache.exists())
        self.assertFalse((self.generated / "AIPCharts.xcfilelist").exists())
        self.assertEqual(list(self.generated.glob("aip-stage-*")), [])
        run = Mock()
        with patch.object(charts, "prepare", side_effect=OSError("chart endpoint unavailable")):
            with self.assertRaises(OSError):
                charts.build(self.root, [], run)
        run.assert_not_called()

    def test_manifest_mismatch_is_rejected_before_downloading_any_pdf(self):
        url = next(iter(self.assets))
        self.assets[url] = b"{}"
        with self.assertRaisesRegex(ValueError, "index SHA-256"):
            self.prepare()
        self.assertEqual(self.requests, [url])
        self.assertFalse(self.cache.exists())

    def test_interrupted_directory_swap_recovers_cached_snapshot(self):
        self.prepare()
        previous = self.generated / "AIPCharts.previous"
        self.cache.rename(previous)
        offline = Mock(side_effect=OSError("offline"))
        self.prepare(offline)
        offline.assert_not_called()
        self.assertFalse(previous.exists())
        self.assertEqual((self.cache / "pdf/fixture.pdf").read_bytes(), self.first_pdf)

    def test_concurrent_preparations_share_one_verified_download(self):
        started = threading.Event()
        release = threading.Event()

        def held_fetch(url, destination, limit):
            if url.endswith("/manifest.json"):
                started.set()
                self.assertTrue(release.wait(5))
            self.fetch(url, destination, limit)

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.prepare, held_fetch)
            try:
                self.assertTrue(started.wait(5))
                second = pool.submit(self.prepare)
                with (self.generated / "aip-charts.lock").open("ab") as lock:
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            finally:
                release.set()
            first.result(timeout=5)
            second.result(timeout=5)
        self.assertEqual(self.requests, list(self.first))

    def test_build_hydrates_lfs_pointer_and_forwards_xcode_overrides(self):
        path = self.root / charts.MAP
        path.parent.mkdir(parents=True)
        path.write_bytes(charts.LFS_POINTER + b"\n")

        def xcode_or_lfs(command, **kwargs):
            self.assertEqual(kwargs["cwd"], self.root)
            if command[0] == "git":
                self.assertEqual(command, ["git", "lfs", "pull", f"--include={charts.MAP}", "--exclude="])
                path.write_bytes(charts.PMTILES_HEADER)
            else:
                self.assertEqual(command, [
                    "/usr/bin/xcodebuild", "-project", "NavigationFlight.xcodeproj", "-scheme", "NavigationFlight",
                    "-destination", "platform=iOS Simulator,id=fixture",
                    "-configuration", "Release", "-derivedDataPath", "/tmp/navigationflight-test", "build",
                ])
            return CompletedProcess(command, 0)

        options = [
            "-destination", "platform=iOS Simulator,id=fixture",
            "-configuration", "Release", "-derivedDataPath", "/tmp/navigationflight-test", "build",
        ]
        run = Mock(side_effect=xcode_or_lfs)
        with patch.object(charts, "prepare") as prepare:
            self.assertEqual(charts.build(self.root, options, run), 0)
        prepare.assert_called_once_with(self.root)
        self.assertEqual(run.call_count, 2)
        self.assertIn("generic/platform=iOS Simulator", charts.xcode_command(self.root, []))

    def test_download_redirect_cannot_leave_approved_https_hosts(self):
        with self.assertRaisesRegex(ValueError, "unexpected AIP download"):
            charts.AssetRedirects().redirect_request(None, None, 302, "", {}, "https://example.invalid/asset")
        with self.assertRaisesRegex(ValueError, "unexpected AIP download"):
            charts.check_asset_url("http://github.com/asset")


if __name__ == "__main__":
    unittest.main()
