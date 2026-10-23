#!/usr/bin/env python3
"""Focused screenshot-only native capture, with all build evidence outside the checkout."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ('GrowingUp', 'Core', 'Widget', 'GrowingUpUITests', 'GrowingUp.xcodeproj',
          'docs/app-store-demo-photos', 'marketing/fonts')

def run(args, log=None):
    if log:
        with log.open('w') as out:
            result = subprocess.run(args, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT)
        if result.returncode:
            print(f'Failed ({result.returncode}): inspect {log}', flush=True)
            sys.exit(result.returncode)
    else:
        subprocess.run(args, cwd=ROOT, check=True)

def run_with_host_captures(args, log, udid, folder):
    """Run the test while the host captures the inner display, which XCTest cannot read.

    The test prints `HOST_CAPTURE <checkpoint>` and waits; each marker gets one simctl screenshot.
    """
    host = folder / 'host'
    host.mkdir()
    with log.open('w') as out:
        process = subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in process.stdout:
            out.write(line)
            marker = re.search(r'HOST_CAPTURE (\S+)', line)
            if marker:
                subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', '--display=primary-1', str(host / f'{marker.group(1)}.png')],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if process.wait():
            print(f'Failed ({process.returncode}): inspect {log}', flush=True)
            sys.exit(process.returncode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--family', required=True, choices=('dynamic-island', 'face-id', 'home-button', 'duo-outer', 'duo-inner'))
    parser.add_argument('--runtime', default='26-5', help='Simulator runtime, for example 27-1')
    parser.add_argument('--xcode', default='26.6', help='Xcode version that builds and runs the capture')
    parser.add_argument('--width', required=True, type=int)
    parser.add_argument('--height', required=True, type=int)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--derived-data', required=True, type=Path)
    parser.add_argument('--built-products', type=Path, help='Reuse the same compiled app on another native simulator')
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('Capture evidence must be outside the repository')
    output.mkdir(parents=True, exist_ok=False)
    head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
    hashes = {}
    for folder in INPUTS:
        for path in sorted((ROOT / folder).rglob('*')):
            if path.is_file():
                hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    metadata = {'workflow': 'local-screenshot-only', 'head_sha':head, 'checkout_sha':head,
                'run_id':output.name, 'run_attempt':'1', 'device':args.device,
                'simulator_udid':args.udid, 'family':args.family, 'runtime':args.runtime,
                'xcode':args.xcode, 'native_width':args.width, 'native_height':args.height,
                'capture_input_hashes':hashes}
    (output / 'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    products = None
    if args.built_products:
        products = output / 'build-products'
        shutil.copytree(args.built_products.resolve(), products)
        configurations = list(products.glob('*.xctestrun'))
        if len(configurations) != 1:
            raise ValueError('Expected exactly one reusable test configuration')
        configuration_path = configurations[0]
        configuration = plistlib.loads(configuration_path.read_bytes())
    base=['xcodebuild','-project','GrowingUp.xcodeproj','-scheme','GrowingUpUI',
          '-derivedDataPath',str(args.derived_data.resolve()),'-destination',f'id={args.udid}',
          '-parallel-testing-enabled','NO','-only-testing:GrowingUpUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots',
          'GROWINGUP_APP_STORE_CAPTURE=1',f'GROWINGUP_APP_STORE_PHOTOS={ROOT}/docs/app-store-demo-photos',
          'CODE_SIGNING_ALLOWED=NO']
    host_capture = args.family == 'duo-inner'
    if host_capture:
        base.append('GROWINGUP_APP_STORE_HOST_CAPTURE=1')
    for locale in ('en','ru'):
        folder=output / locale; folder.mkdir()
        (folder/'metadata.json').write_text(json.dumps(metadata | {'locale':locale},indent=2)+'\n')
        print(f'{args.device}: {locale} build-for-testing; {folder}',flush=True)
        if products:
            configuration['GrowingUpUITests']['EnvironmentVariables']['GROWINGUP_APP_STORE_LOCALE'] = locale
            configuration_path.write_bytes(plistlib.dumps(configuration))
            (folder/'build.log').write_text(f'Reused compiled native app from {args.built_products}\n')
        else:
            run(base[:1]+['build-for-testing']+base[1:]+[f'GROWINGUP_APP_STORE_LOCALE={locale}'],folder/'build.log')
        print(f'{args.device}: {locale} capture started',flush=True)
        if products:
            test = ['xcodebuild','test-without-building','-xctestrun',str(configuration_path),
                    '-destination',f'id={args.udid}','-parallel-testing-enabled','NO',
                    '-only-testing:GrowingUpUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots']
        else:
            test = base[:1]+['test-without-building']+base[1:]+[f'GROWINGUP_APP_STORE_LOCALE={locale}']
        if host_capture:
            run_with_host_captures(test+['-resultBundlePath',str(folder/'UI.xcresult')],folder/'xcodebuild.log',args.udid,folder)
        else:
            run(test+['-resultBundlePath',str(folder/'UI.xcresult')],folder/'xcodebuild.log')
        run(['xcrun','xcresulttool','export','attachments','--path',str(folder/'UI.xcresult'),
             '--output-path',str(folder/'attachments')])
        for kind in ('summary','tests'):
            data=subprocess.check_output(['xcrun','xcresulttool','get','test-results',kind,
                                           '--path',str(folder/'UI.xcresult')])
            (folder/('test-summary.json' if kind=='summary' else 'tests.json')).write_bytes(data)
        print(f'{args.device}: {locale} native capture exported',flush=True)
    print(f'Completed screenshot-only capture: {output}',flush=True)

if __name__ == '__main__':
    main()
