import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('testflight', Path(__file__).parents[1] / 'testflight.py')
testflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(testflight)


class TestflightNotesTest(unittest.TestCase):
    def test_notes_dispatch_uses_original_receipt_identity_and_both_locales(self):
        recorded = {'source_sha': 'a' * 40, 'version': '2.1.4', 'build_number': '26', 'phase': 'available'}
        calls = []

        def gh(*args, data=None):
            calls.append((args, data))
            if args[0] == 'run':
                return '[]'
            return json.dumps({'html_url': 'https://example.test/run/101', 'workflow_run_id': 101})

        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'notes.json'
            notes.write_text(json.dumps({'en': "What's New\nPhoto saving fixed.\n\nWhat to Test\nEdit a photo.",
                                         'ru': 'Что нового\nИсправлено сохранение фото.\n\nЧто проверить\nИзмените фото.'},
                                        ensure_ascii=False), encoding='utf-8')
            with (patch.object(sys, 'argv', ['testflight.py', 'notes', '100', str(notes)]),
                  patch.object(testflight, 'readiness'), patch.object(testflight, 'receipt', return_value=recorded),
                  patch.object(testflight, 'gh', side_effect=gh), contextlib.redirect_stdout(io.StringIO())):
                testflight.main()
        payload = calls[-1][1]
        self.assertEqual('master', payload['ref'])
        self.assertEqual('notes', payload['inputs']['operation'])
        self.assertEqual('100', payload['inputs']['resume_run_id'])
        self.assertEqual(recorded['source_sha'], payload['inputs']['source_sha'])
        self.assertIn('What to Test', payload['inputs']['notes_en'])
        self.assertIn('Что проверить', payload['inputs']['notes_ru'])

    def test_notes_require_both_translations_with_utf8_byte_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'notes.json'
            for value in [[], {'en': 'Only English'}, {'en': 'Text', 'ru': ' '}, {'en': 'Text', 'ru': 'я' * 2001}]:
                path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')
                with self.assertRaises(ValueError):
                    testflight.read_notes(path)
