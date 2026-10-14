"""Local executor for the same Fastlane release engine used by GitHub Actions."""
import base64
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import platform
import stat
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CONFIG = Path.home() / '.config/growingup-testflight/local.json'
STATE = Path.home() / 'Library/Application Support/GrowingUp/releases'
BUNDLE_PATH = Path.home() / '.local/share/growingup/bundle'


def restricted(path):
    path = Path(path).expanduser().resolve(strict=True)
    mode = path.stat()
    if not stat.S_ISREG(mode.st_mode) or mode.st_uid != os.getuid() or mode.st_mode & 0o077:
        raise ValueError('Use an owner-only regular credential file (chmod 600) outside the repository')
    if ROOT in path.parents or any((parent / '.git').exists() for parent in path.parents):
        raise ValueError('Credential files must be outside Git checkouts')
    return path


def load_key(path):
    try:
        data = json.loads(restricted(path).read_text())
        if not all(isinstance(data.get(key), str) and data[key].strip() for key in ('key_id', 'issuer_id', 'key')):
            raise ValueError()
        return data
    except (ValueError, KeyError, TypeError):
        raise ValueError('Use an App Store Connect API JSON key with key_id, issuer_id and key fields') from None


def bundle_environment():
    return {**os.environ, 'BUNDLE_PATH': str(BUNDLE_PATH), 'BUNDLE_FROZEN': 'true',
            'FASTLANE_SKIP_UPDATE_CHECK': 'true', 'FASTLANE_SKIP_DOCS': 'true',
            'FASTLANE_HIDE_CHANGELOG': 'true', 'FASTLANE_DISABLE_COLORS': '1'}


def setup_local(api_key=None):
    if platform.system() != 'Darwin':
        raise RuntimeError('Local TestFlight deployment requires macOS and Xcode; use cloud on this machine')
    if api_key:
        path = restricted(api_key)
        load_key(path)
        CONFIG.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        CONFIG.write_text(json.dumps({'api_key_file': str(path)}, indent=2) + '\n')
        CONFIG.chmod(0o600)
    if not CONFIG.exists():
        raise RuntimeError('Run scripts/testflight setup local --api-key /path/to/asc_api_key.json once')
    config = json.loads(restricted(CONFIG).read_text())
    load_key(config['api_key_file'])
    result = subprocess.run(['bundle', 'install', '--jobs', '4'], cwd=ROOT, env=bundle_environment())
    if result.returncode:
        raise RuntimeError('Could not install the locked Fastlane dependencies')
    print('Local setup saved. Credentials stay on this Mac; next run scripts/testflight check local.')


def last_local_id():
    path = STATE / 'latest.json'
    if not path.exists():
        raise RuntimeError('No previous local release; specify its release ID')
    return json.loads(path.read_text())['release_id']


def save_latest(release_id, attempt_id):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = STATE / 'latest.json'
    # Serialize pointer updates across different releases and replace atomically so
    # status/resume never sees half-written JSON or an older concurrent attempt.
    with (STATE / '.latest.lock').open('a+') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        current = json.loads(path.read_text()) if path.exists() else {}
        if int(current.get('attempt_id', current.get('release_id', '0'))) > int(attempt_id):
            return
        with tempfile.NamedTemporaryFile(mode='w', dir=STATE, prefix='.latest-', delete=False) as temporary:
            temporary.write(json.dumps({'release_id': release_id, 'attempt_id': attempt_id}) + '\n')
            temporary_path = Path(temporary.name)
        try:
            os.replace(temporary_path, path)
        finally:
            temporary_path.unlink(missing_ok=True)


def remember_recorded_release(directory, release_id, attempt_id):
    try:
        recorded = json.loads((directory / 'release.json').read_text())
    except (OSError, ValueError):
        return False
    if recorded.get('release_id') != release_id or not recorded.get('receipt_id'):
        return False
    save_latest(release_id, attempt_id)
    return True


@contextmanager
def release_file_lock(directory):
    """Keep one build/upload process per local artifact directory."""
    path = directory / '.lock'
    with path.open('a+') as lock:
        path.chmod(0o600)
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('This local release is already running; wait for it to finish before resuming') from None
        yield lock.fileno()


