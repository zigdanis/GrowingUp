import copy
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("app_store_listing", Path(__file__).parents[1] / "app-store-listing.py")
listing_tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(listing_tool)


def resource(identifier, **attributes):
    return {"id": identifier, "attributes": attributes}


class FakeAPI:
    """App Store Connect with an editable 3.1 that has en-US and ru but no en-GB yet."""

    def __init__(self):
        self.calls = []
        self.versions = [resource("v30", versionString="3.0.0", appStoreState="READY_FOR_SALE"),
                         resource("v31", versionString="3.1", appStoreState="PREPARE_FOR_SUBMISSION")]
        self.infos = [resource("live", appStoreState="READY_FOR_SALE", state="READY_FOR_DISTRIBUTION"),
                      resource("draft", appStoreState="PREPARE_FOR_SUBMISSION", state="PREPARE_FOR_SUBMISSION")]
        self.locs = {
            "appStoreVersionLocalizations": [
                resource("vl-us", locale="en-US", keywords="old", description="Kids grow up fast.",
                         promotionalText="Promo", whatsNew="iPad", supportUrl="https://ziganshin.pro", marketingUrl=None),
                resource("vl-ru", locale="ru", keywords="старые", description="Дети растут быстро.",
                         promotionalText="Промо", whatsNew="iPad", supportUrl="https://ziganshin.pro", marketingUrl=None)],
            "appInfoLocalizations": [
                resource("il-us", locale="en-US", name="GrowingUp Watcher", subtitle="Old",
                         privacyPolicyUrl="https://ziganshin.pro/growing-up/privacy-policy", privacyChoicesUrl=None),
                resource("il-ru", locale="ru", name="GrowingUp Watcher", subtitle="Старый",
                         privacyPolicyUrl="https://ziganshin.pro/growing-up/privacy-policy", privacyChoicesUrl=None)],
        }

    def collection(self, path, **query):
        if path.endswith("/appStoreVersions"):
            return self.versions
        if path.endswith("/appInfos"):
            return self.infos
        if path == "/v1/appStoreVersions/v31/appStoreVersionLocalizations":
            return self.locs["appStoreVersionLocalizations"]
        if path == "/v1/appInfos/draft/appInfoLocalizations":
            return self.locs["appInfoLocalizations"]
        raise AssertionError(path)

    def create(self, kind, attributes, relationships):
        self.calls.append(("create", kind, attributes["locale"], relationships))
        self.locs[kind].append(resource(f"new-{len(self.calls)}", **attributes))

    def request(self, method, path, data):
        kind, identifier = path.split("/")[2:4]
        self.calls.append((method, kind, identifier))
        target = next(item for item in self.locs[kind] if item["id"] == identifier)
        target["attributes"].update(data["data"]["attributes"])


class ListingTests(unittest.TestCase):
    def setUp(self):
        self.listing = listing_tool.load_listing()

    def test_committed_listing_is_valid(self):
        self.assertEqual(listing_tool.validate(self.listing), [])

    def test_cis_localization_carries_the_russian_name(self):
        """Kazakhstan and the rest of the CIS index only en-GB, so the Russian name must be findable there."""
        locales = self.listing["localizations"]
        carried = set(listing_tool.words(locales["en-GB"]["keywords"]))
        for word in listing_tool.words(locales["ru"]["name"]):
            if word != listing_tool.BRAND:
                self.assertIn(word, carried)
        broken = copy.deepcopy(self.listing)
        broken["localizations"]["en-GB"]["keywords"] = "baby,widget"
        self.assertTrue(any("Russian name" in p for p in listing_tool.validate(broken)))

    def test_rejects_apple_limit_and_keyword_format_violations(self):
        broken = copy.deepcopy(self.listing)
        fields = broken["localizations"]["ru"]
        fields["name"] = "Ж" * 31
        fields["keywords"] = "малыш, дети,малыш,виджеты"
        problems = listing_tool.validate(broken)
        self.assertTrue(any("name has 31" in p for p in problems))
        self.assertTrue(any("without spaces" in p for p in problems))
        self.assertTrue(any("repeat a term" in p for p in problems))
        self.assertTrue(any("виджеты" in p for p in problems), "subtitle words must not be repeated")

    def test_yo_counts_as_ye(self):
        self.assertEqual(listing_tool.words("Ребёнок, ёж"), ["ребенок", "еж"])

    def test_plan_creates_en_gb_from_en_us_texts(self):
        state = listing_tool.read_state(FakeAPI())
        changes = {(c[0], c[1], c[3]): c[4] for c in listing_tool.plan(self.listing, state)}
        version_gb = changes[("create", "appStoreVersionLocalizations", "en-GB")]
        self.assertEqual(version_gb["description"], "Kids grow up fast.")
        self.assertEqual(version_gb["whatsNew"], "iPad")
        self.assertNotIn("marketingUrl", version_gb)
        self.assertEqual(version_gb["keywords"], self.listing["localizations"]["en-GB"]["keywords"])
        info_gb = changes[("create", "appInfoLocalizations", "en-GB")]
        self.assertEqual(info_gb["privacyPolicyUrl"], "https://ziganshin.pro/growing-up/privacy-policy")
        self.assertEqual(changes[("update", "appInfoLocalizations", "ru")],
                         {"name": "GrowingUp: возраст детей", "subtitle": "Дни рождения и виджеты с фото"})
        self.assertEqual(set(changes[("update", "appStoreVersionLocalizations", "en-US")]), {"keywords"})

    def test_apply_writes_then_reads_back_nothing_left(self):
        api = FakeAPI()
        state = listing_tool.read_state(api)
        listing_tool.apply(api, self.listing, state, listing_tool.plan(self.listing, state))
        created = [c for c in api.calls if c[0] == "create"]
        self.assertEqual({(c[1], c[2]) for c in created},
                         {("appInfoLocalizations", "en-GB"), ("appStoreVersionLocalizations", "en-GB")})
        self.assertIn(("create", "appStoreVersionLocalizations", "en-GB",
                       {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": "v31"}}}), api.calls)
        self.assertEqual(listing_tool.plan(self.listing, listing_tool.read_state(api)), [])

    def test_clearing_a_mirrored_text_clears_the_copy(self):
        api = FakeAPI()
        state = listing_tool.read_state(api)
        listing_tool.apply(api, self.listing, state, listing_tool.plan(self.listing, state))
        source = next(i for i in api.locs["appStoreVersionLocalizations"] if i["attributes"]["locale"] == "en-US")
        source["attributes"]["promotionalText"] = None
        changes = listing_tool.plan(self.listing, listing_tool.read_state(api))
        self.assertEqual([(c[0], c[3], c[4]) for c in changes], [("update", "en-GB", {"promotionalText": None})])

    def test_refuses_without_an_editable_version(self):
        api = FakeAPI()
        api.versions[1]["attributes"]["appStoreState"] = "WAITING_FOR_REVIEW"
        with self.assertRaisesRegex(ValueError, "editable App Store version"):
            listing_tool.read_state(api)


if __name__ == "__main__":
    unittest.main()
