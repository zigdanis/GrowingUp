import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import testflight_local as local

spec = importlib.util.spec_from_file_location('testflight_commands', Path(__file__).parents[1] / 'testflight.py')
commands = importlib.util.module_from_spec(spec)
spec.loader.exec_module(commands)


class UnifiedCommandTests(unittest.TestCase):
    def test_deploy_requires_executor_and_never_silently_dispatches_cloud(self):
        with (patch.object(sys, 'argv', ['testflight.py', 'deploy']), patch.object(commands, 'gh') as gh,
              contextlib.redirect_stderr(io.StringIO())):
            with self.assertRaises(SystemExit) as error:
                commands.main()
        self.assertEqual(2, error.exception.code)
        gh.assert_not_called()

    def test_local_and_cloud_deploy_share_source_notes_and_version(self):
        sha = 'b' * 40
        notes = {'notes_en': 'Widget fix', 'notes_ru': 'Исправление виджета'}
        for target in ('local', 'cloud'):
            calls = []

            def gh(*args, data=None):
                calls.append((args, data))
                if args[0] == 'run':
                    return '[{"status":"completed","conclusion":"success"}]' if '--commit' in args else '[]'
                return '{"html_url":"https://example.test/run/123","workflow_run_id":123}'

            def api(path):
                if path.startswith('commits/'):
                    return {'sha': sha}
                if path.startswith('compare/'):
                    return {'merge_base_commit': {'sha': sha}}
                self.fail('Unexpected API request: ' + path)

            with (patch.object(commands, 'api', side_effect=api),
                  patch.object(commands, 'readiness'), patch.object(commands, 'read_notes', return_value=notes),
                  patch.object(commands, 'gh', side_effect=gh), patch.object(local, 'run_local') as run,
                  contextlib.redirect_stdout(io.StringIO())):
                commands.unified_main(['deploy', target, '--version', '2.2.0', '--notes', '/example/notes.json'])
            if target == 'local':
                self.assertEqual(('deploy', sha, '2.2.0', notes), run.call_args.args[:4])
                self.assertFalse(any(args[0] == 'api' for args, data in calls))
            else:
                run.assert_not_called()
                payload = calls[-1][1]
                self.assertEqual({'operation': 'deploy', 'source_sha': sha, 'marketing_version': '2.2.0', **notes}, payload['inputs'])

    def test_source_outside_master_is_refused_before_any_release_action(self):
        with (patch.object(commands, 'api', side_effect=[{'sha': 'a' * 40}, {'merge_base_commit': {'sha': 'b' * 40}}]),
              patch.object(local, 'run_local') as run, patch.object(commands, 'gh') as gh):
            with self.assertRaisesRegex(RuntimeError, 'must belong to master'):
                commands.unified_main(['deploy', 'local'])
        run.assert_not_called()
        gh.assert_not_called()

    def test_resume_uses_original_source_and_never_generates_new_notes(self):
        recorded = {'source_sha': 'c' * 40, 'version': '2.2.0'}
        with (patch.object(commands, 'receipt', return_value=recorded),
              patch.object(commands, 'prepare_notes') as generate,
              patch.object(local, 'run_local') as run):
            commands.unified_main(['resume', 'local', '123'])
        generate.assert_not_called()
        self.assertEqual('c' * 40, run.call_args.args[1])
        self.assertEqual('123', run.call_args.kwargs['release_id'])

    def test_stale_default_notes_are_regenerated_for_selected_source(self):
        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / 'notes.json'
            notes.write_text('{"en":"Old notes","ru":"Старые заметки"}')
            notes.with_suffix('.source.json').write_text('{"source_sha":"old"}')
            with (patch.object(commands, 'DEFAULT_NOTES', notes),
                  patch.object(commands, 'api', side_effect=[{'sha': 'new'}, {'merge_base_commit': {'sha': 'new'}}]),
                  patch.object(commands, 'prepare_notes') as generate,
                  patch.object(commands, 'gh', return_value='[{"status":"completed","conclusion":"success"}]'),
                  patch.object(local, 'run_local')):
                commands.unified_main(['deploy', 'local'])
            generate.assert_called_once_with('new')


