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
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='growingup-cloud-test-')
        self.addCleanup(directory.cleanup)
        active = patch.object(testflight, 'ACTIVE_RELEASE', Path(directory.name) / 'active.json')
        active.start()
        self.addCleanup(active.stop)

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
            notes.with_suffix('.source.json').write_text(json.dumps({'source_sha': 'b' * 40}))
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

    def test_legacy_default_notes_are_refreshed_before_dispatching_another_source(self):
        for metadata in (None, {'source_sha': 'a' * 40}):
            calls = []

            def gh(*args, data=None):
                calls.append((args, data))
                if args[0] == 'run':
                    return '[{"status":"completed","conclusion":"success"}]' if '--commit' in args else '[]'
                return '{"html_url":"https://example.test/run/123","workflow_run_id":123}'

            with self.subTest(metadata=metadata), tempfile.TemporaryDirectory() as directory:
                notes = Path(directory) / 'notes.json'
                notes.write_text('{"en":"Old English","ru":"Старый текст"}')
                if metadata:
                    notes.with_suffix('.source.json').write_text(json.dumps(metadata))

                def generate(source):
                    self.assertEqual('b' * 40, source)
                    notes.write_text('{"en":"New English","ru":"Новый текст"}')

                with (patch.object(sys, 'argv', ['testflight.py', 'deploy', 'next']),
                      patch.object(testflight, 'DEFAULT_NOTES', notes), patch.object(testflight, 'readiness'),
                      patch.object(testflight, 'api', return_value={'sha': 'b' * 40}),
                      patch.object(testflight, 'prepare_notes', side_effect=generate) as generated,
                      patch.object(testflight, 'gh', side_effect=gh), contextlib.redirect_stdout(io.StringIO())):
                    testflight.main()
                generated.assert_called_once_with('b' * 40)
                self.assertEqual('New English', calls[-1][1]['inputs']['notes_en'])
                self.assertEqual('Новый текст', calls[-1][1]['inputs']['notes_ru'])

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

    def test_cloud_deploy_queues_without_locally_waiting_for_ci_and_remembers_identity(self):
        calls = []

        def gh(*args, data=None):
            calls.append((args, data))
            if args[0] == 'run':
                self.assertNotIn('--commit', args, 'Cloud source CI is gated in Actions, not by an idle agent')
                return '[]'
            return '{"html_url":"https://example.test/run/123","workflow_run_id":123}'

        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'notes.json'
            notes.write_text('{"en":"Photo fix","ru":"Исправление фото"}')
            with (patch.object(sys, 'argv', ['testflight.py', 'deploy', 'next', 'master', str(notes)]),
                  patch.object(testflight, 'readiness'), patch.object(testflight, 'api', return_value={'sha': 'b' * 40}),
                  patch.object(testflight, 'gh', side_effect=gh), contextlib.redirect_stdout(io.StringIO()) as output):
                testflight.main()
        active = json.loads(testflight.ACTIVE_RELEASE.read_text())
        self.assertEqual('123', active['run_id'])
        self.assertEqual('123', active['release_id'])
        self.assertEqual('b' * 40, active['source_sha'])
        self.assertIn('progress 123', output.getvalue())
        self.assertEqual(1, sum(data is not None for args, data in calls))

    def test_progress_reads_existing_jobs_and_receipt_without_dispatch_or_credentials(self):
        testflight.ACTIVE_RELEASE.write_text('{"run_id":"123","release_id":"100","source_sha":"old"}')
        jobs = [{'name': 'Archive, upload and distribute', 'status': 'in_progress', 'conclusion': None,
                 'html_url': 'https://example.test/job', 'steps': [{'name': 'Run release operation', 'status': 'in_progress'}]}]

        def api(path):
            return {'jobs': jobs} if '/jobs?' in path else {'html_url': 'https://example.test/run/123',
                                                           'status': 'in_progress', 'conclusion': None}

        recorded = {'release_id': '100', 'source_sha': 'a' * 40, 'phase': 'uploading',
                    'version': '2.2.4', 'build_number': '37'}
        with (patch.object(testflight, 'api', side_effect=api),
              patch.object(testflight, 'release_receipts', return_value=[{'body': json.dumps(recorded)}]),
              patch.object(testflight, 'readiness') as readiness, patch.object(testflight, 'gh') as gh):
            progress = testflight.cloud_progress()
        readiness.assert_not_called()
        gh.assert_not_called()
        self.assertEqual('uploading', progress['phase'])
        self.assertEqual('37', progress['build_number'])
        self.assertEqual('Run release operation', progress['active'][0]['steps'][0])

    def test_progress_shows_ci_blocker_before_any_build_is_reserved(self):
        with (patch.object(testflight, 'api', side_effect=[
                {'html_url': 'https://example.test/run/123', 'status': 'completed', 'conclusion': 'failure'},
                {'jobs': [{'name': 'Wait for source CI', 'status': 'completed', 'conclusion': 'failure',
                           'html_url': 'https://example.test/gate'}]}]),
              patch.object(testflight, 'release_receipts', return_value=[])):
            progress = testflight.cloud_progress('123')
        self.assertEqual('blocked_by_ci', progress['phase'])
        self.assertEqual('https://example.test/gate', progress['failed'][0]['url'])
        self.assertIsNone(progress['build_number'])

    def test_progress_recovers_resumed_release_on_another_machine_from_shared_receipt(self):
        recorded = {'release_id': '100', 'workflow_url': 'https://example.test/run/456',
                    'source_sha': 'a' * 40, 'phase': 'available', 'version': '2.2.4', 'build_number': '37'}
        with (patch.object(testflight, 'api', side_effect=[
                {'html_url': 'https://example.test/run/456', 'status': 'completed', 'conclusion': 'success'},
                {'jobs': []}]),
              patch.object(testflight, 'release_receipts', return_value=[{'body': json.dumps(recorded)}])):
            progress = testflight.cloud_progress('456')
        self.assertEqual('available', progress['phase'])
        self.assertEqual('37', progress['build_number'])

    def test_progress_uses_durable_run_title_before_resume_updates_receipt(self):
        recorded = {'release_id': '100', 'workflow_url': 'https://example.test/run/100',
                    'source_sha': 'a' * 40, 'phase': 'uploaded', 'version': '2.2.4', 'build_number': '37'}
        with (patch.object(testflight, 'api', side_effect=[
                {'html_url': 'https://example.test/run/456', 'status': 'in_progress', 'conclusion': None,
                 'display_title': 'TestFlight resume — source ' + 'a' * 40 + ' — release 100'}, {'jobs': []}]),
              patch.object(testflight, 'release_receipts', return_value=[{'body': json.dumps(recorded)}])):
            progress = testflight.cloud_progress('456')
        self.assertEqual('uploaded', progress['phase'])
        self.assertEqual('37', progress['build_number'])

    def test_terminal_run_without_receipt_never_claims_to_be_preparing(self):
        with (patch.object(testflight, 'api', side_effect=[
                {'html_url': 'https://example.test/run/456', 'status': 'completed', 'conclusion': 'failure'},
                {'jobs': []}]), patch.object(testflight, 'release_receipts', return_value=[])):
            progress = testflight.cloud_progress('456')
        self.assertEqual('receipt_unavailable', progress['phase'])

    def test_dispatch_record_failure_still_reports_accepted_run_without_retry(self):
        with (patch.object(Path, 'mkdir', side_effect=PermissionError),
              contextlib.redirect_stdout(io.StringIO()) as output,
              contextlib.redirect_stderr(io.StringIO()) as warning):
            testflight.remember_dispatch({'workflow_run_id': 123, 'html_url': 'https://example.test/run/123'},
                                         {'source_sha': 'a' * 40, 'operation': 'deploy'})
        self.assertIn('https://example.test/run/123', output.getvalue())
        self.assertIn('already queued', warning.getvalue())
