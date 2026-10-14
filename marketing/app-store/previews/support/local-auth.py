"""Load existing local ASC credentials without printing or copying them."""
import importlib.util
import json
import os
import sys
sys.dont_write_bytecode = True
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('growingup_metadata', ROOT / 'scripts/app-store-metadata.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
directory = Path.home() / 'Documents/Work/Personal'
config = json.loads((directory / 'asc_api_key.json').read_text())
key_path = directory / f'AuthKey_{config["key_id"]}.p8'
assert key_path.is_file()
os.environ.update(ASC_KEY_PATH=str(key_path), ASC_KEY_ID=config['key_id'], ASC_ISSUER_ID=config['issuer_id'])
api = module.Apple()
