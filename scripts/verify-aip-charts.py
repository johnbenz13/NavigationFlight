"""Verify the staged or built AIPCharts bundle against its committed pin."""

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


MANIFEST_LIMIT = 1024 * 1024


def reviewed_index(pin, data):
    if len(data) > MANIFEST_LIMIT:
        raise ValueError("chart index exceeds the size limit")
    if pin["schemaVersion"] != 1 or hashlib.sha256(data).hexdigest() != pin["manifestSha256"]:
        raise ValueError("index SHA-256 does not match the reviewed pin")
    manifest = json.loads(data)
    if manifest["schemaVersion"] != 2 or manifest["releaseId"] != pin["releaseId"]:
        raise ValueError("index release identity does not match the chart pin")
    return manifest


def chart_files(manifest):
    expected = {}
    ids = set()
    total = 0
    for asset in manifest["artifacts"]:
        match = re.fullmatch(r"AIPCharts/pdf/([a-z0-9_-]+\.pdf)", asset["destination"])
        asset_id = asset["id"]
        if (
            asset["representation"] != "pdf" or not match or match[1] in expected
            or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,99}", asset_id) or asset_id in ids
            or type(asset["bytes"]) is not int or not 0 < asset["bytes"] <= 128 * 1024**2
            or not re.fullmatch(r"[0-9a-f]{64}", asset["sha256"])
        ):
            raise ValueError(f"invalid or duplicate chart path {asset['destination']}")
        expected[match[1]] = asset
        ids.add(asset_id)
        total += asset["bytes"]
    if not 1 <= len(expected) <= 256 or total > 512 * 1024**2:
        raise ValueError("chart snapshot exceeds the inventory limits")
    return expected


def verify(pin_path, root):
    pin = json.loads(pin_path.read_bytes())
    index = root / "index.json"
    pdf_dir = root / "pdf"
    if root.is_symlink() or index.is_symlink() or pdf_dir.is_symlink():
        raise ValueError("chart resource paths must be regular files and directories")
    if {path.name for path in root.iterdir()} != {"index.json", "pdf"}:
        raise ValueError("unexpected files at the AIPCharts root")
    if not index.is_file() or index.stat().st_size > MANIFEST_LIMIT:
        raise ValueError("invalid chart index file")
    manifest = reviewed_index(pin, index.read_bytes())
    expected = chart_files(manifest)
    if {path.name for path in pdf_dir.iterdir()} != expected.keys():
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


def write_inputs(path, files):
    relative_root = "$(SRCROOT)/.generated/AIPCharts"
    paths = [relative_root, f"{relative_root}/index.json", f"{relative_root}/pdf"]
    paths.extend(f"{relative_root}/pdf/{name}" for name in files)
    pending = path.with_suffix(".tmp")
    pending.write_text("\n".join(paths) + "\n")
    pending.replace(path)


if __name__ == "__main__":
    try:
        files = verify(Path(sys.argv[1]), Path(sys.argv[2]))
        if len(sys.argv) == 4:
            write_inputs(Path(sys.argv[3]), files)
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"error: AIPCharts verification failed ({error}). Run sh scripts/build.sh.")
