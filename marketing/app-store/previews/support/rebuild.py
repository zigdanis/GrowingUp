#!/usr/bin/env python3
"""Re-edit archived native footage; never boots a simulator or uploads media."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('family', choices=('di', 'face-id', 'home-button'))
    parser.add_argument('locale', choices=('en', 'ru'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--plan', action='store_true', help='Validate sources and print the render command only')
    args = parser.parse_args()
    support = Path(__file__).resolve().parent
    previews = support.parent
    repo = support.parents[3]
    entries = json.loads((previews / 'sources/index.json').read_text())
    entry = next(e for e in entries if e['kind'] == args.family and e['locale'] == args.locale)
    source_edit = previews / entry['edit']
    edit = json.loads(source_edit.read_text())

    def source(relative):
        path = (source_edit.parent / relative).resolve()
        if not path.is_file() or previews.resolve() not in path.parents:
            raise ValueError('Native input is missing or outside the archive')
        return str(path)

    edit['native_file'] = source(edit['native_file'])
    for segment in edit['segments']:
        if segment['start'] < 0 or segment['end'] <= segment['start']:
            raise ValueError('Invalid native segment timing')
        if 'native_file' in segment:
            segment['native_file'] = source(segment['native_file'])
    if not (support / 'music/Little-Days.wav').is_file():
        raise ValueError('Archived soundtrack is missing')
    output = args.output.expanduser().resolve()
    if output.exists():
        raise ValueError('Choose a new output file to preserve approved media')
    prepared = output.with_suffix('.edit.json')
    command = [sys.executable, str(support / 'render.py'), str(prepared), str(output),
               '--locale', args.locale, '--width', str(entry['size'][0]), '--height', str(entry['size'][1])]
    if args.plan:
        print(json.dumps({'source_edit': str(source_edit), 'resolved_edit': edit,
                          'command': command, 'cwd': str(repo)}, indent=2))
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    prepared.write_text(json.dumps(edit, indent=2) + '\n')
    subprocess.run(command, cwd=repo, check=True)


if __name__ == '__main__':
    main()
