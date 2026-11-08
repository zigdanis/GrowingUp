#!/usr/bin/env python3
"""Read-only App Store screenshot inventory, plus the App Asset Library helpers the uploader shares.

Screenshots are captured on MacPro and uploaded by scripts/app-store-families.py from the sets listed in
marketing/app-store/screenshots/families.json; nothing here writes to App Store Connect.
Uses Apple's App Asset Library reserve/upload/commit/placement API (4.5+).
https://developer.apple.com/documentation/appstoreconnectapi/app-asset-library
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_URL = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "pro.ziganshin.GrowingUp"
FILES = ("01-mosaic.png", "02-mia.png", "03-leo-birthday.png", "04-editor.png", "05-pets.png", "06-widgets.png")
LOCALES = ("en-US", "ru")
READY_ASSETS = {"PREPARE_FOR_SUBMISSION", "APPROVED"}
MANAGED_PREFIX = "GrowingUp-store:"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Apple:
    def __init__(self):
        import jwt

        key = Path(os.environ["ASC_KEY_PATH"]).read_text()
        self.jwt = jwt
        self.key = key
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, path, data=None):
        url = urllib.parse.urljoin(API_URL, path)
        if urllib.parse.urlsplit(url).netloc != "api.appstoreconnect.apple.com" or not url.startswith("https://"):
            raise ValueError("Refusing to send Apple credentials outside the API host")
        now = int(time.time())
        token = self.jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
            self.key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
        )
        body = json.dumps(data).encode() if data is not None else None
        request = urllib.request.Request(url, body, method=method, headers={
            "Authorization": "Bearer " + token, "Content-Type": "application/json",
        })
        try:
            with self.opener.open(request, timeout=60) as response:
                content = response.read()
                return json.loads(content) if content else {}
        except urllib.error.HTTPError as error:
            # Do not print response details, JWTs, upload URLs or signed request headers.
            try:
                codes = [e.get("code", "UNKNOWN") for e in json.loads(error.read()).get("errors", [])]
            except (ValueError, TypeError):
                codes = []
            endpoint = urllib.parse.urlsplit(url).path
            raise RuntimeError(f"Apple {method} {endpoint}: HTTP {error.code}, codes {codes}") from None
        except urllib.error.URLError:
            raise RuntimeError("Apple API network request failed; inspect inventory before retrying a mutation") from None

    def collection(self, path, **query):
        return self.collection_with_included(path, **query)[0]

    def collection_with_included(self, path, **query):
        if query:
            path += "?" + urllib.parse.urlencode(query)
        result, included = [], []
        while path:
            page = self.request("GET", path)
            result.extend(page["data"])
            included.extend(page.get("included", []))
            path = page.get("links", {}).get("next")
        return result, included

    def resource(self, path):
        return self.request("GET", path)["data"]

    def create(self, resource_type, attributes, relationships):
        return self.request("POST", f"/v1/{resource_type}", {"data": {
            "type": resource_type, "attributes": attributes, "relationships": relationships,
        }})["data"]

    def upload(self, operations, content):
        validate_operations(operations, len(content))
        for operation in operations:
            request = urllib.request.Request(
                operation["url"], content[operation["offset"]:operation["offset"] + operation["length"]],
                method=operation["method"], headers={h["name"]: h["value"] for h in operation["requestHeaders"]},
            )
            try:
                with self.opener.open(request, timeout=90) as response:
                    response.read()
            except (urllib.error.HTTPError, urllib.error.URLError):
                raise RuntimeError("Apple binary upload failed; signed URL and headers withheld") from None


def relationship(resource_type, identifier):
    return {"data": {"type": resource_type, "id": identifier}}


def validate_operations(operations, size):
    cursor = 0
    for operation in sorted(operations, key=lambda op: op["offset"]):
        if (operation["offset"] != cursor or operation["length"] <= 0
                or operation["method"] != "PUT" or not operation["url"].startswith("https://")):
            raise ValueError("Invalid or incomplete Apple upload operations")
        if any(header["name"].lower() == "authorization" for header in operation["requestHeaders"]):
            raise ValueError("Apple upload operations must not contain authorization headers")
        cursor += operation["length"]
    if cursor != size:
        raise ValueError("Apple upload operations do not cover the declared file size")


def screenshot(path, locale):
    content = path.read_bytes()
    if content[:8] != b"\x89PNG\r\n\x1a\n" or content[12:16] != b"IHDR" or len(content) < 33:
        raise ValueError(f"Not a PNG screenshot: {path.name}")
    width, height, _, color_type = struct.unpack(">IIBB", content[16:26])
    # Apple screenshot specifications disallow alpha. RGB and grayscale are unambiguous.
    cursor = 8
    transparent = False
    while cursor + 12 <= len(content):
        length = struct.unpack(">I", content[cursor:cursor + 4])[0]
        transparent |= content[cursor + 4:cursor + 8] == b"tRNS"
        cursor += length + 12
    if color_type not in (0, 2) or transparent:
        raise ValueError(f"Screenshot must be an opaque RGB/grayscale PNG: {path.name}")
    digest = hashlib.sha256(content).hexdigest()
    return {"path": path, "content": content, "width": width, "height": height, "sha256": digest,
            "reference": f"{MANAGED_PREFIX}{locale}:{path.name}:{digest}"}


def resolve_spec(catalog, image):
    features = [f for f in catalog["features"] if f["featureId"] == "APP_STORE_VERSIONS"]
    types = [t for t in catalog["placementTypes"] if t["placementTypeId"] == "APP_SCREENSHOT"]
    if len(features) != 1 or len(types) != 1:
        raise ValueError("App Asset Library screenshot feature is unavailable")
    placement_type = types[0]
    if "APP_SCREENSHOTS_AND_PREVIEWS" not in placement_type["acceptsAssetCategories"]:
        raise ValueError("Apple catalog does not accept screenshot images")
    specs = []
    for spec in catalog["imageSpecs"]:
        dimensions = spec["dimensions"]
        if (dimensions["minWidth"] == dimensions["maxWidth"] == image["width"]
                and dimensions["minHeight"] == dimensions["maxHeight"] == image["height"]
                and ".png" in spec["fileExtensions"] and len(image["content"]) <= spec["maxFileSize"]):
            specs.append(spec["specId"])
    groups = []
    for mapping in placement_type["specMappings"]:
        group = mapping["placementGroupId"]
        profile = next((p for p in catalog["placementProfileGroups"] if p["placementProfileGroupId"] == group), {})
        # iPhone and iPad screenshot groups; their native sizes never overlap.
        if profile.get("platform") not in ("IPHONE_APP_STORE", "IPAD_APP_STORE"):
            continue
        matching = set(mapping["specs"]) & set(specs)
        for policy in features[0]["placementPolicies"]:
            if policy["placementType"] == "APP_SCREENSHOT":
                for limit in policy["groupLimits"]:
                    if group in limit["groupIds"] and limit["maxCount"] >= len(FILES) and len(matching) == 1:
                        groups.append((group, next(iter(matching))))
    if len(groups) != 1:
        raise ValueError(f"Expected one iPhone or iPad screenshot placement group for {image['width']}x{image['height']}; found {len(groups)}")
    return groups[0]


def placements(api, localization_id, group=None):
    query = {"filter[placementType]": "APP_SCREENSHOT", "sort": "placementGroupPosition", "include": "image"}
    if group:
        query["filter[placementGroup]"] = group
    path = f"/v1/appStoreVersionLocalizations/{localization_id}/placements"
    if hasattr(api, "collection_with_included"):
        result, included = api.collection_with_included(path, **query)
    else:
        result, included = api.collection(path, **query), []
    images = {item["id"]: item for item in included if item.get("type") == "appAssetLibraryImages"}
    for placement in result:
        image_id = placement["relationships"]["image"]["data"]["id"]
        # Use fresh included resources from this response, never a persistent cache.
        placement["image"] = images[image_id] if image_id in images else api.resource(f"/v1/appAssetLibraryImages/{image_id}")
    return result


def verify_image(asset, image, spec_id):
    attrs = asset["attributes"]
    if (attrs["state"] not in READY_ASSETS or attrs["fileSize"] != len(image["content"])
            or attrs["referenceName"] != image["reference"] or attrs["specId"] != spec_id
            or attrs["imageAsset"]["width"] != image["width"] or attrs["imageAsset"]["height"] != image["height"]):
        raise ValueError("Apple processed asset does not match the reviewed screenshot")


def verify_placements(verified, ordered, images, spec_id):
    """Validate every asset and order; return False while placement processing is pending."""
    if [p["id"] for p in verified] != [p["id"] for p in ordered]:
        raise ValueError("Apple screenshot order does not match the reviewed screenshot order")
    ready = True
    for placement, image in zip(verified, images):
        verify_image(placement["image"], image, spec_id)
        state = placement["attributes"]["state"]
        if state == "ASSET_PROCESSING":
            ready = False
        elif state != "ACTIVE":
            raise ValueError(f"Screenshot placement {placement['id']} state is {state}; expected ACTIVE")
    return ready


def prepare_image(api, library_id, image, spec_id):
    assets = api.collection(f"/v1/appAssetLibraries/{library_id}/images", **{"filter[referenceName]": image["reference"]})
    if len(assets) > 1:
        raise ValueError("Duplicate managed screenshot reservations; inspect inventory before retrying")
    if assets:
        asset = assets[0]
    else:
        asset = api.create("appAssetLibraryImages", {
            "fileName": image["path"].name, "fileSize": len(image["content"]),
            "category": "APP_SCREENSHOTS_AND_PREVIEWS", "referenceName": image["reference"],
        }, {"assetLibrary": relationship("appAssetLibraries", library_id)})
    asset_id = asset["id"]
    if asset["attributes"]["state"] == "AWAITING_UPLOAD":
        api.upload(asset["attributes"]["uploadOperations"], image["content"])
        api.request("PATCH", f"/v1/appAssetLibraryImages/{asset_id}", {"data": {
            "type": "appAssetLibraryImages", "id": asset_id, "attributes": {"uploaded": True},
        }})
    # A newly uploaded PNG can take slightly over five minutes in Apple's processing queue.
    deadline = time.monotonic() + 600
    while True:
        asset = api.resource(f"/v1/appAssetLibraryImages/{asset_id}")
        if asset["attributes"]["state"] in READY_ASSETS:
            verify_image(asset, image, spec_id)
            return asset
        if asset["attributes"]["state"] not in {"UPLOAD_COMPLETE", "COMPLETE"}:
            raise ValueError(f"Screenshot processing state is {asset['attributes']['state']}; inspect this asset before retrying")
        if time.monotonic() >= deadline:
            raise TimeoutError("Apple screenshot processing pending; rerun the same source to resume")
        time.sleep(5)


def inventory(api, receipt):
    apps = api.collection("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})
    if len(apps) != 1:
        raise ValueError("Expected exactly one GrowingUp app for the configured Apple account")
    app_id = apps[0]["id"]
    versions = api.collection(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})
    receipt.update(app_id=app_id, versions=[{"id": v["id"], **{k: v["attributes"][k] for k in ("versionString", "appStoreState")}} for v in versions])
    library = api.resource(f"/v1/apps/{app_id}/assetLibrary")
    reference = api.collection("/v1/appAssetLibraryRefData")
    if len(reference) != 1:
        raise ValueError("Expected the Apple asset specification catalog")
    receipt["asset_library_id"] = library["id"]
    receipt["catalog_id"] = reference[0]["id"]
    receipt["localizations"] = {}
    for version in versions:
        localizations = api.collection(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
        receipt["localizations"][version["id"]] = [{
            "id": loc["id"], "locale": loc["attributes"]["locale"], "screenshots": [{
                "placement_id": p["id"], "group": p["attributes"]["placementGroup"], "image_id": p["image"]["id"],
                "placement_state": p["attributes"]["state"],
                "reference": p["image"]["attributes"].get("referenceName"), "state": p["image"]["attributes"]["state"],
            } for p in placements(api, loc["id"])],
        } for loc in localizations]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("inventory",),
                        help="Uploads go through scripts/app-store-families.py with families.json")
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        parser.error("--source-sha must be a full commit SHA")
    receipt = {"operation": args.operation, "source_sha": args.source_sha, "success": False}
    try:
        inventory(Apple(), receipt)
        receipt["success"] = True
    except Exception as error:
        # Unexpected library exceptions may embed secrets; keep only the explicit safe errors.
        receipt["error"] = str(error) if isinstance(error, (ValueError, RuntimeError, TimeoutError)) else type(error).__name__
        print(receipt["error"], file=sys.stderr)
    finally:
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n")
    return 0 if receipt["success"] else 1


if __name__ == "__main__":
    sys.exit(main())
