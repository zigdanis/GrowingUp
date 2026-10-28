import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch

from test_app_store_metadata import ScreenshotAPI, image_attributes

spec=importlib.util.spec_from_file_location('families',Path(__file__).parents[1]/'app-store-families.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
GROUP='IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE'

class FamilyReplacementTests(unittest.TestCase):
    def upload(self,api,receipt,only_groups=None,extra_group=False):
        manifest={'version':'2.1.0','version_id':'2.1.0','app_id':'app'}
        images={locale:[{'path':Path(name),'content':b'png','width':1206,'height':2622,
                        'sha256':locale+name,'reference':f.m.MANAGED_PREFIX+locale+name,'spec':'spec'}
                       for name in f.m.FILES] for locale in f.m.LOCALES}
        sets=[{'group':GROUP,'size':[1206,2622],'device':'iPhone-17-Pro','images':images}]
        if extra_group:
            sets.append(sets[0] | {'group':'small-phone'})
        def prepared(api,library,image,spec):
            asset={'id':image['reference'],'attributes':image_attributes(image)}
            api.assets[asset['id']]=asset
            return asset
        with patch.object(f,'read_sets',return_value=(manifest,sets)),patch.object(f.m,'prepare_image',side_effect=prepared):
            f.run(api,Path('manifest.json'),receipt,True,only_groups=only_groups)

    def test_selected_group_upload_preserves_other_manifest_groups(self):
        api=ScreenshotAPI()
        receipt={}
        self.upload(api,receipt,only_groups=[GROUP],extra_group=True)
        self.assertEqual({g['group'] for g in receipt['groups']},{GROUP})
        self.assertFalse(any(e[0]=='delete' for e in api.events))
        for locale in f.m.LOCALES:
            self.assertTrue(any(p['attributes']['placementGroup']=='small-phone'
                                for p in api.localizations[f'draft-{locale}']))

    def test_unknown_selected_group_stops_before_writes(self):
        api=ScreenshotAPI()
        with self.assertRaisesRegex(ValueError,'absent'):
            self.upload(api,{},only_groups=['not-in-manifest'])
        self.assertFalse(any(e[0] in ('create','delete') for e in api.events))

    def test_target_replacement_becomes_active_before_deletion_other_families_preserved(self):
        api=ScreenshotAPI(unrelated=True)
        for locale in f.m.LOCALES:
            api.add(f'draft-{locale}',GROUP,f'target-old-{locale}','APP_SCREENSHOT')
            api.assets[f'target-old-{locale}']['attributes']['referenceName']=f.m.MANAGED_PREFIX+'old'
        receipt={}
        self.upload(api,receipt)
        self.assertEqual(receipt['deleted_placements'],[f'draft-{locale}-target-old-{locale}' for locale in f.m.LOCALES])
        for locale in f.m.LOCALES:
            old_id=f'draft-{locale}-target-old-{locale}'
            deletion=api.events.index(('delete',old_id))
            verification=api.events.index(('read',f'draft-{locale}',GROUP,len(f.m.FILES)+1))
            self.assertLess(verification,deletion)
            kept={p['id'] for p in api.localizations[f'draft-{locale}']}
            for p in ('tablet','preview'):
                self.assertIn(f'draft-{locale}-{p}-{locale}',kept)
            self.assertTrue(any(p['attributes']['placementGroup']=='small-phone' for p in api.localizations[f'draft-{locale}']))
        self.assertTrue(receipt['other_groups_preserved'])

    def test_processing_failure_keeps_prior_placements(self):
        api=ScreenshotAPI()
        api.add('draft-en-US',GROUP,'target-old','APP_SCREENSHOT')
        api.assets['target-old']['attributes']['referenceName']=f.m.MANAGED_PREFIX+'old'
        with patch.object(f,'wait_active',side_effect=TimeoutError('pending')),self.assertRaises(TimeoutError):
            self.upload(api,{})
        self.assertFalse(any(e[0]=='delete' for e in api.events))
        self.assertTrue(any(p['id']=='draft-en-US-target-old' for p in api.localizations['draft-en-US']))

    def test_unknown_target_asset_refuses_all_writes(self):
        api=ScreenshotAPI()
        api.add('draft-ru',GROUP,'unmanaged-target','APP_SCREENSHOT')
        with self.assertRaisesRegex(ValueError,'Unmanaged'):
            self.upload(api,{})
        self.assertFalse(any(e[0] in ('create','delete') for e in api.events))

    def test_capacity_refuses_removing_old_assets_to_make_room(self):
        api=ScreenshotAPI()
        for i in range(7):
            api.add('draft-en-US',GROUP,f'old-{i}','APP_SCREENSHOT')
            api.assets[f'old-{i}']['attributes']['referenceName']=f.m.MANAGED_PREFIX+f'old-{i}'
        with self.assertRaisesRegex(ValueError,'capacity'):
            self.upload(api,{})
        self.assertFalse(any(e[0] in ('create','delete') for e in api.events))


def solid_png(width, height, shade):
    row = b'\x00' + bytes([shade, shade, shade]) * width
    def chunk(kind, data):
        body = kind + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(row * height)) + chunk(b'IEND', b''))

