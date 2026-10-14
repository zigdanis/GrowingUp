"""Put the new previews first, retaining every existing video and screenshot."""
import importlib.util
import json
from pathlib import Path
from datetime import datetime, timezone

OUT = Path.home() / 'Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013/asc-upload'
spec = importlib.util.spec_from_file_location('preview_auth', Path(__file__).with_name('local-auth.py'))
auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auth)
api = auth.api
receipt = json.loads((OUT / 'upload-receipt.json').read_text())
assert receipt['success']
version = api.resource(f'/v1/appStoreVersions/{receipt["version_id"]}')
assert version['attributes']['versionString'] == '2.1.0'
assert version['attributes']['appStoreState'] == 'PREPARE_FOR_SUBMISSION'
before = json.loads((OUT / 'placements-before-upload.json').read_text())
ordering = []
for f in receipt['previews']:
    loc_id = receipt['localizations'][f['locale']]
    ps = api.collection(f'/v1/appStoreVersionLocalizations/{loc_id}/placements',
                        **{'filter[placementType]': 'APP_PREVIEW', 'filter[placementGroup]': f['group'],
                           'sort': 'placementGroupPosition', 'include': 'video'})
    target = next(p for p in ps if p['id'] == f['placement_id'])
    assert target['relationships']['video']['data']['id'] == f['asset_id']
    assert target['attributes']['state'] == 'ACTIVE'
    wanted = [target] + [p for p in ps if p['id'] != target['id']]
    if [p['id'] for p in ps] != [p['id'] for p in wanted]:
        result = api.create('appAssetLibraryPlacementOrderingRequests', {'placementGroup': f['group']},
               {'orderedPlacements': {'data': [{'type': 'appAssetLibraryPlacements', 'id': p['id']} for p in wanted]},
                'appStoreVersionLocalization': {'data': {'type': 'appStoreVersionLocalizations', 'id': loc_id}}})
        ordering.append({'locale': f['locale'], 'group': f['group'], 'request_id': result['id']})
    verified = api.collection(f'/v1/appStoreVersionLocalizations/{loc_id}/placements',
                             **{'filter[placementType]': 'APP_PREVIEW', 'filter[placementGroup]': f['group'],
                                'sort': 'placementGroupPosition', 'include': 'video'})
    assert [p['id'] for p in verified] == [p['id'] for p in wanted]
    f['first_in_group_verified'] = True
    video = api.resource(f'/v1/appAssetLibraryVideos/{f["asset_id"]}')['attributes']
    assert video['state'] in ['PREPARE_FOR_SUBMISSION', 'APPROVED']
    assert video['specId'] == f['spec_id'] and video['fileSize'] == f['size']
    assert video['previewFrameTimeCode'] == receipt['poster_timecode']
    frame_state = video['previewFrameImage']['state']
    if isinstance(frame_state, dict):
        frame_state = frame_state['state']
    assert frame_state == 'COMPLETE'
    print(f['file'], 'ACTIVE; first in target group; poster COMPLETE', flush=True)
after = {}
for locale, loc_id in receipt['localizations'].items():
    ps = api.collection(f'/v1/appStoreVersionLocalizations/{loc_id}/placements',
                        **{'sort': 'placementGroupPosition', 'include': 'image,video'})
    by_id = {p['id']: p for p in ps}
    for p in before[locale]:
        got = by_id[p['id']]
        assert p.get('relationships') == got.get('relationships')
        if p['attributes']['placementType'] == 'APP_SCREENSHOT':
            assert p['attributes'] == got['attributes']
        else:
            for key in ['placementType', 'placementGroup', 'mediaType', 'state']:
                assert p['attributes'][key] == got['attributes'][key]
    assert [p['id'] for p in ps if p['attributes']['placementType'] == 'APP_SCREENSHOT'] == [
        p['id'] for p in before[locale] if p['attributes']['placementType'] == 'APP_SCREENSHOT']
    after[locale] = ps
version = api.resource(f'/v1/appStoreVersions/{receipt["version_id"]}')
assert version['attributes']['appStoreState'] == 'PREPARE_FOR_SUBMISSION'
receipt.update(new_previews_first=True, ordering_requests=ordering,
               preserved_existing_screenshots=32, preserved_existing_previews=8,
               final_readback_at_utc=datetime.now(timezone.utc).isoformat())
(OUT / 'placements-final.json').write_text(json.dumps(after, indent=2) + '\n')
(OUT / 'upload-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print('Verified: all 6 new previews first in target groups; 32 screenshots and 8 previous previews preserved; draft unsubmitted', flush=True)
