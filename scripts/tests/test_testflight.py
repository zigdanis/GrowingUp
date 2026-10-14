import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('testflight', Path(__file__).parents[1] / 'testflight.py')
testflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(testflight)


class TestflightNotesTest(unittest.TestCase):
    def test_prepare_notes_uses_latest_processed_build_and_never_dispatches(self):
        source = 'b' * 40
        base = 'a' * 40
        records = [
            {'processing_status': 'VALID', 'source_sha': 'c' * 40, 'build_number': '29', 'version': '2.1.7'},
            {'processing_status': 'VALID', 'source_sha': base, 'build_number': '30', 'version': '2.1.8'},
            {'phase': 'reserved', 'source_sha': 'd' * 40, 'build_number': '31', 'version': '2.1.9'},
        ]
        notes_text = {'en': "What's New\nClearer widget labels.\nWhat to Test\nOpen a widget.",
                      'ru': 'Что нового\nУлучшена читаемость виджетов.\nЧто проверить\nОткройте виджет.'}
        commands = []

        def run(command, **kwargs):
            commands.append(command)
            if command[0] == 'codex':
                self.assertIn(base, kwargs['input'])
                self.assertIn(source, kwargs['input'])
                self.assertIn('Widget label fix', kwargs['input'])
                self.assertIn('buttonStyle', kwargs['input'])
                self.assertIn('read-only', command)
                self.assertNotIn('--model', command)
                Path(command[command.index('--output-last-message') + 1]).write_text(
                    json.dumps(notes_text, ensure_ascii=False), encoding='utf-8')
                output = ''
            elif command[1] == 'log':
                output = 'Widget label fix'
            elif command[1] == 'diff':
                output = '+ .buttonStyle(.plain)'
            else:
                output = ''
            return subprocess.CompletedProcess(command, 0, output, '')

        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'testflight-next.json'
            with (patch.object(sys, 'argv', ['testflight.py', 'prepare-notes']),
                  patch.object(testflight, 'DEFAULT_NOTES', notes),
                  patch.object(testflight, 'api', return_value={'sha': source}),
                  patch.object(testflight, 'release_receipts', return_value=[{'body': json.dumps(r)} for r in records]),
                  patch.object(testflight, 'readiness') as readiness,
                  patch.object(testflight, 'gh') as gh,
                  patch.object(testflight.subprocess, 'run', side_effect=run),
                  contextlib.redirect_stdout(io.StringIO())):
                testflight.main()
            self.assertEqual(notes_text, json.loads(notes.read_text(encoding='utf-8')))
            self.assertIn(base + '..' + source, notes.with_suffix('.md').read_text())
        readiness.assert_not_called()
        gh.assert_not_called()
        self.assertEqual(['git', 'merge-base', '--is-ancestor', base, source], commands[0])

    def test_failed_generation_preserves_prepared_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'testflight-next.json'
            notes.write_text('previous reviewed notes', encoding='utf-8')
            record = {'processing_status': 'VALID', 'source_sha': 'a' * 40,
                      'build_number': '30', 'version': '2.1.8'}

            def run(command, **kwargs):
                return subprocess.CompletedProcess(command, 1 if command[0] == 'codex' else 0, 'app diff', '')

            with (patch.object(testflight, 'DEFAULT_NOTES', notes),
                  patch.object(testflight, 'api', return_value={'sha': 'b' * 40}),
                  patch.object(testflight, 'release_receipts', return_value=[{'body': json.dumps(record)}]),
                  patch.object(testflight.subprocess, 'run', side_effect=run),
                  contextlib.redirect_stdout(io.StringIO())):
                with self.assertRaisesRegex(RuntimeError, 'Codex note generation failed'):
                    testflight.prepare_notes('master')
            self.assertEqual('previous reviewed notes', notes.read_text())

    def test_legacy_explicit_cloud_deploy_still_supported(self):
        calls = []
        notes_text = {'en': "What's New\nWidget labels are clearer.", 'ru': 'Что нового\nУлучшена читаемость виджетов.'}

        def gh(*args, data=None):
            calls.append((args, data))
            if args[:2] == ('run', 'list'):
                if '--commit' in args:
                    return '[{"status":"completed","conclusion":"success"}]'
                return '[]'
            return json.dumps({'html_url': 'https://example.test/run/101', 'workflow_run_id': 101})

        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'testflight-next.json'
            notes.write_text(json.dumps(notes_text, ensure_ascii=False), encoding='utf-8')
            with (patch.object(sys, 'argv', ['testflight.py', 'deploy', 'next', 'master', str(notes)]),
                  patch.object(testflight, 'DEFAULT_NOTES', notes),
                  patch.object(testflight, 'readiness'),
                  patch.object(testflight, 'api', return_value={'sha': 'b' * 40}) as api,
                  patch.object(testflight, 'gh', side_effect=gh), contextlib.redirect_stdout(io.StringIO())):
                testflight.main()
        api.assert_called_once_with('commits/master')
        payload = calls[-1][1]
        self.assertEqual('master', payload['ref'])
        self.assertEqual('deploy', payload['inputs']['operation'])
        self.assertEqual('next', payload['inputs']['marketing_version'])
        self.assertEqual('b' * 40, payload['inputs']['source_sha'])
        self.assertEqual(notes_text['en'], payload['inputs']['notes_en'])
        self.assertEqual(notes_text['ru'], payload['inputs']['notes_ru'])

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
