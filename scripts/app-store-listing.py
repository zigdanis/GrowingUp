#!/usr/bin/env python3
"""Check, plan or apply the App Store search fields in marketing/app-store/listing.json.

`check` validates the file offline. `plan` reads the editable version from App Store Connect and prints what
`apply` would change. `apply --confirm VERSION` sets name, subtitle and keywords of the existing localizations,
copies the en-US texts into en-GB, and reads them back. It never creates a version or a localization, edits the
en-US or ru texts, touches screenshots, or submits anything. Scheme: docs/app-store-localization.md.
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
# en-GB exists for its Russian keywords; English readers outside the US must see the same texts as en-US.
MIRRORED_TEXTS = ("description", "whatsNew", "promotionalText", "supportUrl", "marketingUrl")
# Kazakhstan, Belarus, Uzbekistan and the rest of the CIS index only English (U.K.), so en-GB keywords are Russian and
# must carry the words of the Russian name. `ru` is indexed only in Russia, Ukraine and the United States. en-US is
# searched only in the storefronts without English (U.K.), the United States, Canada and Japan, so it stays English.
PRIMARY, CIS_INDEX, RUSSIAN = "en-US", "en-GB", "ru"


def words(text):
    """Lowercased words as App Store search sees them: ё is е, punctuation separates."""
    return [w for w in re.split(r"[^\w]+", text.lower().replace("ё", "е")) if w]


def validate(listing):
    """Return a list of problems with the listing; empty when Apple would accept it and the scheme holds."""
    problems = []
    locales = listing["localizations"]
    for locale in (PRIMARY, CIS_INDEX, RUSSIAN):
        if locale not in locales:
            problems.append(f"{locale}: localization is missing")
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
    if CIS_INDEX in locales and RUSSIAN in locales:
        cis = locales[CIS_INDEX]
        carried = {w for term in cis.get("keywords", "").split(",") for w in words(term)}
        carried |= set(words(cis.get("name", "") + " " + cis.get("subtitle", "")))
        # One-letter words such as «и» are not worth keyword room.
        missing = [w for w in words(locales[RUSSIAN].get("name", "")) if len(w) > 1 and w not in carried]
        if missing:
            problems.append(f"{CIS_INDEX}: keywords must carry the Russian name for CIS search: {', '.join(missing)}")
    if PRIMARY in locales and CIS_INDEX in locales:
        # English readers in en-GB storefronts must see the same name and subtitle as in the US.
        for field in INFO_FIELDS:
            if locales[CIS_INDEX].get(field) != locales[PRIMARY].get(field):
                problems.append(f"{CIS_INDEX}: {field} must match {PRIMARY}")
    if PRIMARY in locales and not locales[PRIMARY].get("keywords", "").isascii():
        problems.append(f"{PRIMARY}: keywords must be English; Russian keywords belong in {CIS_INDEX}")
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
    """Updates as (resource type, id, locale, attributes), in the order apply sends them."""
    changes = []
    primary = state["version_locs"].get(PRIMARY)
    for locale, fields in listing["localizations"].items():
        version_fields = {"keywords": fields["keywords"]}
        if locale == CIS_INDEX and primary is not None:
            version_fields.update({f: primary["attributes"].get(f) for f in MIRRORED_TEXTS})
        for kind, locs, wanted in (
            ("appInfoLocalizations", state["info_locs"], {f: fields[f] for f in INFO_FIELDS}),
            ("appStoreVersionLocalizations", state["version_locs"], version_fields),
        ):
            current = locs.get(locale)
            if current is None:
                raise ValueError(f"{locale} is missing in {kind}; adding a localization needs a separate decision")
            diff = {f: v for f, v in wanted.items() if current["attributes"].get(f) != v}
            if diff:
                changes.append((kind, current["id"], locale, diff))
    return changes


def apply(api, listing, state, changes):
    for kind, identifier, locale, attributes in changes:
        print(f"{locale}: update {kind} {sorted(attributes)}", flush=True)
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
    for kind, _, locale, attributes in changes:
        print(f"  {locale} {kind}: " + json.dumps(attributes, ensure_ascii=False)[:400])
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