DUO = 'IPHONE_DUO_PROFILE'
OUTER = (1398, 2034)
CATALOG = {
    'features': [{'featureId': 'APP_STORE_VERSIONS', 'placementPolicies': [{
        'placementType': 'APP_SCREENSHOT', 'groupLimits': [{'groupIds': [DUO, 'OLD'], 'maxCount': 10}]}]}],
    'placementTypes': [{'placementTypeId': 'APP_SCREENSHOT', 'acceptsAssetCategories': ['APP_SCREENSHOTS_AND_PREVIEWS'],
                        'specMappings': [{'placementGroupId': DUO, 'specs': ['outer-spec']}]}],
    'imageSpecs': [{'specId': 'outer-spec', 'dimensions': {'minWidth': OUTER[0], 'maxWidth': OUTER[0],
                                                           'minHeight': OUTER[1], 'maxHeight': OUTER[1]},
                    'fileExtensions': ['.png'], 'maxFileSize': 10**9}],
    'placementProfileGroups': [{'placementProfileGroupId': DUO, 'platform': 'IPHONE_APP_STORE'}],
}


class DuoSetTests(unittest.TestCase):
    """A Duo set is one placement group of the outer display's cards; selecting it skips the older families."""

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        patcher = patch.object(f, 'ROOT', self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        scripts = self.root / 'scripts'
        scripts.mkdir()
        (scripts / 'render-app-store-screenshots.py').write_text('base')
        (scripts / 'render-duo-app-store-screenshots.py').write_text('duo')
        self.screenshots = self.root / 'marketing/app-store/screenshots'
        self.native = self.root / 'marketing/app-store/native-captures'
        self.write_duo()
        self.manifest = self.screenshots / 'families.json'
        self.write_manifest(old_set=False)

    def digest(self, content):
        return hashlib.sha256(content).hexdigest()

    def write_duo(self):
        folder = self.screenshots / 'families/iphone-duo'
        outputs, inputs = {}, {}
        for locale in f.m.LOCALES:
            native = self.native / 'iphone-duo' / locale
            native.mkdir(parents=True)
            (native / 'mia.png').write_bytes(f'native-{locale}'.encode())
            inputs[locale] = {'mia': self.digest(f'native-{locale}'.encode())}
            (folder / locale).mkdir(parents=True)
            for index, name in enumerate(f.m.FILES):
                content = solid_png(*OUTER, index)
                (folder / locale / name).write_bytes(content)
                outputs[f'{locale}/{name}'] = self.digest(content)
        source = {'renderer': 'scripts/render-duo-app-store-screenshots.py', 'renderer_sha256': self.digest(b'duo'),
                  'base_renderer_sha256': self.digest(b'base'), 'size': list(OUTER), 'outputs': outputs, 'inputs': inputs,
                  'capture': {'workflow': 'local-screenshot-only', 'device': 'iPhone-Duo', 'runtime': '27-1',
                              'capture_input_hashes': {}}}
        (folder / 'source.json').write_text(json.dumps(source))

    def write_manifest(self, old_set):
        sets = [{'slug': 'iphone-duo', 'path': 'families/iphone-duo', 'group': DUO, 'device': 'iPhone-Duo',
                 'runtime': '27-1', 'size': list(OUTER)}]
        if old_set:
            # An older family whose inputs changed since its capture: stale, but not part of this upload.
            old = self.screenshots / 'families/old'
            old.mkdir(parents=True)
            (old / 'source.json').write_text(json.dumps({'renderer_sha256': 'stale'}))
            sets.append({'slug': 'old', 'path': 'families/old', 'group': 'OLD', 'device': 'x', 'runtime': 'y', 'size': [1, 1]})
        self.manifest.write_text(json.dumps({'app_id': '1461697772', 'version': '2.3.0', 'version_id': 'v', 'sets': sets}))

    def test_duo_group_is_read_with_its_spec(self):
        _, sets = f.read_sets(self.manifest, CATALOG, [DUO])
        self.assertEqual([s['group'] for s in sets], [DUO])
        for locale in f.m.LOCALES:
            self.assertEqual([i['spec'] for i in sets[0]['images'][locale]], ['outer-spec'] * len(f.m.FILES))

    def test_selected_group_does_not_revalidate_stale_older_families(self):
        self.write_manifest(old_set=True)
        f.read_sets(self.manifest, CATALOG, [DUO])
        with self.assertRaises(OSError):
            f.read_sets(self.manifest, CATALOG)

    def test_changed_retained_native_input_is_refused(self):
        (self.native / 'iphone-duo/ru/mia.png').write_bytes(b'edited')
        with self.assertRaisesRegex(ValueError, 'Retained native source'):
            f.read_sets(self.manifest, CATALOG, [DUO])

    def test_changed_renderer_is_refused(self):
        (self.root / 'scripts/render-duo-app-store-screenshots.py').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'Renderer changed'):
            f.read_sets(self.manifest, CATALOG, [DUO])

    def test_changed_shared_renderer_is_refused(self):
        (self.root / 'scripts/render-app-store-screenshots.py').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'Shared renderer changed'):
            f.read_sets(self.manifest, CATALOG, [DUO])


if __name__=='__main__':unittest.main()
