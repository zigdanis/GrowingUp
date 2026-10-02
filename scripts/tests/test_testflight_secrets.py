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

spec = importlib.util.spec_from_file_location('testflight_secrets', Path(__file__).parents[1] / 'testflight-secrets.py')
secrets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(secrets)


class TestflightSecretsTest(unittest.TestCase):
    def test_rejects_readable_by_others_and_git_checkout_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'input.json'
            path.write_text('{}')
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                secrets.restricted_file(path)
            path.chmod(0o600)
            (Path(directory) / '.git').mkdir()
            with self.assertRaises(ValueError):
                secrets.restricted_file(path)

    def import_credentials(self, directory, secret_status):
        directory = Path(directory)
        key = directory / 'key.p8'
        key.write_text('fake-private-content')
        key.chmod(0o600)
        source = directory / 'input.json'
        source.write_text(json.dumps({'ASC_KEY_ID': 'KEYID', 'ASC_ISSUER_ID': 'issuer',
                                      'ASC_PRIVATE_KEY_PATH': str(key), 'MATCH_PASSWORD': 'fake-match-password'}))
        source.chmod(0o600)
        calls = []

        def run(command, **kwargs):
            calls.append((command, kwargs))
            status = 0 if command[0] == 'openssl' else secret_status
            return subprocess.CompletedProcess(command, status, stdout='', stderr='error')

        output = io.StringIO()
        with patch.object(sys, 'argv', ['testflight-secrets.py', str(source)]), patch.object(secrets.subprocess, 'run', run), contextlib.redirect_stdout(output):
            if secret_status:
                with self.assertRaises(RuntimeError):
                    secrets.main()
            else:
                secrets.main()
        self.assertNotIn('fake-private-content', output.getvalue())
        self.assertNotIn('fake-match-password', output.getvalue())
        for command, kwargs in calls:
            self.assertNotIn('fake-private-content', ' '.join(command))
            self.assertNotIn('fake-match-password', ' '.join(command))
            if command[0] == 'gh':
                self.assertEqual(command[-2:], ['--env', 'testflight'])
                self.assertIn('input', kwargs)
        return source, key

    def test_success_uses_environment_stdin_and_removes_input_copies(self):
        with tempfile.TemporaryDirectory() as directory:
            source, key = self.import_credentials(directory, 0)
            self.assertFalse(source.exists())
            self.assertFalse(key.exists())

    def test_failed_import_retains_input_files_and_does_not_echo_values(self):
        with tempfile.TemporaryDirectory() as directory:
            source, key = self.import_credentials(directory, 1)
            self.assertTrue(source.exists())
            self.assertTrue(key.exists())
