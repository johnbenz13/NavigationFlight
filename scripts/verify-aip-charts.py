"""Verify the private stage or built AIPCharts bundle against its committed pin."""

import hashlib
import json
from pathlib import Path
import re
import sys


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify(pin_path, root):
    pin = json.loads(pin_path.read_bytes())
    index = root / "index.json"
    pdf_dir = root / "pdf"
    if root.is_symlink() or index.is_symlink() or pdf_dir.is_symlink():
        raise ValueError("chart resource paths must be regular files and directories")
    if {path.name for path in root.iterdir()} != {"index.json", "pdf"}:
        raise ValueError("unexpected files at the AIPCharts root")
    if pin["schemaVersion"] != 1 or sha256(index) != pin["manifestSha256"]:
        raise ValueError("index SHA-256 does not match the reviewed pin")
    manifest = json.loads(index.read_bytes())
    if manifest["schemaVersion"] != 2 or manifest["releaseId"] != pin["releaseId"]:
        raise ValueError("index release identity does not match the chart pin")

    expected = {}
    for asset in manifest["artifacts"]:
        match = re.fullmatch(r"AIPCharts/pdf/([a-z0-9][a-z0-9-]*\.pdf)", asset["destination"])
        if asset["representation"] != "pdf" or not match or match[1] in expected:
            raise ValueError(f"invalid or duplicate chart path {asset['destination']}")
        expected[match[1]] = asset
    if not expected or {path.name for path in pdf_dir.iterdir()} != expected.keys():
        raise ValueError("PDF filenames do not match the index")
    total = 0
    for name, asset in expected.items():
        path = pdf_dir / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size != asset["bytes"]:
            raise ValueError(f"invalid size or path for {name}")
        if sha256(path) != asset["sha256"]:
            raise ValueError(f"SHA-256 mismatch for {name}")
        total += asset["bytes"]
    print(f"Verified AIPCharts {manifest['releaseId']}, {len(expected)} PDFs, {total} PDF bytes")
    return sorted(expected)


if __name__ == "__main__":
    try:
        files = verify(Path(sys.argv[1]), Path(sys.argv[2]))
        if len(sys.argv) == 4:
            inputs = Path(sys.argv[3])
            relative_root = "$(SRCROOT)/.generated/AIPCharts"
            paths = [relative_root, f"{relative_root}/index.json", f"{relative_root}/pdf"]
            paths.extend(f"{relative_root}/pdf/{name}" for name in files)
            pending = inputs.with_suffix(".tmp")
            pending.write_text("\n".join(paths) + "\n")
            pending.replace(inputs)
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"error: AIPCharts verification failed ({error}). Run sh scripts/prepare-aip-charts.sh.")
