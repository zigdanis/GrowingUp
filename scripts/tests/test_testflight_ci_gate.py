import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location('ci_gate', Path(__file__).parents[1] / 'testflight-ci-gate.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
SHA = 'a' * 40


class SourceCIGateTests(unittest.TestCase):
    def run_gate(self, states, source=SHA, ancestor=SHA, timeout=100):
        states = iter(states)
        now = [0]
        messages = []

        def fetch(repo, path):
            if path.startswith('compare/'):
                return {'merge_base_commit': {'sha': ancestor}}
            if '/jobs?' in path:
                return {'jobs': [{'name': 'Build & Test', 'conclusion': 'failure', 'html_url': 'https://example.test/job'}]}
            return {'workflow_runs': next(states)}

        def pause(seconds):
            now[0] += seconds

        return gate.wait_for_ci('owner/repo', source, timeout=timeout, interval=30, fetch=fetch,
                                clock=lambda: now[0], pause=pause, report=messages.append), messages

    def run_state(self, status, conclusion=None, **overrides):
        return {'id': 10, 'head_sha': SHA, 'event': 'push', 'head_branch': 'master',
                'status': status, 'conclusion': conclusion, 'html_url': 'https://example.test/ci',
                'run_attempt': 1, **overrides}

    def test_waits_for_exact_master_source_and_returns_only_after_success(self):
        wrong = self.run_state('completed', 'success', head_sha='b' * 40)
        pr = self.run_state('completed', 'success', event='pull_request')
        good = self.run_state('completed', 'success')
        result, messages = self.run_gate([[wrong, pr], [self.run_state('queued')],
                                          [self.run_state('in_progress')], [good]])
        self.assertEqual(good, result)
        self.assertIn('not started', messages[0])
        self.assertIn('queued', messages[1])
        self.assertIn('passed', messages[-1])

    def test_failed_ci_reports_failed_job_and_never_releases(self):
        with self.assertRaisesRegex(RuntimeError, 'Build & Test: failure.*https://example.test/job'):
            self.run_gate([[self.run_state('completed', 'failure')]])

    def test_cancelled_ci_is_not_accepted(self):
        with self.assertRaisesRegex(RuntimeError, 'No archive or upload'):
            self.run_gate([[self.run_state('completed', 'cancelled')]])

    def test_no_run_has_bounded_wait(self):
        with self.assertRaisesRegex(TimeoutError, 'No upload started'):
            self.run_gate([[], [], []], timeout=60)

    def test_invalid_or_non_master_source_fails_before_waiting(self):
        with self.assertRaisesRegex(ValueError, 'full commit SHA'):
            self.run_gate([], source='master')
        with self.assertRaisesRegex(ValueError, 'belong to master'):
            self.run_gate([], ancestor='b' * 40)


if __name__ == '__main__':
    unittest.main()
