#!/usr/bin/env python3
"""Check, plan or apply the App Store search fields in marketing/app-store/listing.json.

`check` validates the file offline. `plan` reads the editable version from App Store Connect and prints what
`apply` would change. `apply --confirm VERSION` creates missing localizations (en-GB), sets name, subtitle and
keywords, copies the texts of a `mirror` localization, and reads everything back. It never creates a version,
touches screenshots or submits anything. Scheme: docs/app-store-localization.md.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "marketing/app-store/listing.json"
APP_ID = "1461697772"
FLEET_CREDENTIALS = Path("~/.config/app-store-connect/fleet.json").expanduser()
# Name and subtitle live on the appInfo, keywords and texts on the version; both are editable only in these states.
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
INFO_FIELDS = ("name", "subtitle")
MIRRORED_VERSION_FIELDS = ("description", "promotionalText", "whatsNew", "supportUrl", "marketingUrl")
MIRRORED_INFO_FIELDS = ("privacyPolicyUrl", "privacyChoicesUrl")
# Kazakhstan, Belarus, Uzbekistan and the rest of the CIS index only English (U.K.), so this localization must
# carry the words of the Russian name; `ru` is indexed only in Russia, Ukraine and the United States.
CIS_INDEX, RUSSIAN = "en-GB", "ru"
BRAND = "growingup"


def words(text):
    """Lowercased words as App Store search sees them: ё is е, punctuation separates."""
    return [w for w in re.split(r"[^\w]+", text.lower().replace("ё", "е")) if w]


def validate(listing):
    """Return a list of problems with the listing; empty when Apple would accept it and the scheme holds."""
    problems = []
    locales = listing["localizations"]
    for locale, fields in locales.items():
        for field, limit in (("name", 30), ("subtitle", 30), ("keywords", 100)):
            value = fields.get(field, "")
            if not value.strip():
                problems.append(f"{locale}: {field} is empty")
            if len(value) > limit:
                problems.append(f"{locale}: {field} has {len(value)} characters, limit {limit}")
        terms = fields.get("keywords", "").split(",")
        if any(term != term.strip() or not term for term in terms):
            problems.append(f"{locale}: keywords need single commas without spaces around them")
        normalized = [" ".join(words(term)) for term in terms]
        if len(set(normalized)) != len(normalized):
            problems.append(f"{locale}: keywords repeat a term")
        shown = set(words(fields.get("name", "") + " " + fields.get("subtitle", "")))
        repeated = sorted({w for term in terms for w in words(term) if w in shown})
        if repeated:
            problems.append(f"{locale}: keywords repeat words of the name or subtitle: {', '.join(repeated)}")
        mirror = fields.get("mirror")
        if mirror is not None and (mirror not in locales or locales[mirror].get("mirror")):
            problems.append(f"{locale}: mirror must name a localization that is not itself a mirror")
    if CIS_INDEX in locales and RUSSIAN in locales:
        carried = {w for term in locales[CIS_INDEX]["keywords"].split(",") for w in words(term)}
        carried |= set(words(locales[CIS_INDEX]["name"] + " " + locales[CIS_INDEX]["subtitle"]))
        missing = [w for w in words(locales[RUSSIAN]["name"]) if w != BRAND and w not in carried]
        if missing:
            problems.append(f"{CIS_INDEX}: keywords must carry the Russian name for CIS search: {', '.join(missing)}")
    return problems


def load_listing(path=LISTING):
    listing = json.loads(Path(path).read_text())
    if listing.get("app_id") != APP_ID:
        raise ValueError("Expected the GrowingUp listing")
    return listing


def editable(items, kind):
    found = [item for item in items if item["attributes"].get("appStoreState", item["attributes"].get("state")) in EDITABLE]
    if len(found) != 1:
        raise ValueError(f"Expected exactly one editable {kind}, found {len(found)}; create the next version first")
    return found[0]


def read_state(api):
    versions = api.collection(f"/v1/apps/{APP_ID}/appStoreVersions", **{"filter[platform]": "IOS", "limit": "20"})
    version = editable(versions, "App Store version")
    info = editable(api.collection(f"/v1/apps/{APP_ID}/appInfos"), "app info")
    by_locale = lambda items: {item["attributes"]["locale"]: item for item in items}
    return {
        "version": version, "info": info,
        "version_locs": by_locale(api.collection(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")),
        "info_locs": by_locale(api.collection(f"/v1/appInfos/{info['id']}/appInfoLocalizations")),
    }


def plan(listing, state):
    """Changes as (action, resource type, id or None, locale, attributes), in the order apply sends them."""
    changes = []
    for locale, fields in listing["localizations"].items():
        mirror = fields.get("mirror")
        for kind, locs, wanted, mirrored in (
            ("appInfoLocalizations", state["info_locs"], {f: fields[f] for f in INFO_FIELDS}, MIRRORED_INFO_FIELDS),
            ("appStoreVersionLocalizations", state["version_locs"], {"keywords": fields["keywords"]}, MIRRORED_VERSION_FIELDS),
        ):
            if mirror is not None:
                if mirror not in locs:
                    raise ValueError(f"{mirror} is missing in App Store Connect; it is the source of {locale}")
                source = locs[mirror]["attributes"]
                # Keep cleared fields: a null clears the copy too, so a text removed in the source never lingers.
                wanted.update({f: source.get(f) for f in mirrored})
            current = locs.get(locale)
            if current is None:
                created = {f: v for f, v in wanted.items() if v is not None}
                changes.append(("create", kind, None, locale, {"locale": locale, **created}))
            else:
                diff = {f: v for f, v in wanted.items() if current["attributes"].get(f) != v}
                if diff:
                    changes.append(("update", kind, current["id"], locale, diff))
    return changes


def apply(api, listing, state, changes):
    owners = {"appInfoLocalizations": ("appInfo", "appInfos", state["info"]["id"]),
              "appStoreVersionLocalizations": ("appStoreVersion", "appStoreVersions", state["version"]["id"])}
    for action, kind, identifier, locale, attributes in changes:
        print(f"{locale}: {action} {kind} {sorted(attributes)}", flush=True)
        if action == "create":
            name, owner_type, owner_id = owners[kind]
            api.create(kind, attributes, {name: {"data": {"type": owner_type, "id": owner_id}}})
        else:
            api.request("PATCH", f"/v1/{kind}/{identifier}",
                        {"data": {"type": kind, "id": identifier, "attributes": attributes}})
    after = read_state(api)
    if after["version"]["id"] != state["version"]["id"] or plan(listing, after):
        raise ValueError("App Store Connect does not match the listing after apply; run plan and inspect")
    return after


def apple():
    """The repo's App Store Connect client, with the Fleet team key when ASC_* variables are not set."""
    spec = importlib.util.spec_from_file_location("store_metadata", ROOT / "scripts/app-store-metadata.py")
    metadata = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(metadata)
    if all(os.environ.get(name) for name in ("ASC_KEY_PATH", "ASC_KEY_ID", "ASC_ISSUER_ID")):
        return metadata.Apple()
    credentials = json.loads(FLEET_CREDENTIALS.read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".p8") as key:
        os.chmod(key.name, 0o600)
        key.write(credentials["key"])
        key.flush()
        os.environ.update(ASC_KEY_PATH=key.name, ASC_KEY_ID=credentials["key_id"], ASC_ISSUER_ID=credentials["issuer_id"])
        try:
            return metadata.Apple()
        finally:
            del os.environ["ASC_KEY_PATH"]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("operation", choices=("check", "plan", "apply"))
    parser.add_argument("--listing", type=Path, default=LISTING)
    parser.add_argument("--confirm", metavar="VERSION", help="apply only to this editable version string")
    args = parser.parse_args()
    listing = load_listing(args.listing)
    problems = validate(listing)
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems or args.operation == "check":
        return 1 if problems else 0
    api = apple()
    state = read_state(api)
    version = state["version"]["attributes"]["versionString"]
    changes = plan(listing, state)
    print(f"Editable version {version} ({state['version']['attributes']['appStoreState']}): {len(changes)} changes")
    for action, kind, _, locale, attributes in changes:
        print(f"  {locale} {action} {kind}: " + json.dumps(attributes, ensure_ascii=False)[:400])
    if args.operation == "plan" or not changes:
        return 0
    if args.confirm != version:
        parser.error(f"apply needs --confirm {version}")
    apply(api, listing, state, changes)
    print("Read back: App Store Connect matches the listing")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
