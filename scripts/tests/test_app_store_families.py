import importlib.util
from pathlib import Path
import unittest
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
            verification=api.events.index(('read',f'draft-{locale}',GROUP,5))
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

if __name__=='__main__':unittest.main()
