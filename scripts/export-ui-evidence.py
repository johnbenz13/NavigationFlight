#!/usr/bin/env python3
"""Export selected UI screenshots from an original Xcode result without rerunning tests."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
from datetime import datetime, timezone


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f"{' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def export(args):
    location = Path(args.result).expanduser().resolve()
    candidates = [location] if location.suffix == '.xcresult' else list(location.rglob('*.xcresult')) if location.is_dir() else []
    valid = [p for p in candidates if (p / 'Info.plist').is_file()]
    if len(valid) != 1:
        raise ValueError(f"Expected one original .xcresult with Info.plist at {location}; found {len(valid)}. Pass the exact original bundle in DerivedData/Logs/Test, not an incomplete ActionArtifacts copy. No tests need rerunning.")
    bundle = valid[0]
    summary = json.loads(run('xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(bundle)))
    output = Path(args.output).expanduser().resolve()
    if output.exists():
        raise ValueError(f"Output already exists: {output}. Choose a new directory; the original result can be exported repeatedly.")
    selections = []
    for selection in args.select:
        name, separator, orientation = selection.rpartition('=')
        if not separator or not name or orientation not in ('portrait', 'landscape'):
            raise ValueError('--select must be exact attachment name=portrait or name=landscape')
        if name in [n for n, _ in selections]:
            raise ValueError(f'Duplicate selection: {name}')
        selections.append((name, orientation))
    source = Path(args.source).resolve()
    head = run('git', '-C', str(source), 'rev-parse', 'HEAD').strip()
    status = run('git', '-C', str(source), 'status', '--porcelain')
    diff = run('git', '-C', str(source), 'diff', 'HEAD', '--binary')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.ui-evidence-', dir=output.parent) as temporary:
        staging = Path(temporary)
        run('xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle), '--output-path', str(staging), '--test-id', args.test_id)
        manifest = json.loads((staging / 'manifest.json').read_text())
        records = []
        for name, orientation in selections:
            matches = [(test, attachment) for test in manifest for attachment in test['attachments'] if attachment['suggestedHumanReadableName'] == name or re.fullmatch(re.escape(name) + r'_[0-9]+_[0-9A-Fa-f-]{36}\.png', attachment['suggestedHumanReadableName'])]
            if len(matches) != 1:
                available = [a['suggestedHumanReadableName'] for t in manifest for a in t['attachments']]
                raise ValueError(f'Expected one attachment named {name!r}; found {len(matches)}. Available: {available}')
            test, attachment = matches[0]
            path = staging / attachment['exportedFileName']
            if path.parent != staging or not path.is_file():
                raise ValueError(f'Invalid exported attachment path: {path}')
            data = path.read_bytes()
            if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
                raise ValueError(f'{name}: expected a PNG screenshot')
            width, height = struct.unpack('>II', data[16:24])
            if not (width > height if orientation == 'landscape' else height > width):
                raise ValueError(f'{name}: {width}x{height} pixels do not match expected {orientation}; capture the full screen after rotation.')
            records.append(dict(testIdentifier=test['testIdentifier'], attachment=attachment, orientation=orientation, pixelWidth=width, pixelHeight=height, sha256=hashlib.sha256(data).hexdigest()))
        selected = {r['attachment']['exportedFileName'] for r in records}
        for path in staging.iterdir():
            if path.name not in selected and path.name != 'manifest.json':
                if path.is_file():
                    path.unlink()
        provenance = dict(exportedAt=datetime.now(timezone.utc).isoformat(), originalResultBundle=str(bundle), resultInfoSHA256=hashlib.sha256((bundle / 'Info.plist').read_bytes()).hexdigest(), testSummary=summary, source=dict(path=str(source), head=head, status=status, note='Source state recorded at export; verify this matches the test invocation. Untracked files are listed, not archived.'), screenshots=records)
        (staging / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        (staging / 'source.patch').write_text(diff)
        staging.rename(output)
    print(f'Exported {len(records)} validated screenshots to {output}; original bundle preserved.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--result', required=True, help='Original .xcresult, or directory containing exactly one original bundle')
    parser.add_argument('--test-id', required=True, help='xcresulttool test identifier')
    parser.add_argument('--select', action='append', required=True, help='Exact attachment name=portrait|landscape (repeatable)')
    parser.add_argument('--source', required=True, help='Git checkout used for test run; recorded as export-time provenance')
    parser.add_argument('--output', required=True, help='New export directory')
    try:
        export(parser.parse_args())
    except (ValueError, OSError, KeyError, json.JSONDecodeError, struct.error) as error:
        print(f'UI evidence export failed: {error}\nFix the path/permissions/selection and repeat this command against the same original result; do not rerun tests.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
