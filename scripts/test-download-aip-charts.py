"""Deterministic release staging checks without GitHub access."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("downloader", Path(__file__).with_name("download-aip-charts.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DownloadTests(unittest.TestCase):
    def exercise(self, corrupt=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Config").mkdir()
            (root / "scripts").mkdir()
            (root / "scripts/verify-aip-charts.py").write_bytes(Path(__file__).with_name("verify-aip-charts.py").read_bytes())
            pdf = b"chart fixture"
            manifest = json.dumps({"schemaVersion": 2, "releaseId": "test", "artifacts": [{
                "id": "test", "representation": "pdf", "destination": "AIPCharts/pdf/test.pdf",
                "bytes": len(pdf), "sha256": hashlib.sha256(pdf).hexdigest(),
            }]}).encode()
            (root / "Config/aip-charts-pin.json").write_text(json.dumps({
                "schemaVersion": 1, "releaseId": "test", "manifestSha256": hashlib.sha256(manifest).hexdigest(),
            }))
            previous = root / ".generated/AIPCharts"
            previous.mkdir(parents=True)
            (previous / "sentinel").write_text("previous install")
            release = {"immutable": True, "assets": [{"name": name, "id": index} for index, name in enumerate(["manifest.json", "artifact-test"])]}

            def download(asset, destination):
                destination.write_bytes(manifest if asset["id"] == 0 else b"corrupt" if corrupt else pdf)

            with patch.object(module, "ROOT", root), patch.object(module.subprocess, "check_output", return_value=json.dumps(release).encode()), patch.object(module, "download", side_effect=download):
                if corrupt:
                    with self.assertRaises(ValueError):
                        module.prepare()
                    self.assertTrue((previous / "sentinel").exists())
                    self.assertFalse((root / ".generated/AIPCharts.xcfilelist").exists())
                else:
                    module.prepare()
                    self.assertEqual((previous / "pdf/test.pdf").read_bytes(), pdf)
                    self.assertIn("$(SRCROOT)/.generated/AIPCharts/pdf/test.pdf", (root / ".generated/AIPCharts.xcfilelist").read_text())

    def test_verified_release_installs(self):
        self.exercise()

    def test_corrupt_download_preserves_previous_install(self):
        self.exercise(corrupt=True)


if __name__ == "__main__":
    unittest.main()
