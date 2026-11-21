"""Stage the pinned GitHub chart release using the developer's gh credentials."""

from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "johnbenz13/fplnav-spec"
spec = importlib.util.spec_from_file_location("chart_verifier", ROOT / "scripts/verify-aip-charts.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def download(asset, destination):
    with destination.open("wb") as output:
        subprocess.run([
            "gh", "api", f"repos/{REPOSITORY}/releases/assets/{asset['id']}",
            "-H", "Accept: application/octet-stream",
        ], stdout=output, check=True)


def prepare():
    pin_path = ROOT / "Config/aip-charts-pin.json"
    pin = json.loads(pin_path.read_bytes())
    tag = f"aviation-maps/{pin['releaseId']}"
    # gh reads its keychain login or GH_TOKEN; credentials never enter arguments.
    from urllib.parse import quote
    release = json.loads(subprocess.check_output([
        "gh", "api", f"repos/{REPOSITORY}/releases/tags/{quote(tag, safe='')}",
    ]))
    if release.get("draft") or not release.get("immutable"):
        raise ValueError("Expected an immutable published chart release")
    assets = {asset["name"]: asset for asset in release["assets"]}
    generated = ROOT / ".generated"
    generated.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aip-download-", dir=generated) as temporary:
        stage = Path(temporary) / "AIPCharts"
        (stage / "pdf").mkdir(parents=True)
        index = stage / "index.json"
        download(assets["manifest.json"], index)
        if verifier.sha256(index) != pin["manifestSha256"]:
            raise ValueError("Release manifest does not match committed pin")
        manifest = json.loads(index.read_bytes())
        jobs = []
        for artifact in manifest["artifacts"]:
            match = re.fullmatch(r"AIPCharts/pdf/([a-z0-9_-]+\.pdf)", artifact["destination"])
            if artifact["representation"] != "pdf" or not match:
                raise ValueError("Unexpected chart artifact destination")
            asset_name = f"artifact-{artifact['id']}"
            jobs.append((assets[asset_name], stage / "pdf" / match[1]))
        if len({path for _, path in jobs}) != len(jobs):
            raise ValueError("Duplicate chart destination")
        with ThreadPoolExecutor(max_workers=4) as executor:
            list(executor.map(lambda job: download(*job), jobs))
        verifier.verify(pin_path, stage)
        destination = generated / "AIPCharts"
        backup = Path(temporary) / "previous"
        if destination.exists():
            destination.rename(backup)
        try:
            stage.rename(destination)
        except OSError:
            if backup.exists():
                backup.rename(destination)
            raise
    subprocess.run([
        "/usr/bin/python3", str(ROOT / "scripts/verify-aip-charts.py"),
        str(pin_path), str(destination), str(generated / "AIPCharts.xcfilelist"),
    ], check=True)


if __name__ == "__main__":
    try:
        prepare()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Chart preparation failed: {error}")
