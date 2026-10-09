#!/usr/bin/env python3
"""Prepare App Store screenshot placements, without uploading or submitting a build.

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
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_URL = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "pro.ziganshin.GrowingUp"
FILES = ("01-mia.png", "02-leo-celebration.png", "03-mango-teddy.png", "04-widgets.png")
LOCALES = ("en-US", "ru")
LIVE_STATES = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}
READY_ASSETS = {"PREPARE_FOR_SUBMISSION", "APPROVED"}
MANAGED_PREFIX = "GrowingUp-store:"
CAPTURE_INPUTS = ("GrowingUp", "Core", "Widget", "GrowingUpUITests", "GrowingUp.xcodeproj",
                  "scripts/run-app-store-screenshots.sh", "scripts/render-app-store-screenshots.py",
                  "docs/app-store-demo-photos", "marketing/app-store/fonts")


def version_tuple(value):
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", value):
        raise ValueError("Expected a numeric App Store version")
    return tuple(int(part) for part in value.split(".")) + ((0,) if value.count(".") == 1 else ())


def select_version(versions, requested):
    live = [v for v in versions if v["attributes"]["appStoreState"] in LIVE_STATES]
    if not live:
        raise ValueError("No live iOS App Store version; inspect inventory before creating a version")
    latest = max(live, key=lambda v: version_tuple(v["attributes"]["versionString"]))
    major, minor, _ = version_tuple(latest["attributes"]["versionString"])
    target = f"{major}.{minor + 1}.0"
    if requested != "next" and version_tuple(requested) != version_tuple(target):
        raise ValueError(f"Requested version is not the next minor of live App Store version; expected {target}")
    existing = None
    for version in versions:
        attrs = version["attributes"]
        if version_tuple(attrs["versionString"]) == version_tuple(target):
            if attrs["appStoreState"] != "PREPARE_FOR_SUBMISSION":
                raise ValueError(f"Target {target} is not an editable PREPARE_FOR_SUBMISSION version")
            existing = version
        elif version_tuple(attrs["versionString"]) > version_tuple(latest["attributes"]["versionString"]):
            raise ValueError(f"Another App Store version already exists: {attrs['versionString']}; refusing to downgrade or change it")
    return latest, target, existing


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
        if query:
            path += "?" + urllib.parse.urlencode(query)
        result = []
        while path:
            page = self.request("GET", path)
            result.extend(page["data"])
            path = page.get("links", {}).get("next")
        return result

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
        if profile.get("platform") != "IPHONE_APP_STORE":
            continue
        matching = set(mapping["specs"]) & set(specs)
        for policy in features[0]["placementPolicies"]:
            if policy["placementType"] == "APP_SCREENSHOT":
                for limit in policy["groupLimits"]:
                    if group in limit["groupIds"] and limit["maxCount"] >= len(FILES) and len(matching) == 1:
                        groups.append((group, next(iter(matching))))
    if len(groups) != 1:
        raise ValueError(f"Expected one iPhone screenshot placement group for {image['width']}x{image['height']}; found {len(groups)}")
    return groups[0]


def validate_provenance(folder, source_sha, images):
    provenance = json.loads((folder / "source.json").read_text())
    capture_sha = provenance["capture"]["head_sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", capture_sha):
        raise ValueError("Screenshot capture provenance must contain a full source SHA")
    root = folder.resolve().parents[2]
    base_command = ["git", "-C", str(root)]
    if subprocess.run(base_command + ["merge-base", "--is-ancestor", capture_sha, source_sha],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        raise ValueError("Screenshot capture source is not an ancestor of the reviewed master source")
    if subprocess.run(base_command + ["diff", "--quiet", capture_sha, source_sha, "--", *CAPTURE_INPUTS],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        raise ValueError("App or screenshot capture inputs changed after capture; regenerate screenshots")
    expected = {f"{locale}/{image['path'].name}": image["sha256"] for locale, files in images.items() for image in files}
    if provenance["outputs"] != expected:
        raise ValueError("Committed screenshots do not match their capture/render provenance digests")
    dimensions = {(image["width"], image["height"]) for files in images.values() for image in files}
    if dimensions != {tuple(provenance["size"])}:
        raise ValueError("Screenshot dimensions do not match the capture/render provenance")
    return {"head_sha": capture_sha, "run_id": provenance["capture"]["run_id"],
            "run_attempt": provenance["capture"]["run_attempt"], "outputs": expected}


def placements(api, localization_id, group=None):
    query = {"filter[placementType]": "APP_SCREENSHOT", "sort": "placementGroupPosition", "include": "image"}
    if group:
        query["filter[placementGroup]"] = group
    # Fetch images explicitly: collection pagination does not retain included resources.
    result = api.collection(f"/v1/appStoreVersionLocalizations/{localization_id}/placements", **query)
    for placement in result:
        image_id = placement["relationships"]["image"]["data"]["id"]
        placement["image"] = api.resource(f"/v1/appAssetLibraryImages/{image_id}")
    return result


def check_replaceable(current, live):
    inherited_ids = {p["image"]["id"] for p in live}
    for placement in current:
        image = placement["image"]
        if image["id"] not in inherited_ids and not image["attributes"].get("referenceName", "").startswith(MANAGED_PREFIX):
            raise ValueError("Draft contains unrelated screenshots; refusing to replace them")


def verify_image(asset, image, spec_id):
    attrs = asset["attributes"]
    if (attrs["state"] not in READY_ASSETS or attrs["fileSize"] != len(image["content"])
            or attrs["referenceName"] != image["reference"] or attrs["specId"] != spec_id
            or attrs["imageAsset"]["width"] != image["width"] or attrs["imageAsset"]["height"] != image["height"]):
        raise ValueError("Apple processed asset does not match the reviewed screenshot")


def verify_placements(verified, ordered, images, spec_id):
    if [p["id"] for p in verified] != [p["id"] for p in ordered]:
        raise ValueError("Apple screenshot order does not match Mia, Leo, Mango/Teddy, widgets")
    for placement, image in zip(verified, images):
        verify_image(placement["image"], image, spec_id)
        if placement["attributes"]["state"] != "PARENT_PREPARE_FOR_SUBMISSION":
            raise ValueError("Screenshot placement is not in the editable draft state")


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
    deadline = time.monotonic() + 300
    while True:
        asset = api.resource(f"/v1/appAssetLibraryImages/{asset_id}")
        if asset["attributes"]["state"] in READY_ASSETS:
            verify_image(asset, image, spec_id)
            return asset
        if asset["attributes"]["state"] != "UPLOAD_COMPLETE":
            raise ValueError(f"Screenshot processing state is {asset['attributes']['state']}; inspect this asset before retrying")
        if time.monotonic() >= deadline:
            raise TimeoutError("Apple screenshot processing pending; rerun the same source to resume")
        time.sleep(5)


def run(api, args, receipt):
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
    if args.operation == "inventory":
        receipt["localizations"] = {}
        for version in versions:
            localizations = api.collection(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
            receipt["localizations"][version["id"]] = [{
                "id": loc["id"], "locale": loc["attributes"]["locale"], "screenshots": [{
                    "placement_id": p["id"], "group": p["attributes"]["placementGroup"], "image_id": p["image"]["id"],
                    "reference": p["image"]["attributes"].get("referenceName"), "state": p["image"]["attributes"]["state"],
                } for p in placements(api, loc["id"])],
            } for loc in localizations]
        return
    images = {locale: [screenshot(args.screenshots / locale / name, locale) for name in FILES] for locale in LOCALES}
    receipt["capture"] = validate_provenance(args.screenshots, args.source_sha, images)
    specifications = {locale: [resolve_spec(reference[0]["attributes"], image) for image in files] for locale, files in images.items()}
    if len({value for values in specifications.values() for value in values}) != 1:
        raise ValueError("The eight screenshots must target the same iPhone group and dimensions")
    group, spec_id = specifications[LOCALES[0]][0]
    live, target, draft = select_version(versions, args.version)
    receipt.update(target_version=target, live_version=live["attributes"]["versionString"], placement_group=group, spec_id=spec_id)
    live_localizations = {loc["attributes"]["locale"]: loc for loc in api.collection(f"/v1/appStoreVersions/{live['id']}/appStoreVersionLocalizations")}
    for locale in LOCALES:
        if locale not in live_localizations:
            raise ValueError(f"Live metadata for {locale} is missing; metadata authoring needs a separate instruction")
    draft_localizations = {} if draft is None else {loc["attributes"]["locale"]: loc for loc in api.collection(f"/v1/appStoreVersions/{draft['id']}/appStoreVersionLocalizations")}
    live_placements = {locale: placements(api, live_localizations[locale]["id"], group) for locale in LOCALES}
    # Check all existing target locales before the first write.
    for locale, localization in draft_localizations.items():
        if locale in LOCALES:
            check_replaceable(placements(api, localization["id"], group), live_placements[locale])
    if draft is None:
        draft = api.create("appStoreVersions", {"platform": "IOS", "versionString": target, "releaseType": "MANUAL"}, {"app": relationship("apps", app_id)})
        draft_localizations = {loc["attributes"]["locale"]: loc for loc in api.collection(f"/v1/appStoreVersions/{draft['id']}/appStoreVersionLocalizations")}
    receipt["version_id"] = draft["id"]
    receipt["screenshots"] = []
    for locale in LOCALES:
        localization = draft_localizations.get(locale)
        if localization is None:
            attrs = {key: value for key, value in live_localizations[locale]["attributes"].items()
                     if key in {"description", "keywords", "marketingUrl", "supportUrl", "promotionalText"} and value is not None}
            attrs["locale"] = locale
            localization = api.create("appStoreVersionLocalizations", attrs, {"appStoreVersion": relationship("appStoreVersions", draft["id"])})
        localization_id = localization["id"]
        current = placements(api, localization_id, group)
        check_replaceable(current, live_placements[locale])
        assets = [prepare_image(api, library["id"], image, spec_id) for image in images[locale]]
        wanted_ids = {asset["id"] for asset in assets}
        # Only remove the explicitly targeted group's inherited or managed screenshots.
        for placement in current:
            if placement["image"]["id"] not in wanted_ids:
                api.request("DELETE", f"/v1/appAssetLibraryPlacements/{placement['id']}")
        ordered = []
        for asset, image in zip(assets, images[locale]):
            matching = [p for p in current if p["image"]["id"] == asset["id"]]
            if len(matching) > 1:
                raise ValueError("Duplicate screenshot placements; inspect inventory")
            placement = matching[0] if matching else api.create("appAssetLibraryPlacements", {
                "placementType": "APP_SCREENSHOT", "placementGroup": group,
            }, {"image": relationship("appAssetLibraryImages", asset["id"]),
                "appStoreVersionLocalization": relationship("appStoreVersionLocalizations", localization_id)})
            ordered.append({"type": "appAssetLibraryPlacements", "id": placement["id"]})
            receipt["screenshots"].append({"locale": locale, "file": image["path"].name, "sha256": image["sha256"],
                                           "asset_id": asset["id"], "placement_id": placement["id"], "state": asset["attributes"]["state"]})
        api.create("appAssetLibraryPlacementOrderingRequests", {"placementGroup": group}, {
            "orderedPlacements": {"data": ordered}, "appStoreVersionLocalization": relationship("appStoreVersionLocalizations", localization_id),
        })
        verified = placements(api, localization_id, group)
        verify_placements(verified, ordered, images[locale], spec_id)
    final = api.resource(f"/v1/appStoreVersions/{draft['id']}")
    if final["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION" or final["attributes"]["versionString"] != target:
        raise ValueError("App Store version changed state during screenshot preparation")
    receipt["verified_state"] = "PREPARE_FOR_SUBMISSION"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("inventory", "upload"))
    parser.add_argument("--version", default="next")
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--screenshots", type=Path, default=Path("marketing/app-store/screenshots"))
    parser.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        parser.error("--source-sha must be a full commit SHA")
    receipt = {"operation": args.operation, "source_sha": args.source_sha, "success": False}
    try:
        run(Apple(), args, receipt)
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
