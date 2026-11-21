"""Prepare the pinned public chart snapshot and optionally run Xcode."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
import fcntl
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


ROOT = Path(__file__).resolve().parent.parent
RELEASES = "https://github.com/johnbenz13/fplnav-downloads/releases/download/"
ASSET_HOSTS = {
    "github.com", "release-assets.githubusercontent.com",
    "objects.githubusercontent.com", "github-releases.githubusercontent.com",
}
MAP = Path("NavigationFlight/Resources/Maps/navigation-north.pmtiles")
LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"
PMTILES_HEADER = b"PMTiles\x03"

# The same verifier also runs inside the Xcode build phase.
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("aip_verifier", ROOT / "scripts/verify-aip-charts.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def check_asset_url(url):
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.netloc not in ASSET_HOSTS:
        raise ValueError("unexpected AIP download host or protocol")


class AssetRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, url):
        check_asset_url(url)
        return super().redirect_request(request, response, code, message, headers, url)


def download(url, destination, limit):
    check_asset_url(url)
    request = Request(url, headers={"User-Agent": "NavigationFlight-AIP-build"})
    try:
        with build_opener(AssetRedirects()).open(request, timeout=30) as response:
            if response.status != 200:
                raise ValueError(f"expected HTTP 200, received {response.status}")
            with destination.open("xb") as output:
                remaining = limit
                while block := response.read(min(remaining + 1, 1024 * 1024)):
                    if len(block) > remaining:
                        raise ValueError("download exceeds the reviewed size")
                    output.write(block)
                    remaining -= len(block)
    except (OSError, ValueError) as error:
        raise ValueError(f"could not download {url}: {error}") from error


def manifest_url(pin):
    release_id = pin["releaseId"]
    sequence = pin["sequence"]
    if (
        pin["schemaVersion"] != 1
        or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,99}", release_id)
        or type(sequence) is not int or sequence <= 0
        or not re.fullmatch(r"[0-9a-f]{64}", pin["manifestSha256"])
    ):
        raise ValueError("invalid committed AIP chart pin")
    expected = f"{RELEASES}{release_id}/manifest.json"
    if pin["manifestUrl"] != expected:
        raise ValueError("the AIP pin must reference its immutable public release manifest")
    return expected


def fetch_snapshot(pin, stage, fetch):
    index = stage / "index.json"
    pdf_dir = stage / "pdf"
    pdf_dir.mkdir(parents=True)
    url = manifest_url(pin)
    fetch(url, index, verifier.MANIFEST_LIMIT)
    manifest = verifier.reviewed_index(pin, index.read_bytes())
    files = verifier.chart_files(manifest)
    release = url.rsplit("/", 1)[0]
    with ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [
            pool.submit(fetch, f"{release}/artifact-{asset['id']}", pdf_dir / name, asset["bytes"])
            for name, asset in files.items()
        ]
        try:
            for job in as_completed(jobs):
                job.result()
        except BaseException:
            for job in jobs:
                job.cancel()
            raise


def exists(path):
    return path.exists() or path.is_symlink()


def remove_backup(path):
    if not exists(path):
        return
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


@contextmanager
def checkout_lock(root):
    generated = root / ".generated"
    generated.mkdir(exist_ok=True)
    with (generated / "aip-charts.lock").open("ab") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield lock


def prepare(root, fetch=download):
    """Called with the checkout lock held. An unverified attempt never replaces the cache."""
    pin_path = root / "Config/aip-charts-pin.json"
    pin = json.loads(pin_path.read_bytes())
    manifest_url(pin)
    generated = root / ".generated"
    charts = generated / "AIPCharts"
    previous = generated / "AIPCharts.previous"
    inputs = generated / "AIPCharts.xcfilelist"

    if exists(previous) and not exists(charts):
        previous.rename(charts)
    try:
        files = verifier.verify(pin_path, charts)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Preparing pinned AIPCharts {pin['releaseId']} ({error})", flush=True)
    else:
        verifier.write_inputs(inputs, files)
        remove_backup(previous)
        print("Using verified cached AIPCharts", flush=True)
        return

    with tempfile.TemporaryDirectory(prefix="aip-stage-", dir=generated) as stage_directory:
        stage = Path(stage_directory) / "AIPCharts"
        fetch_snapshot(pin, stage, fetch)
        files = verifier.verify(pin_path, stage)

        remove_backup(previous)
        if exists(charts):
            charts.rename(previous)
        try:
            stage.rename(charts)
        except BaseException:
            if exists(previous) and not exists(charts):
                previous.rename(charts)
            raise
        verifier.write_inputs(inputs, files)
        remove_backup(previous)


def map_prefix(path):
    with path.open("rb") as stream:
        return stream.read(len(LFS_POINTER))


def prepare_map(root, run=subprocess.run):
    path = root / MAP
    prefix = map_prefix(path)
    if prefix.startswith(PMTILES_HEADER):
        return
    if prefix != LFS_POINTER:
        raise ValueError(f"{MAP} is not a PMTiles file or a Git LFS pointer")
    print(f"Fetching {MAP} with Git LFS", flush=True)
    result = run(
        ["git", "lfs", "pull", f"--include={MAP}", "--exclude="],
        cwd=root, check=False,
    )
    if result.returncode or not map_prefix(path).startswith(PMTILES_HEADER):
        raise ValueError("could not hydrate the cockpit basemap; install Git LFS and check normal Git repository access")


def xcode_command(root, arguments):
    options = {arg.split("=", 1)[0] for arg in arguments}
    command = ["/usr/bin/xcodebuild", "-project", "NavigationFlight.xcodeproj", "-scheme", "NavigationFlight"]
    if not options.intersection({"-destination", "-sdk"}):
        command += ["-destination", "generic/platform=iOS Simulator"]
    if "-derivedDataPath" not in options:
        command += ["-derivedDataPath", str(root / ".generated/DerivedData")]
    return command + arguments


def build(root, arguments, run=subprocess.run):
    with checkout_lock(root) as lock:
        prepare(root)
        prepare_map(root, run)
        result = run(xcode_command(root, arguments), cwd=root, check=False, pass_fds=(lock.fileno(),))
        return result.returncode


if __name__ == "__main__":
    try:
        arguments = sys.argv[1:]
        if arguments[:1] == ["--build"]:
            sys.exit(build(ROOT, arguments[1:]))
        if arguments:
            sys.exit("Usage: sh scripts/prepare-aip-charts.sh")
        with checkout_lock(ROOT):
            prepare(ROOT)
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"error: NavigationFlight build preparation failed: {error}")
