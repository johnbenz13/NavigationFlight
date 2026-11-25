#!/usr/bin/env python3
"""Exercise exporter failure/recovery and selection using xcresulttool-shaped payloads."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('evidence', Path(__file__).with_name('export-ui-evidence.py'))
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class EvidenceExportTests(unittest.TestCase):
    def test_recovery_orientation_provenance_and_repeat_export(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / 'original.xcresult'
            bundle.mkdir()
            (bundle / 'Info.plist').write_bytes(b'original result')
            args = SimpleNamespace(result=str(bundle), source=str(root), output=str(root / 'first'), test_id='Suite/test', select=['Portrait=portrait', 'Landscape=landscape'])

            def tool(*command):
                if command[0] == 'git':
                    return 'source-head\n' if 'rev-parse' in command else ''
                if 'summary' in command:
                    return '{"passedTests": 1}'
                destination = Path(command[command.index('--output-path') + 1])
                entries = []
                for name, width, height in [('Portrait', 1668, 2388), ('Landscape', 2388, 1668)]:
                    filename = name + '.png'
                    (destination / filename).write_bytes(b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', width, height))
                    entries.append(dict(exportedFileName=filename, suggestedHumanReadableName=name + '_0_94DA2377-9BF0-4632-8BD7-585F2AD95424.png', deviceId='simulator'))
                (destination / 'manifest.json').write_text(json.dumps([dict(testIdentifier='Suite/test', attachments=entries)]))
                return ''

            with patch.object(evidence, 'run', side_effect=tool):
                args.select = ['Landscape=portrait']
                with self.assertRaisesRegex(ValueError, '2388x1668'):
                    evidence.export(args)
                self.assertFalse(Path(args.output).exists())
                args.select = ['Portrait=portrait', 'Landscape=landscape']
                evidence.export(args)
                provenance = json.loads((Path(args.output) / 'provenance.json').read_text())
                self.assertEqual(provenance['screenshots'][1]['pixelWidth'], 2388)
                self.assertEqual(provenance['originalResultBundle'], str(bundle.resolve()))
                self.assertEqual(provenance['source']['head'], 'source-head')
                with self.assertRaisesRegex(ValueError, 'already exists'):
                    evidence.export(args)
                args.output = str(root / 'second')
                evidence.export(args)
                self.assertEqual((root / 'first/Landscape.png').read_bytes(), (root / 'second/Landscape.png').read_bytes())
                self.assertTrue((bundle / 'Info.plist').exists())

    def test_incomplete_copy_rejected_before_tool_execution(self):
        with tempfile.TemporaryDirectory(suffix='.xcresult') as directory:
            with patch.object(evidence, 'run') as tool:
                with self.assertRaisesRegex(ValueError, 'original.*Info.plist'):
                    evidence.export(SimpleNamespace(result=directory))
                tool.assert_not_called()


if __name__ == '__main__':
    unittest.main()
