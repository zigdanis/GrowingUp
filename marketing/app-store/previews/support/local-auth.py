"""Load the release ASC key from the SOPS vault without printing it or leaving a copy on disk."""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
sys.dont_write_bytecode = True
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('growingup_metadata', ROOT / 'scripts/app-store-metadata.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
# Same key and vault file as scripts/testflight_local.py; there is no plaintext copy on Fleet machines.
vault_file = Path.home() / 'myai/secrets/growingup/asc-api-key.json'
sops = shutil.which('sops') or next(
    (str(c) for c in (Path.home() / '.local/bin/sops', Path('/opt/homebrew/bin/sops')) if c.exists()), None)
if not sops or not vault_file.exists():
    sys.exit(f'Need sops and the vault file {vault_file} (clone zigdanis/secrets to ~/myai/secrets)')
result = subprocess.run([sops, 'decrypt', str(vault_file)], capture_output=True, text=True)
if result.returncode:
    sys.exit(f'sops could not decrypt {vault_file}')
config = json.loads(result.stdout)
with tempfile.TemporaryDirectory(prefix='growingup-asc-') as directory:
    key_path = Path(directory) / 'AuthKey.p8'
    key_path.touch(mode=0o600)
    key_path.write_text(config['key'])
    os.environ.update(ASC_KEY_PATH=str(key_path), ASC_KEY_ID=config['key_id'], ASC_ISSUER_ID=config['issuer_id'])
    api = module.Apple()  # reads the key into memory; the temporary file is removed on exit
os.environ.pop('ASC_KEY_PATH')
