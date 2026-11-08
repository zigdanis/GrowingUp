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


class ScreenshotAPI:
    """Stateful Apple responses for the placement replacement contract, shared with test_app_store_families."""

    def __init__(self, old_groups=True, unrelated=False, fail_second_locale=False,
                 placement_states=(), final_state="PREPARE_FOR_SUBMISSION"):
        self.events = []
        self.assets = {}
        self.localizations = {f"{state}-{locale}": [] for state in ("live", "draft") for locale in metadata.LOCALES}
        self.fail_second_locale = fail_second_locale
        self.placement_states = list(placement_states)
        self.final_state = final_state
        for locale in metadata.LOCALES:
            for state in ("live", "draft"):
                self.add(f"{state}-{locale}", "tablet", f"tablet-{locale}", "APP_SCREENSHOT")
                self.add(f"{state}-{locale}", "primary", f"preview-{locale}", "APP_PREVIEW")
                if old_groups:
                    image_id = f"old-{locale}" if not (unrelated and state == "draft" and locale == "ru") else "unrelated"
                    self.add(f"{state}-{locale}", "small-phone", image_id, "APP_SCREENSHOT")

    def add(self, localization, group, image_id, kind):
        self.assets[image_id] = {"id": image_id, "attributes": {"referenceName": None, "state": "APPROVED"}}
        placement = {"id": f"{localization}-{image_id}", "attributes": {
            "placementGroup": group, "placementType": kind, "state": "ACTIVE"},
                     "relationships": {"image": {"data": {"id": image_id}}}}
        self.localizations[localization].append(placement)

    def collection(self, path, **query):
        if path == "/v1/apps":
            return [{"id": "app"}]
        if path == "/v1/apps/app/appStoreVersions":
            return [version("2.0.0", "READY_FOR_DISTRIBUTION"), version("2.1.0")]
        if path == "/v1/appAssetLibraryRefData":
            return [{"id": "catalog", "attributes": {"placementProfileGroups": [
                {"placementProfileGroupId": group, "platform": platform} for group, platform in (
                    ("primary", "IPHONE_APP_STORE"), ("small-phone", "IPHONE_APP_STORE"), ("tablet", "IPAD_APP_STORE"))]}}]
        if path.endswith("/appStoreVersionLocalizations"):
            state = "live" if "/2.0.0/" in path else "draft"
            return [{"id": f"{state}-{locale}", "attributes": {"locale": locale}} for locale in metadata.LOCALES]
        if path.endswith("/placements"):
            localization = path.split("/")[-2]
            result = [placement for placement in self.localizations[localization]
                      if placement["attributes"]["placementType"] == query["filter[placementType]"]
                      and (not query.get("filter[placementGroup]") or placement["attributes"]["placementGroup"] == query["filter[placementGroup]"])]
            self.events.append(("read", localization, query.get("filter[placementGroup]"), len(result)))
            if localization == "draft-en-US" and len(result) == len(metadata.FILES) and self.placement_states:
                state = self.placement_states.pop(0) if len(self.placement_states) > 1 else self.placement_states[0]
                result = [{**p, "attributes": {**p["attributes"], "state": state}} for p in result]
            return result
        raise AssertionError(path)

    def resource(self, path):
        if path.endswith("/assetLibrary"):
            return {"id": "library"}
        if "/appAssetLibraryImages/" in path:
            return self.assets[path.split("/")[-1]]
        if path == "/v1/appStoreVersions/2.1.0":
            return version("2.1.0", self.final_state)
        raise AssertionError(path)

    def create(self, kind, attributes, relationships):
        localization = relationships["appStoreVersionLocalization"]["data"]["id"]
        self.events.append(("create", kind, localization))
        if kind == "appAssetLibraryPlacementOrderingRequests":
            if self.fail_second_locale and localization == "draft-ru":
                raise ValueError("Second locale ordering failed")
            wanted = [p["id"] for p in relationships["orderedPlacements"]["data"]]
            current = self.localizations[localization]
            self.localizations[localization] = ([p for p in current if p["id"] not in wanted]
                                               + [next(p for p in current if p["id"] == identifier) for identifier in wanted])
            return {"id": "ordering"}
        image_id = relationships["image"]["data"]["id"]
        placement = {"id": f"placement-{image_id}", "attributes": {**attributes, "state": "ACTIVE"},
                     "relationships": {"image": {"data": {"id": image_id}}}}
        self.localizations[localization].append(placement)
        return placement

    def request(self, method, path):
        if method != "DELETE" or not path.startswith("/v1/appAssetLibraryPlacements/"):
            raise AssertionError((method, path))
        identifier = path.split("/")[-1]
        self.events.append(("delete", identifier))
        for localization, values in self.localizations.items():
            self.localizations[localization] = [p for p in values if p["id"] != identifier]
        return {}


