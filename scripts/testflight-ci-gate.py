#!/usr/bin/env python3
"""Wait inside Actions for the selected master source's CI; never archive or upload."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time


def api(repo, path):
    result = subprocess.run(['gh', 'api', f'repos/{repo}/{path}'],
                            check=True, capture_output=True, text=True, timeout=60)
    return json.loads(result.stdout)


def wait_for_ci(repo, source, timeout=5400, interval=30, fetch=api, clock=time.monotonic,
                pause=time.sleep, report=print):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('Source must be a full commit SHA')
    comparison = fetch(repo, f'compare/{source}...master')
    if comparison['merge_base_commit']['sha'] != source:
        raise ValueError('Release source must belong to master')
    deadline = clock() + timeout
    previous = None
    while True:
        runs = fetch(repo, 'actions/workflows/ci.yml/runs?event=push&branch=master'
                     f'&head_sha={source}&per_page=5')['workflow_runs']
        runs = [run for run in runs if run['head_sha'] == source and run['event'] == 'push'
                and run['head_branch'] == 'master']
        run = max(runs, key=lambda item: item['id']) if runs else None
        state = (run['id'], run['status'], run.get('conclusion'), run.get('run_attempt')) if run else None
        if state != previous or run is None:
            url = run['html_url'] if run else 'CI has not appeared yet'
            report(f"Waiting for source CI: {source}\n{url}\n"
                   f"Status: {run['status'] if run else 'not started'}"
                   f" / {run.get('conclusion') or 'pending' if run else 'pending'}")
            previous = state
        if run and run['status'] == 'completed':
            if run.get('conclusion') == 'success':
                report(f"Source CI passed: {run['html_url']}. Release can start.")
                return run
            jobs = fetch(repo, f"actions/runs/{run['id']}/jobs?filter=latest&per_page=100")['jobs']
            failures = [f"{job['name']}: {job.get('conclusion')} ({job['html_url']})"
                        for job in jobs if job.get('conclusion') in ('failure', 'cancelled', 'timed_out', 'action_required')]
            raise RuntimeError(f"Source CI {run.get('conclusion')}: {run['html_url']}\n"
                               + '\n'.join(failures) + '\nNo archive or upload was started. Fix CI, then retry this gate.')
        if clock() >= deadline:
            raise TimeoutError('Source CI did not finish within the release wait budget. No upload started.')
        pause(interval)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY', 'zigdanis/GrowingUp'))
    args = parser.parse_args()

    def report(message):
        print(message, flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            Path(os.environ['GITHUB_STEP_SUMMARY']).write_text('### TestFlight: source CI\n\n' + message + '\n')

    try:
        wait_for_ci(args.repo, args.source, report=report)
    except (ValueError, RuntimeError, TimeoutError, OSError, subprocess.SubprocessError) as error:
        report(str(error))
        raise SystemExit(1) from None


if __name__ == '__main__':
    main()