@contextmanager
def credentials(api):
    if platform.system() != 'Darwin':
        raise RuntimeError('Local TestFlight deployment requires macOS and Xcode; use cloud on this machine')
    if not CONFIG.exists():
        raise RuntimeError('Run scripts/testflight setup local --api-key /path/to/asc_api_key.json once')
    config = json.loads(restricted(CONFIG).read_text())
    key = load_key(config['api_key_file'])
    variables = {item['name']: item['value'] for item in api('actions/variables')['variables']}
    password = subprocess.run(['security', 'find-generic-password', '-s', 'pro.ziganshin.GrowingUp.match',
                               '-a', 'growingup-ci-20261004', '-w'], capture_output=True, text=True)
    if password.returncode:
        raise RuntimeError('The GrowingUp Match password is missing from the Mac login Keychain')
    token = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True)
    if token.returncode:
        raise RuntimeError('GitHub CLI is not signed in; run gh auth login')
    basic = base64.b64encode(('x-access-token:' + token.stdout.strip()).encode()).decode()
    env = bundle_environment()
    env.update({name: variables[name] for name in ('APPLE_TEAM_ID', 'MATCH_GIT_URL', 'MATCH_GIT_BRANCH')})
    env.update({name: variables[name] for name in ('BETA_GROUP_ID', 'BETA_TESTER_ID') if variables.get(name)})
    if env['MATCH_GIT_URL'].startswith('git@github.com:'):
        env['MATCH_GIT_URL'] = env['MATCH_GIT_URL'].replace('git@github.com:', 'https://github.com/', 1)
    # Git reads credentials from the environment, never command arguments or files.
    env.update({'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'http.https://github.com/.extraheader',
                'GIT_CONFIG_VALUE_0': 'Authorization: Basic ' + basic, 'GIT_TERMINAL_PROMPT': '0',
                'MATCH_PASSWORD': password.stdout.rstrip('\n'),
                'ASC_KEY_ID': key['key_id'], 'ASC_ISSUER_ID': key['issuer_id']})
    content = base64.b64decode(key['key']).decode() if key.get('is_key_content_base64') else key['key']
    secrets = [env['MATCH_PASSWORD'], token.stdout.strip(), basic, key['key_id'], key['issuer_id'],
               content, *content.splitlines()]
    with tempfile.TemporaryDirectory(prefix='growingup-release-keys-') as directory:
        os.chmod(directory, 0o700)
        path = Path(directory) / 'AuthKey.p8'
        path.write_text(content)
        path.chmod(0o600)
        env['ASC_KEY_PATH'] = str(path)
        yield env, sorted({s for s in secrets if s}, key=len, reverse=True)


def run_local(operation, source_sha, version, notes, api, release_id=None):
    if operation in ('resume', 'status', 'update-notes'):
        release_id = release_id or last_local_id()
    run_id = str(time.time_ns())
    release_id = release_id or run_id
    if not release_id.isdecimal():
        raise ValueError('Release ID must be numeric')
    directory = STATE / release_id
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    lane = {'check': 'release_plan', 'deploy': 'app_store', 'archive': 'release_archive',
            'resume': 'app_store', 'status': 'release_status', 'update-notes': 'release_notes'}[operation]
    with release_file_lock(directory) as lock_fd, credentials(api) as (env, secrets):
        check = subprocess.run(['bundle', 'check'], cwd=ROOT, env=env, capture_output=True)
        if check.returncode:
            raise RuntimeError('Local Fastlane dependencies are missing; run scripts/testflight setup local')
        with tempfile.TemporaryDirectory(prefix='growingup-release-source-') as temporary:
            source = Path(temporary) / 'source'
            result = subprocess.run(['git', 'worktree', 'add', '--detach', str(source), source_sha], cwd=ROOT,
                                    capture_output=True)
            if result.returncode:
                raise RuntimeError('Release source is not available locally; run git fetch origin and retry')
            try:
                env.update({'RELEASE_EXECUTOR': 'local', 'GITHUB_REPOSITORY': 'zigdanis/GrowingUp',
                            'GITHUB_RUN_ID': run_id, 'RELEASE_URL': 'https://github.com/zigdanis/GrowingUp',
                            'SOURCE_SHA': source_sha, 'MARKETING_VERSION': version,
                            'RELEASE_SOURCE_DIR': str(source), 'RELEASE_TEMP': str(directory),
                            'RELEASE_RECEIPT': str(directory / 'release.json'), 'FL_REPORT_PATH': str(directory),
                            'RESUME_RUN_ID': release_id if operation in ('resume', 'status', 'update-notes') else ''})
                env.update({'NOTES_EN': notes.get('notes_en', ''), 'NOTES_RU': notes.get('notes_ru', '')})
                log_path = directory / (operation + '.log')
                print(f'Local {operation}: {release_id}\nLog: {log_path}', flush=True)
                command = ['bundle', 'exec', 'fastlane', 'ios', lane]
                remembered = operation not in ('deploy', 'archive', 'resume')
                with log_path.open('w') as log:
                    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                               stderr=subprocess.STDOUT, text=True, bufsize=1, pass_fds=(lock_fd,))
                    try:
                        for line in process.stdout:
                            if not remembered:
                                remembered = remember_recorded_release(directory, release_id, run_id)
                            for secret in secrets:
                                line = line.replace(secret, '[REDACTED]')
                            log.write(line)
                            log.flush()
                            print(line, end='', flush=True)
                        code = process.wait()
                    except BaseException:
                        process.terminate()
                        process.wait()
                        raise
                    finally:
                        if not remembered:
                            remember_recorded_release(directory, release_id, run_id)
                if code:
                    followup = f'; resume release {release_id} after fixing the cause' if operation != 'check' else ''
                    raise RuntimeError(f'Local {operation} stopped. Inspect {log_path}{followup}.')
                return directory / 'release.json'
            finally:
                subprocess.run(['git', 'worktree', 'remove', '--force', str(source)], cwd=ROOT, capture_output=True)