class PlacementReadTests(unittest.TestCase):
    def test_paginated_included_images_avoid_redundant_requests(self):
        def placement(identifier):
            return {"id": identifier, "relationships": {"image": {"data": {"id": identifier}}}}
        pages = [
            {"data": [placement("first")], "included": [{"type": "appAssetLibraryImages", "id": "first"}],
             "links": {"next": "/next"}},
            {"data": [placement("second")], "included": [{"type": "appAssetLibraryImages", "id": "second"}]},
        ]
        api = metadata.Apple.__new__(metadata.Apple)
        with patch.object(api, "request", side_effect=pages) as request, patch.object(api, "resource") as resource:
            result = metadata.placements(api, "locale")
        self.assertEqual([p["image"]["id"] for p in result], ["first", "second"])
        self.assertEqual(request.call_count, 2)
        resource.assert_not_called()

    def test_missing_included_image_is_fetched_explicitly(self):
        api = metadata.Apple.__new__(metadata.Apple)
        page = {"data": [{"id": "placement", "relationships": {"image": {"data": {"id": "missing"}}}}]}
        with patch.object(api, "request", return_value=page), \
                patch.object(api, "resource", return_value={"id": "missing"}) as resource:
            result = metadata.placements(api, "locale")
        resource.assert_called_once_with("/v1/appAssetLibraryImages/missing")
        self.assertEqual(result[0]["image"]["id"], "missing")


class AppStoreMetadataTests(unittest.TestCase):
    def test_inventory_reports_placement_and_asset_states_separately_without_writes(self):
        api = ScreenshotAPI()
        receipt = {}
        metadata.inventory(api, receipt)
        for localizations in receipt["localizations"].values():
            for localization in localizations:
                for image in localization["screenshots"]:
                    self.assertEqual(image["placement_state"], "ACTIVE")
                    self.assertEqual(image["state"], "APPROVED")
        self.assertFalse(any(event[0] in {"create", "delete"} for event in api.events))

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

    def test_resolve_an_ipad_group_but_not_an_imessage_one(self):
        catalog = {"features": [{"featureId": "APP_STORE_VERSIONS", "placementPolicies": [{
            "placementType": "APP_SCREENSHOT", "groupLimits": [{"groupIds": ["IPAD_13_PROFILE", "IMESSAGE_IPAD_13_PROFILE"], "maxCount": 10}],
        }]}], "placementTypes": [{"placementTypeId": "APP_SCREENSHOT", "acceptsAssetCategories": ["APP_SCREENSHOTS_AND_PREVIEWS"],
                                  "specMappings": [{"placementGroupId": "IPAD_13_PROFILE", "specs": ["ipad"]},
                                                   {"placementGroupId": "IMESSAGE_IPAD_13_PROFILE", "specs": ["ipad"]}]}],
                   "placementProfileGroups": [{"placementProfileGroupId": "IPAD_13_PROFILE", "platform": "IPAD_APP_STORE"},
                                              {"placementProfileGroupId": "IMESSAGE_IPAD_13_PROFILE"}],
                   "imageSpecs": [{"specId": "ipad", "dimensions": {"minWidth": 2064, "maxWidth": 2064, "minHeight": 2752, "maxHeight": 2752},
                                   "fileExtensions": [".png"], "maxFileSize": 100}]}
        image = {"width": 2064, "height": 2752, "content": b"png"}
        self.assertEqual(metadata.resolve_spec(catalog, image), ("IPAD_13_PROFILE", "ipad"))

    def test_processed_asset_verification_checks_dimensions_spec_reference_size(self):
        image = {"content": b"png", "width": 1320, "height": 2868, "reference": "managed:sha256"}
        asset = {"id": "asset", "attributes": image_attributes(image)}
        metadata.verify_image(asset, image, "spec")
        for field, value in [("fileSize", 4), ("referenceName", "other"), ("specId", "wrong"), ("state", "FAILED"),
                             ("imageAsset", {"width": 1321, "height": 2868}), ("imageAsset", {"width": 1320, "height": 2869})]:
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
                     "attributes": {"state": "ACTIVE"}} for image in images]
        ordered = [{"id": "mia"}, {"id": "leo"}]
        metadata.verify_placements(verified, ordered, images, "spec")
        with self.assertRaisesRegex(ValueError, "order"):
            metadata.verify_placements(verified[::-1], ordered, images, "spec")

    def test_complete_is_transient_and_is_polled_without_reuploading_reserved_image(self):
        image = {"content": b"png", "width": 1206, "height": 2622, "reference": "managed:sha256"}
        states = iter(("COMPLETE", "PREPARE_FOR_SUBMISSION"))

        class API:
            def collection(self, path, **query):
                return [{"id": "asset", "attributes": {"state": "COMPLETE"}}]

            def resource(self, path):
                return {"id": "asset", "attributes": {**image_attributes(image), "state": next(states)}}

            def upload(self, operations, content):
                raise AssertionError("Processed upload must not be sent again")

        with patch.object(metadata.time, "sleep") as sleep:
            asset = metadata.prepare_image(API(), "library", image, "spec")
        self.assertEqual(asset["attributes"]["state"], "PREPARE_FOR_SUBMISSION")
        sleep.assert_called_once_with(5)



if __name__ == "__main__":
    unittest.main()