class LocalExecutorTests(unittest.TestCase):
    def test_failed_attempt_keeps_previous_latest_until_reservation(self):
        for failure in ('credentials', 'bundle', 'source', 'preflight', 'after-reservation'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                @contextlib.contextmanager
                def credentials(api):
                    if failure == 'credentials':
                        raise RuntimeError('Credential setup missing')
                    yield {}, []

                def run(args, **kwargs):
                    failed = (failure == 'bundle' and args[:2] == ['bundle', 'check']) or (
                        failure == 'source' and args[:3] == ['git', 'worktree', 'add'])
                    return subprocess.CompletedProcess(args, int(failed), '', '')

                class Process:
                    stdout = io.StringIO('Fastlane stopped\n')
                    def wait(self):
                        return 1

                def start_process(*args, **kwargs):
                    data = {'release_id': '2000', 'phase': 'reserved'}
                    if failure == 'after-reservation':
                        data['receipt_id'] = 42
                    Path(kwargs['env']['RELEASE_RECEIPT']).write_text(json.dumps(data))
                    return Process()

                with (patch.object(local, 'STATE', Path(directory)), patch.object(local.time, 'time_ns', return_value=2000),
                      patch.object(local, 'credentials', credentials), patch.object(local.subprocess, 'run', side_effect=run),
                      patch.object(local.subprocess, 'Popen', side_effect=start_process),
                      contextlib.redirect_stdout(io.StringIO())):
                    local.save_latest('100', '1000')
                    with self.assertRaises(RuntimeError):
                        local.run_local('deploy', 'a' * 40, '2.2.0', {}, None)
                    self.assertEqual('2000' if failure == 'after-reservation' else '100', local.last_local_id())

    def test_older_concurrent_attempt_cannot_replace_newer_latest(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(local, 'STATE', Path(directory)):
            local.save_latest('newer-release', '3000')
            local.save_latest('older-release', '2000')
            self.assertEqual('newer-release', local.last_local_id())

    def test_same_release_artifacts_cannot_be_used_concurrently(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            with local.release_file_lock(path):
                with self.assertRaisesRegex(RuntimeError, 'already running'):
                    with local.release_file_lock(path):
                        self.fail('Concurrent local release acquired the artifact lock')
            with local.release_file_lock(path):
                pass

    def test_credential_permissions_reject_shared_or_tracked_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'key.json'
            path.write_text('{}')
            path.chmod(0o644)
            with self.assertRaisesRegex(ValueError, 'owner-only'):
                local.restricted(path)
            path.chmod(0o600)
            self.assertEqual(path.resolve(), local.restricted(path))
            (path.parent / '.git').mkdir()
            with self.assertRaisesRegex(ValueError, 'Git checkouts'):
                local.restricted(path)

    def test_local_execution_isolated_source_and_redacted_logs(self):
        calls = []
        secret = 'private-test-password'

        def run(args, **kwargs):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, '', '')

        class Process:
            stdout = io.StringIO('Starting\ncredential=' + secret + '\nFinished\n')
            def wait(self):
                return 0

        with tempfile.TemporaryDirectory() as directory:
            @contextlib.contextmanager
            def credentials(api):
                yield {}, [secret]

            with (patch.object(local, 'STATE', Path(directory)), patch.object(local, 'credentials', credentials),
                  patch.object(local.subprocess, 'run', side_effect=run),
                  patch.object(local.subprocess, 'Popen', return_value=Process()) as popen,
                  contextlib.redirect_stdout(io.StringIO()) as output):
                result = local.run_local('deploy', 'a' * 40, '2.2.0', {'notes_en': 'English', 'notes_ru': 'Русский'}, None)
            env = popen.call_args.kwargs['env']
            self.assertEqual('local', env['RELEASE_EXECUTOR'])
            self.assertEqual('2.2.0', env['MARKETING_VERSION'])
            self.assertEqual('a' * 40, env['SOURCE_SHA'])
            self.assertNotEqual(str(local.ROOT), env['RELEASE_SOURCE_DIR'])
            self.assertEqual(['bundle', 'exec', 'fastlane', 'ios', 'app_store'], popen.call_args.args[0])
            self.assertNotIn(secret, output.getvalue())
            self.assertNotIn(secret, (result.parent / 'deploy.log').read_text())
            self.assertIn('[REDACTED]', (result.parent / 'deploy.log').read_text())
            self.assertEqual(['git', 'worktree', 'remove', '--force', env['RELEASE_SOURCE_DIR']], calls[-1])

    def test_non_macos_setup_has_clear_cloud_alternative(self):
        with patch.object(local.platform, 'system', return_value='Linux'):
            with self.assertRaisesRegex(RuntimeError, 'use cloud'):
                local.setup_local()
