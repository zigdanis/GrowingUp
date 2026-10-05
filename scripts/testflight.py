#!/usr/bin/env python3
"""Dispatch and inspect manually commanded TestFlight releases from Linux."""
import argparse
import json
import subprocess
import sys

REPO = 'zigdanis/GrowingUp'
ENVIRONMENT = 'testflight'
REQUIRED_SECRETS = {'ASC_PRIVATE_KEY', 'ASC_KEY_ID', 'ASC_ISSUER_ID', 'MATCH_PASSWORD', 'MATCH_GIT_PRIVATE_KEY'}


def gh(*args, data=None):
    for _ in range(3 if data is None else 1):
        result = subprocess.run(['gh', *args], input=json.dumps(data) if data is not None else None,
                                text=True, capture_output=True)
        if result.returncode == 0:
            return result.stdout
    raise RuntimeError(result.stderr.strip())


def api(path):
    return json.loads(gh('api', f'repos/{REPO}/{path}'))


def readiness():
    environment = api(f'environments/{ENVIRONMENT}')
    policy = environment.get('deployment_branch_policy') or {}
    branches = api(f'environments/{ENVIRONMENT}/deployment-branch-policies')['branch_policies']
    if not policy.get('custom_branch_policies') or {(p['name'], p['type']) for p in branches} != {('master', 'branch')}:
        raise RuntimeError('The testflight environment must allow only the master branch')
    names = {s['name'] for s in api(f'environments/{ENVIRONMENT}/secrets')['secrets']}
    missing = sorted(REQUIRED_SECRETS - names)
    print('Release environment: master only')
    print('Required secret names present: ' + ', '.join(sorted(REQUIRED_SECRETS & names)))
    if missing:
        raise RuntimeError('Missing environment secrets: ' + ', '.join(missing))
    print('Credentials are present; the cloud preflight must still validate their access and signing.')


def receipt(run_id):
    pages = json.loads(gh('api', f'repos/{REPO}/releases?per_page=100', '--paginate', '--slurp'))
    matches = [r for page in pages for r in page if r['draft'] and r['tag_name'] == 'testflight/receipts/' + run_id]
    if len(matches) != 1:
        raise RuntimeError('No unique release receipt for that original run ID')
    return json.loads(matches[0]['body'])


def read_notes(path):
    with open(path) as notes_file:
        notes = json.load(notes_file)
    if (not isinstance(notes, dict) or set(notes) != {'en', 'ru'} or
            not all(isinstance(v, str) and v.strip() and len(v.encode()) <= 4000 for v in notes.values())):
        raise ValueError('Notes JSON needs nonempty en and ru strings, at most 4000 bytes each')
    return {'notes_en': notes['en'], 'notes_ru': notes['ru']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    sub.add_parser('ready')
    sub.add_parser('preflight')
    deploy = sub.add_parser('deploy')
    deploy.add_argument('version', help='next, or a new marketing version')
    deploy.add_argument('source', help='source ref or full SHA on master')
    deploy.add_argument('notes', help='JSON file with en and ru changes/testing strings; no credentials')
    for name in ('resume', 'status'):
        sub.add_parser(name).add_argument('run_id')
    notes_update = sub.add_parser('notes', help='Update localized notes on an existing build without uploading')
    notes_update.add_argument('run_id')
    notes_update.add_argument('notes', help='JSON file with en and ru changes/testing strings')
    args = parser.parse_args()
    readiness()
    if args.operation == 'ready':
        return
    active = json.loads(gh('run', 'list', '--repo', REPO, '--workflow', 'testflight.yml', '--limit', '100',
                          '--json', 'databaseId,status,url'))
    pending = [r for r in active if r['status'] != 'completed']
    if pending:
        raise RuntimeError('A release operation is already pending: ' + pending[0]['url'])
    payload = {'operation': args.operation}
    if args.operation in ('resume', 'status', 'notes'):
        if not args.run_id.isdecimal():
            raise ValueError('run_id must be numeric')
        recorded = receipt(args.run_id)
        payload.update(source_sha=recorded['source_sha'], marketing_version=recorded['version'],
                       resume_run_id=args.run_id)
        print(f"Recorded release: {recorded['version']} ({recorded['build_number']}), {recorded['phase']}")
        if args.operation == 'notes':
            payload.update(read_notes(args.notes))
    else:
        ref = args.source if args.operation == 'deploy' else 'master'
        source = api('commits/' + ref)['sha']
        payload['source_sha'] = source
        if args.operation == 'deploy':
            payload.update(read_notes(args.notes))
            ci = json.loads(gh('run', 'list', '--repo', REPO, '--workflow', 'ci.yml', '--commit', source,
                               '--limit', '1', '--json', 'status,conclusion'))
            if not ci or ci[0]['status'] != 'completed' or ci[0]['conclusion'] != 'success':
                raise RuntimeError('The latest CI run for the selected source must pass before deployment')
            payload['marketing_version'] = args.version
    # The current REST API returns the exact run ID/URL, avoiding polling races.
    result = gh('api', f'repos/{REPO}/actions/workflows/testflight.yml/dispatches', '--method', 'POST', '--input', '-',
                '--header', 'X-GitHub-Api-Version: 2026-03-10',
                data={'ref': 'master', 'inputs': payload})
    run = json.loads(result)
    print('Dispatched TestFlight ' + args.operation + ' for source ' + payload['source_sha'])
    print(run['html_url'])
    print('Monitor: gh run watch ' + str(run['workflow_run_id']) + ' --repo ' + REPO + ' --exit-status')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
