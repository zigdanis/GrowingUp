#!/usr/bin/env python3
"""Upload only the six approved GrowingUp previews; no deletes or submissions.

Apple's App Asset Library reserve/upload/commit/placement API.
Credentials are loaded locally, never serialized in receipts or logs.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[4]
OUT = Path.home() / 'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013/asc-upload'
APP = '1461697772'
VERSION = '4dccceea-13f4-4f10-8153-d1106ec1731c'
GROUPS = {'di': 'IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE',
          'face-id': 'IPHONE_FACE_ID_LARGE_PROFILE',
          'home-button': 'IPHONE_HOME_BUTTON_MEDIUM_PROFILE'}
READY = {'PREPARE_FOR_SUBMISSION', 'APPROVED'}


def now():
    return datetime.now(timezone.utc).isoformat()


def save(name, value):
    path = OUT / name
    temp = path.with_suffix('.new')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)


def rel(kind, identifier):
    return {'data': {'type': kind, 'id': identifier}}


def snapshot(api, locs):
    return {locale: api.collection(f'/v1/appStoreVersionLocalizations/{identifier}/placements',
                                   **{'sort': 'placementGroupPosition', 'include': 'image,video'})
            for locale, identifier in locs.items()}


def protected(snapshot_value):
    # Existing placements must keep IDs, assets, group, type, state, and order.
    return {locale: [(p['id'], p['attributes'], p.get('relationships', {}))
                     for p in ps] for locale, ps in snapshot_value.items()}


def check_version(api):
    version = api.resource(f'/v1/appStoreVersions/{VERSION}')
    attrs = version['attributes']
    if attrs['versionString'] != '2.1.0' or attrs['appStoreState'] != 'PREPARE_FOR_SUBMISSION':
        raise ValueError('Expected existing editable 2.1.0 draft; refusing metadata changes')


def preflight(api, locs, catalog, library, current):
    provenance = json.loads((ROOT / 'marketing/app-store/previews/provenance.json').read_text())
    exports = provenance['exports']
    assert len(exports) == 6
    placement_type = next(t for t in catalog['placementTypes'] if t['placementTypeId'] == 'APP_PREVIEW')
    assert 'APP_SCREENSHOTS_AND_PREVIEWS' in placement_type['acceptsAssetCategories']
    feature = next(f for f in catalog['features'] if f['featureId'] == 'APP_STORE_VERSIONS')
    policy = next(p for p in feature['placementPolicies'] if p['placementType'] == 'APP_PREVIEW')
    files = []
    for item in exports:
        path = ROOT / item['delivered_file']
        content = path.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        assert digest == item['sha256'] and len(content) == item['size']
        assert item['full_decode_passed'] and item['ui_test_passed'] and item['faststart_verified']
        locale = 'en-US' if item['locale'] == 'en' else 'ru'
        group = GROUPS[item['kind']]
        assert locale in locs
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
                                                    '-show_format', '-of', 'json', str(path)]))
        video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
        audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
        assert video['codec_name'] == 'h264' and video['profile'] == 'High' and video['level'] <= 40
        assert video['field_order'] == 'progressive' and video['pix_fmt'] == 'yuv420p'
        assert video['avg_frame_rate'] == '30/1' and int(video['nb_frames']) == 750
        assert audio['codec_name'] == 'aac' and audio['channels'] == 2
        assert int(audio['sample_rate']) in [44100, 48000] and float(probe['format']['duration']) == 25
        specs = [s for s in catalog['videoSpecs']
                 if s['dimensions'] == {'minWidth': video['width'], 'maxWidth': video['width'],
                                        'minHeight': video['height'], 'maxHeight': video['height']}
                 and path.suffix in s['fileExtensions'] and len(content) <= s['maxFileSize']
                 and any(f['minFps'] <= 30 <= f['maxFps'] for f in s['frameRates'])
                 and s['duration'] == {'min': 'PT15S', 'max': 'PT30S'}]
        assert len(specs) == 1
        spec = specs[0]['specId']
        mapping = next(m for m in placement_type['specMappings'] if m['placementGroupId'] == group)
        assert spec in mapping['specs']
        limit = next(l['maxCount'] for l in policy['groupLimits'] if group in l['groupIds'])
        previews = [p for p in current[locale] if p['attributes']['placementType'] == 'APP_PREVIEW'
                    and p['attributes']['placementGroup'] == group]
        reference = f'GrowingUp-preview:20261014:{locale}:{item["kind"]}:{digest}'
        assets = api.collection(f'/v1/appAssetLibraries/{library}/videos',
                                **{'filter[referenceName]': reference})
        assert len(assets) <= 1
        existing_ids = {a['id'] for a in assets}
        already = [p for p in previews if p.get('relationships', {}).get('video', {}).get('data', {}).get('id') in existing_ids]
        assert len(already) <= 1
        assert len(previews) + (0 if already else 1) <= limit
        files.append({'path': str(path), 'file': path.name, 'locale': locale, 'group': group,
                      'sha256': digest, 'size': len(content), 'spec_id': spec, 'reference': reference,
                      'existing_asset_id': assets[0]['id'] if assets else None,
                      'existing_placement_id': already[0]['id'] if already else None})
    assert len({(f['locale'], f['group']) for f in files}) == 6
    return files


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--upload', action='store_true')
    opts = args.parse_args()
    auth_spec = importlib.util.spec_from_file_location('local_auth', Path(__file__).with_name('local-auth.py'))
    auth = importlib.util.module_from_spec(auth_spec)
    auth_spec.loader.exec_module(auth)
    api = auth.api
    original_request = api.request

    def guarded_request(method, path, data=None):
        if method not in {'GET', 'POST', 'PATCH'}:
            raise ValueError('Deletes and other operations are prohibited')
        if method == 'POST' and path not in {'/v1/appAssetLibraryVideos', '/v1/appAssetLibraryPlacements'}:
            raise ValueError('Only new preview assets/placements may be created')
        if method == 'POST' and path.endswith('Placements') and data['data']['attributes']['placementType'] != 'APP_PREVIEW':
            raise ValueError('Screenshot mutations are prohibited')
        if method == 'PATCH' and (not path.startswith('/v1/appAssetLibraryVideos/') or data['data']['attributes'] != {'uploaded': True}):
            raise ValueError('Only new video upload commits are permitted')
        return original_request(method, path, data)

    api.request = guarded_request
    check_version(api)
    app = api.resource(f'/v1/apps/{APP}')
    assert app['attributes']['bundleId'] == 'pro.ziganshin.GrowingUp'
    library = api.resource(f'/v1/apps/{APP}/assetLibrary')['id']
    locs = {l['attributes']['locale']: l['id'] for l in
            api.collection(f'/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations')
            if l['attributes']['locale'] in {'en-US', 'ru'}}
    assert len(locs) == 2
    catalog = api.collection('/v1/appAssetLibraryRefData')[0]['attributes']
    before = snapshot(api, locs)
    if not (OUT / 'placements-before-upload.json').exists():
        save('placements-before-upload.json', before)
    save('live-catalog.json', catalog)
    files = preflight(api, locs, catalog, library, before)
    receipt = {'success': False, 'started_at_utc': now(), 'operation': 'upload' if opts.upload else 'preflight',
               'app_id': APP, 'version': '2.1.0', 'version_id': VERSION, 'library_id': library,
               'localizations': locs, 'poster_timecode': '00:00:02:00', 'previews': files,
               'source_commit': '0d60b645b4bf42d98f5c294079b9e59c10a730ca',
               'authorization': 'Danis explicitly requested CLI upload of six completed no-confetti previews',
               'deleted_assets_or_placements': 0, 'submitted_for_review': False,
               'build_uploads': 0, 'simulator_boots': 0}
    filename = 'upload-receipt.json' if opts.upload else 'preflight.json'
    if opts.upload and (OUT / filename).exists():
        previous = json.loads((OUT / filename).read_text())
        receipt['started_at_utc'] = previous['started_at_utc']
        for f in files:
            prior = next((p for p in previous['previews'] if p['sha256'] == f['sha256']), {})
            for key in ['committed_at_utc']:
                if key in prior:
                    f[key] = prior[key]
    save(filename, receipt)
    print('Preflight passed: six approved hashes, Apple live video specs, editable 2.1.0, group capacity', flush=True)
    if not opts.upload:
        receipt['success'] = True
        save(filename, receipt)
        return
    try:
        for index, f in enumerate(files, 1):
            check_version(api)
            print(f'Upload {index}/6: {f["file"]}', flush=True)
            asset = api.resource(f'/v1/appAssetLibraryVideos/{f["existing_asset_id"]}') if f['existing_asset_id'] else api.create(
                'appAssetLibraryVideos', {'fileName': f['file'], 'fileSize': f['size'],
                  'category': 'APP_SCREENSHOTS_AND_PREVIEWS', 'referenceName': f['reference'],
                  'previewFrameTimeCode': receipt['poster_timecode']},
                {'assetLibrary': rel('appAssetLibraries', library)})
            f['asset_id'] = asset['id']
            f['state'] = asset['attributes']['state']
            save(filename, receipt)
            attrs = asset['attributes']
            assert attrs['fileName'] == f['file'] and attrs['fileSize'] == f['size']
            if attrs['state'] == 'AWAITING_UPLOAD':
                content = Path(f['path']).read_bytes()
                assert hashlib.sha256(content).hexdigest() == f['sha256']
                api.upload(attrs['uploadOperations'], content)
                api.request('PATCH', f'/v1/appAssetLibraryVideos/{asset["id"]}', {'data': {
                    'type': 'appAssetLibraryVideos', 'id': asset['id'], 'attributes': {'uploaded': True}}})
                f['state'] = 'UPLOAD_COMPLETE'
                f['committed_at_utc'] = now()
                save(filename, receipt)
            elif attrs['state'] not in READY | {'UPLOAD_COMPLETE', 'COMPLETE'}:
                raise ValueError(f'Existing video state {attrs["state"]}; inspect before retry')
        deadline = time.monotonic() + 1800
        cycle = 0
        while True:
            complete = 0
            check_version(api)
            for f in files:
                asset = api.resource(f'/v1/appAssetLibraryVideos/{f["asset_id"]}')
                attrs = asset['attributes']
                f['state'] = attrs['state']
                f['state_details'] = attrs.get('stateDetails')
                if attrs['state'] == 'FAILED':
                    raise ValueError(f'Apple processing FAILED for {f["file"]}; state details retained in receipt')
                if attrs['state'] not in READY:
                    continue
                assert attrs['specId'] == f['spec_id']
                assert attrs['fileName'] == f['file'] and attrs['fileSize'] == f['size']
                assert attrs['previewFrameTimeCode'] == receipt['poster_timecode']
                frame = attrs.get('previewFrameImage') or {}
                frame_state = frame.get('state')
                if isinstance(frame_state, dict):
                    frame_state = frame_state.get('state')
                f['preview_frame_state'] = frame_state
                if frame_state == 'FAILED':
                    raise ValueError(f'Apple preview frame FAILED for {f["file"]}')
                if frame_state != 'COMPLETE':
                    continue
                ps = api.collection(f'/v1/appStoreVersionLocalizations/{locs[f["locale"]]}/placements',
                                    **{'filter[placementType]': 'APP_PREVIEW', 'filter[placementGroup]': f['group'], 'include': 'video'})
                matches = [p for p in ps if p['relationships']['video']['data']['id'] == f['asset_id']]
                assert len(matches) <= 1
                placement = matches[0] if matches else api.create('appAssetLibraryPlacements',
                   {'placementType': 'APP_PREVIEW', 'placementGroup': f['group']},
                   {'video': rel('appAssetLibraryVideos', f['asset_id']),
                    'appStoreVersionLocalization': rel('appStoreVersionLocalizations', locs[f['locale']])})
                f['placement_id'] = placement['id']
                f['placement_state'] = placement['attributes']['state']
                if f['placement_state'] not in {'ACTIVE', 'PARENT_PREPARE_FOR_SUBMISSION'}:
                    continue
                complete += 1
            save(filename, receipt)
            if cycle % 2 == 0 or complete == 6:
                print('Apple processing/readback:', complete, '/6 complete;',
                      [(f['file'], f.get('state'), f.get('preview_frame_state'), f.get('placement_state')) for f in files], flush=True)
            if complete == 6:
                break
            if time.monotonic() > deadline:
                raise TimeoutError('Apple still processing; resume same CLI without duplicating assets')
            cycle += 1
            time.sleep(15)
        after = snapshot(api, locs)
        created_ids = {f['placement_id'] for f in files if not f['existing_placement_id']}
        preserved = {locale: [p for p in ps if p['id'] not in created_ids] for locale, ps in after.items()}
        assert protected(before) == protected(preserved), 'Existing placements changed during upload; inspect receipts'
        check_version(api)
        save('placements-after-upload.json', after)
        receipt.update(success=True, verified_state='PREPARE_FOR_SUBMISSION',
                       existing_placements_preserved=True,
                       existing_placement_count=sum(map(len, before.values())), completed_at_utc=now())
        save(filename, receipt)
        print('SUCCESS: all six APP_PREVIEW assets processed, poster frames COMPLETE, placements ACTIVE; existing placements preserved', flush=True)
    except Exception as error:
        receipt['error'] = str(error) if isinstance(error, (ValueError, RuntimeError, TimeoutError, AssertionError)) else type(error).__name__
        save(filename, receipt)
        print('Upload stopped:', receipt['error'], flush=True)
        raise SystemExit(1) from None


if __name__ == '__main__':
    main()
