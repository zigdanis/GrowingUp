import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("app_store_metadata", Path(__file__).parents[1] / "app-store-metadata.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


def version(value, state="PREPARE_FOR_SUBMISSION"):
    return {"id": value, "attributes": {"versionString": value, "appStoreState": state}}


def image_attributes(image, spec_id="spec"):
    return {"state": "PREPARE_FOR_SUBMISSION", "fileSize": len(image["content"]),
            "referenceName": image["reference"], "specId": spec_id,
            "imageAsset": {"width": image["width"], "height": image["height"]}}


class AppStoreMetadataTests(unittest.TestCase):
    def test_next_minor_comes_from_live_store_not_newer_beta_source(self):
        live = version("2.0.0", "READY_FOR_DISTRIBUTION")
        self.assertEqual(metadata.select_version([live], "next"), (live, "2.1.0", None))
        self.assertEqual(metadata.select_version([live, version("2.1.0")], "2.1.0")[1], "2.1.0")

    def test_version_selection_refuses_higher_draft_and_wrong_request(self):
        live = version("2.0.0", "READY_FOR_SALE")
        with self.assertRaisesRegex(ValueError, "Another App Store version"):
            metadata.select_version([live, version("2.1.9")], "2.1.0")
        with self.assertRaisesRegex(ValueError, "next minor"):
            metadata.select_version([live], "2.0.1")
        with self.assertRaisesRegex(ValueError, "not an editable"):
            metadata.select_version([live, version("2.1.0", "WAITING_FOR_REVIEW")], "next")

    def test_upload_operations_cover_bytes_exactly_without_credentials(self):
        operations = [{"method": "PUT", "url": "https://store.apple.com/part", "offset": offset,
                       "length": 5, "requestHeaders": []} for offset in (5, 0)]
        metadata.validate_operations(operations, 10)
        operations[0]["offset"] = 6
        with self.assertRaises(ValueError):
            metadata.validate_operations(operations, 10)
        operations[0]["offset"] = 5
        operations[0]["requestHeaders"] = [{"name": "Authorization", "value": "secret"}]
        with self.assertRaisesRegex(ValueError, "authorization"):
            metadata.validate_operations(operations, 10)

    def test_screenshot_digest_and_transparency(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "01-mia.png"
            header = struct.pack(">I", 13) + b"IHDR" + struct.pack(">IIBBBBB", 1320, 2868, 8, 2, 0, 0, 0) + b"\0" * 4
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + header)
            image = metadata.screenshot(path, "ru")
            self.assertEqual((image["width"], image["height"]), (1320, 2868))
            self.assertEqual(len(image["sha256"]), 64)
            self.assertTrue(image["reference"].endswith(image["sha256"]))
            path.write_bytes(path.read_bytes() + struct.pack(">I", 0) + b"tRNS" + b"\0" * 4)
            with self.assertRaisesRegex(ValueError, "opaque"):
                metadata.screenshot(path, "ru")

    def test_resolve_runtime_catalog_spec_and_limit(self):
        catalog = {"features": [{"featureId": "APP_STORE_VERSIONS", "placementPolicies": [{
            "placementType": "APP_SCREENSHOT", "groupLimits": [{"groupIds": ["new-phone-group"], "maxCount": 10}],
        }]}], "placementTypes": [{"placementTypeId": "APP_SCREENSHOT", "acceptsAssetCategories": ["APP_SCREENSHOTS_AND_PREVIEWS"],
                                  "specMappings": [{"placementGroupId": "new-phone-group", "specs": ["spec"]}]}],
                   "placementProfileGroups": [{"placementProfileGroupId": "new-phone-group", "platform": "IPHONE_APP_STORE"}],
                   "imageSpecs": [{"specId": "spec", "dimensions": {"minWidth": 1320, "maxWidth": 1320, "minHeight": 2868, "maxHeight": 2868},
                                   "fileExtensions": [".png"], "maxFileSize": 100}]}
        image = {"width": 1320, "height": 2868, "content": b"png"}
        self.assertEqual(metadata.resolve_spec(catalog, image), ("new-phone-group", "spec"))
        catalog["features"][0]["placementPolicies"][0]["groupLimits"][0]["maxCount"] = 3
        with self.assertRaisesRegex(ValueError, "found 0"):
            metadata.resolve_spec(catalog, image)

    def test_refuses_unrelated_draft_images_but_allows_inherited_live(self):
        old = {"image": {"id": "old", "attributes": {"referenceName": "old marketing"}}}
        managed = {"image": {"id": "ours", "attributes": {"referenceName": metadata.MANAGED_PREFIX + "ru:01-mia:hash"}}}
        metadata.check_replaceable([old, managed], [old])
        with self.assertRaisesRegex(ValueError, "unrelated"):
            metadata.check_replaceable([old], [])

    def test_processed_asset_verification_checks_dimensions_spec_reference_size(self):
        image = {"content": b"png", "width": 1320, "height": 2868, "reference": "managed:sha256"}
        asset = {"id": "asset", "attributes": image_attributes(image)}
        metadata.verify_image(asset, image, "spec")
        for field, value in [("fileSize", 4), ("referenceName", "other"), ("specId", "wrong"), ("state", "FAILED")]:
            bad = {"attributes": {**asset["attributes"], field: value}}
            with self.assertRaises(ValueError):
                metadata.verify_image(bad, image, "spec")

    def test_resume_ready_asset_never_reserves_or_transfers_again(self):
        image = {"content": b"png", "width": 1320, "height": 2868, "reference": "managed:sha256"}
        asset = {"id": "asset", "attributes": image_attributes(image)}

        class API:
            def collection(self, path, **query):
                return [asset]

            def resource(self, path):
                return asset

        self.assertEqual(metadata.prepare_image(API(), "library", image, "spec"), asset)

    def test_commit_uses_current_library_contract_and_verifies_after_processing(self):
        image = {"path": Path("01-mia.png"), "content": b"png", "width": 1320, "height": 2868, "reference": "managed:sha256"}
        committed = []

        class API:
            def collection(self, path, **query):
                return []

            def create(self, kind, attributes, relationships):
                self.asset = {"id": "asset", "attributes": {"state": "AWAITING_UPLOAD", "uploadOperations": []}}
                return self.asset

            def upload(self, operations, content):
                self.content = content

            def request(self, method, path, data):
                committed.append(data["data"]["attributes"])
                self.asset["attributes"] = image_attributes(image)

            def resource(self, path):
                return self.asset

        api = API()
        metadata.prepare_image(api, "library", image, "spec")
        self.assertEqual(api.content, b"png")
        self.assertEqual(committed, [{"uploaded": True}])

    def test_order_verification_rejects_reversed_apple_response(self):
        images = [{"content": b"png", "width": 1320, "height": 2868, "reference": name} for name in ("mia", "leo")]
        verified = [{"id": image["reference"], "image": {"attributes": image_attributes(image)},
                     "attributes": {"state": "PARENT_PREPARE_FOR_SUBMISSION"}} for image in images]
        ordered = [{"id": "mia"}, {"id": "leo"}]
        metadata.verify_placements(verified, ordered, images, "spec")
        with self.assertRaisesRegex(ValueError, "order"):
            metadata.verify_placements(verified[::-1], ordered, images, "spec")

    def test_provenance_accepts_asset_commit_but_rejects_changed_capture_inputs_or_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory) / "marketing/app-store/screenshots"
            folder.mkdir(parents=True)
            provenance = {"capture": {"head_sha": "a" * 40, "run_id": "12", "run_attempt": "1"},
                          "size": [1320, 2868], "outputs": {"ru/01-mia.png": "digest"}}
            (folder / "source.json").write_text(json.dumps(provenance))
            images = {"ru": [{"path": folder / "ru/01-mia.png", "sha256": "digest", "width": 1320, "height": 2868}]}
            with patch.object(metadata.subprocess, "run") as command:
                command.return_value.returncode = 0
                result = metadata.validate_provenance(folder, "b" * 40, images)
                self.assertEqual(result["head_sha"], "a" * 40)
                self.assertIn("marketing/fonts", command.call_args.args[0])
                command.return_value.returncode = 1
                with self.assertRaisesRegex(ValueError, "ancestor"):
                    metadata.validate_provenance(folder, "b" * 40, images)
                command.return_value.returncode = 0
                images["ru"][0]["sha256"] = "tampered"
                with self.assertRaisesRegex(ValueError, "digests"):
                    metadata.validate_provenance(folder, "b" * 40, images)
                command.side_effect = [type("Result", (), {"returncode": 0})(), type("Result", (), {"returncode": 1})()]
                with self.assertRaisesRegex(ValueError, "changed after capture"):
                    metadata.validate_provenance(folder, "b" * 40, images)


if __name__ == "__main__":
    unittest.main()
