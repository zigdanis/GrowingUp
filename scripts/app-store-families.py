#!/usr/bin/env python3
"""Validate and place explicitly listed native screenshot families on an existing draft.

Never clears other groups, creates a version, or submits media for App Review.
Replacement sets are placed and become ACTIVE before old placements are removed.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location('store_metadata', ROOT / 'scripts/app-store-metadata.py')
m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m)
APP_INPUTS = ('GrowingUp', 'Core', 'Widget', 'GrowingUpUITests', 'GrowingUp.xcodeproj',
              'docs/app-store-demo-photos', 'marketing/fonts')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_sets(manifest, catalog, only_groups=None):
    """Validate the manifest sets; with `only_groups`, only those groups are read and checked."""
    data = json.loads(manifest.read_text())
    if data['app_id'] != '1461697772':
        raise ValueError('Expected the reviewed GrowingUp manifest')
    sets = []
    for entry in data['sets']:
        if only_groups is not None and entry['group'] not in only_groups:
            continue
        folder = (manifest.parent / entry['path']).resolve()
        if folder != manifest.parent.resolve() and manifest.parent.resolve() not in folder.parents:
            raise ValueError('Screenshot folder escapes the manifest directory')
        source = json.loads((folder / 'source.json').read_text())
        # A set lists its files and their native sizes; the older families use the four standard cards.
        listed = entry.get('images') or [{'file': name, 'size': entry['size']} for name in m.FILES]
        images = {locale:[m.screenshot(folder / locale / item['file'],locale) for item in listed] for locale in m.LOCALES}
        outputs = {f'{locale}/{image["path"].name}':image['sha256'] for locale,files in images.items() for image in files}
        if outputs != source['outputs'] or ('images' not in entry and source['size'] != entry['size']):
            raise ValueError('Screenshots do not match the reviewed manifest and provenance')
        for files in images.values():
            for image,item in zip(files,listed):
                if [image['width'],image['height']] != item['size']:
                    raise ValueError('Screenshot dimensions differ from native device dimensions')
                group,spec = m.resolve_spec(catalog,image)
                if group != entry['group']:
                    raise ValueError('Apple catalog resolved a different hardware group')
                image['spec'] = spec
        for capture,native_folder,inputs in captures(entry, source):
            if capture['device'] != entry['device'] or capture['runtime'] != entry['runtime']:
                raise ValueError('Manifest device/runtime differs from capture evidence')
            if capture.get('workflow') == 'local-screenshot-only':
                renderer = source.get('renderer', 'scripts/render-app-store-screenshots.py')
                if source['renderer_sha256'] != digest(ROOT / renderer):
                    raise ValueError('Renderer changed after composition')
                if source.get('base_renderer_sha256', digest(ROOT / 'scripts/render-app-store-screenshots.py')) != digest(ROOT / 'scripts/render-app-store-screenshots.py'):
                    raise ValueError('Shared renderer changed after composition')
                for relative,sha in capture['capture_input_hashes'].items():
                    if digest(ROOT / relative) != sha:
                        raise ValueError('App/photo input changed after native capture')
                for locale,names in inputs.items():
                    for name,sha in names.items():
                        native = ROOT / 'marketing/app-store/native-captures' / native_folder / locale / f'{name}.png'
                        if digest(native) != sha:
                            raise ValueError('Retained native source does not match composition')
            else:
                sha = capture['head_sha']
                subprocess.run(['git','merge-base','--is-ancestor',sha,'HEAD'],cwd=ROOT,check=True,
                               stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                subprocess.run(['git','diff','--quiet',sha,'HEAD','--',*APP_INPUTS],cwd=ROOT,check=True)
                subprocess.run(['git','diff','--quiet','HEAD','--',*APP_INPUTS],cwd=ROOT,check=True)
        sets.append(entry | {'images':images})
    if len({s['group'] for s in sets}) != len(sets):
        raise ValueError('Duplicate target groups')
    if only_groups is None and 'IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE' not in {s['group'] for s in sets}:
        raise ValueError('Required DI medium must have its own explicit native set')
    return data,sets

def captures(entry, source):
    """The (capture record, native-capture folder, retained inputs) of each display a set was composed from."""
    if 'displays' not in source:
        return [(source['capture'], entry['slug'], source['inputs'])]
    return [(display['capture'], f"{entry['slug']}/{name}", display['inputs']) for name,display in source['displays'].items()]

def signature(placements):
    return {(p['id'],p['attributes']['placementGroup'],p['image']['id']) for p in placements}

def ensure_draft(api, manifest):
    version = api.resource(f"/v1/appStoreVersions/{manifest['version_id']}")
    if version['attributes']['versionString'] != manifest['version'] or version['attributes']['appStoreState'] != 'PREPARE_FOR_SUBMISSION':
        raise ValueError('Target version is no longer the editable reviewed draft')

def wait_active(api, loc_id, group, ordered, images, allow_extra=False):
    deadline = time.monotonic()+300
    while True:
        current = m.placements(api,loc_id,group)
        wanted = {p['id'] for p in ordered}
        selected = [p for p in current if p['id'] in wanted]
        if not allow_extra and len(current) != len(ordered):
            raise ValueError('Unexpected screenshot placements in targeted group')
        if m.verify_placements(selected,ordered,images,None):
            return current
        if time.monotonic() >= deadline:
            raise TimeoutError('Screenshot placement processing remains pending; inspect receipt before resuming')
        time.sleep(5)

def run(api, manifest_path, receipt, upload=False, only_groups=None):
    catalog = api.collection('/v1/appAssetLibraryRefData')[0]['attributes']
    manifest,sets = read_sets(manifest_path,catalog,only_groups)
    if only_groups is not None:
        if not only_groups or not set(only_groups) <= {s['group'] for s in sets}:
            raise ValueError('Selected upload groups are absent from the validated manifest')
        sets = [s for s in sets if s['group'] in only_groups]
    ensure_draft(api,manifest)
    locs = {loc['attributes']['locale']:loc['id'] for loc in api.collection(
        f"/v1/appStoreVersions/{manifest['version_id']}/appStoreVersionLocalizations")}
    if any(locale not in locs for locale in m.LOCALES):
        raise ValueError('Both reviewed localizations must already exist')
    library = api.resource(f"/v1/apps/{manifest['app_id']}/assetLibrary")
    before = {locale:m.placements(api,locs[locale]) for locale in m.LOCALES}
    target_groups = {s['group'] for s in sets}
    untouched = {locale:signature([p for p in ps if p['attributes']['placementGroup'] not in target_groups])
                 for locale,ps in before.items()}
    # Validate every group and replacement's temporary capacity before the first write.
    for s in sets:
        for locale in m.LOCALES:
            current = [p for p in before[locale] if p['attributes']['placementGroup']==s['group']]
            if any(not (p['image']['attributes'].get('referenceName') or '').startswith(m.MANAGED_PREFIX) for p in current):
                raise ValueError('Unmanaged screenshots in targeted group; refusing replacement')
            wanted = {i['reference'] for i in s['images'][locale]}
            missing = wanted - {p['image']['attributes'].get('referenceName') for p in current}
            if len(current)+len(missing)>10:
                raise ValueError('Not enough placement capacity to verify replacement before removing old images')
    receipt.update(version_id=manifest['version_id'],version=manifest['version'],groups=[],deleted_placements=[])
    if not upload:
        receipt['validated'] = [{'group':s['group'],'size':s['size'],'device':s['device']} for s in sets]
        return
    for s in sets:
        group=s['group']
        for locale in m.LOCALES:
            ensure_draft(api,manifest)
            print(f'{locale}: preparing {group}',flush=True)
            images=s['images'][locale]
            current=m.placements(api,locs[locale],group)
            if signature(current) != signature([p for p in before[locale] if p['attributes']['placementGroup']==group]):
                raise ValueError('Target group changed after preflight; inspect before resuming')
            assets=[m.prepare_image(api,library['id'],i,i['spec']) for i in images]
            ordered=[]
            for asset in assets:
                matches=[p for p in current if p['image']['id']==asset['id']]
                if len(matches)>1:raise ValueError('Duplicate screenshot placement')
                p=matches[0] if matches else api.create('appAssetLibraryPlacements',{
                    'placementType':'APP_SCREENSHOT','placementGroup':group},{
                    'image':m.relationship('appAssetLibraryImages',asset['id']),
                    'appStoreVersionLocalization':m.relationship('appStoreVersionLocalizations',locs[locale])})
                ordered.append({'type':'appAssetLibraryPlacements','id':p['id']})
            old=[{'type':'appAssetLibraryPlacements','id':p['id']} for p in current if p['id'] not in {p['id'] for p in ordered}]
            def order(items):
                api.create('appAssetLibraryPlacementOrderingRequests',{'placementGroup':group},{
                    'orderedPlacements':{'data':items},
                    'appStoreVersionLocalization':m.relationship('appStoreVersionLocalizations',locs[locale])})
            if [p['id'] for p in current] != [p['id'] for p in ordered]:order(ordered+old)
            wait_active(api,locs[locale],group,ordered,images,allow_extra=bool(old))
            # The reviewed replacements are now ACTIVE; remove only obsolete targeted placements.
            ensure_draft(api,manifest)
            for p in old:
                api.request('DELETE',f"/v1/appAssetLibraryPlacements/{p['id']}")
                receipt['deleted_placements'].append(p['id'])
            if old:order(ordered)
            wait_active(api,locs[locale],group,ordered,images)
            receipt['groups'].append({'locale':locale,'group':group,'size':s['size'],'device':s['device'],
                 'screenshots':[{'file':i['path'].name,'sha256':i['sha256'],'placement_id':p['id'],'state':'ACTIVE'} for i,p in zip(images,ordered)]})
            print(f'{locale}: {group}: {len(ordered)} own placements ACTIVE',flush=True)
    for locale in m.LOCALES:
        after=m.placements(api,locs[locale])
        if signature([p for p in after if p['attributes']['placementGroup'] not in target_groups]) != untouched[locale]:
            raise ValueError('A non-target screenshot group changed concurrently')
    ensure_draft(api,manifest)
    receipt['verified_state']='PREPARE_FOR_SUBMISSION'
    receipt['other_groups_preserved']=True

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path)
    parser.add_argument('--upload',action='store_true')
    parser.add_argument('--group',action='append',help='Upload only this validated manifest group; preserve all others')
    parser.add_argument('--receipt',required=True,type=Path)
    args=parser.parse_args()
    receipt={'success':False,'upload':args.upload}
    try:
        run(m.Apple(),args.manifest.resolve(),receipt,args.upload,only_groups=args.group)
        receipt['success']=True
    except Exception as error:
        receipt['error']=str(error) if isinstance(error,(ValueError,RuntimeError,TimeoutError)) else type(error).__name__
        print(receipt['error'],file=sys.stderr)
    finally:args.receipt.write_text(json.dumps(receipt,indent=2)+'\n')
    return 0 if receipt['success'] else 1

if __name__=='__main__':sys.exit(main())
