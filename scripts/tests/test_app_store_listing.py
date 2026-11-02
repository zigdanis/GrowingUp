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
    """App Store Connect with an editable 3.1.0 that still has the 3.0.0 search fields."""

    def __init__(self):
        self.calls = []
        self.versions = [resource("v30", versionString="3.0.0", appStoreState="READY_FOR_SALE"),
                         resource("v31", versionString="3.1.0", appStoreState="PREPARE_FOR_SUBMISSION")]
        self.infos = [resource("live", appStoreState="READY_FOR_SALE", state="READY_FOR_DISTRIBUTION"),
                      resource("draft", appStoreState="PREPARE_FOR_SUBMISSION", state="PREPARE_FOR_SUBMISSION")]
        self.locs = {
            "appStoreVersionLocalizations": [
                resource("vl-us", locale="en-US", keywords="baby,kids", description="Kids grow up fast."),
                resource("vl-ru", locale="ru", keywords="ребенок,дети", description="Дети растут быстро.")],
            "appInfoLocalizations": [
                resource("il-us", locale="en-US", name="GrowingUp Watcher", subtitle="Exact age & birthday widgets"),
                resource("il-ru", locale="ru", name="GrowingUp Watcher", subtitle="Точный возраст и дни рождения")],
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

    def request(self, method, path, data):
        kind, identifier = path.split("/")[2:4]
        self.calls.append((method, kind, identifier, data["data"]["attributes"]))
        target = next(item for item in self.locs[kind] if item["id"] == identifier)
        target["attributes"].update(data["data"]["attributes"])


class ListingTests(unittest.TestCase):
    def setUp(self):
        self.listing = listing_tool.load_listing()

    def test_committed_listing_is_valid(self):
        self.assertEqual(listing_tool.validate(self.listing), [])

    def test_en_us_carries_the_russian_name_for_cis_search(self):
        """Kazakhstan and the rest of the CIS search only en-US here, so the Russian name must be findable there."""
        locales = self.listing["localizations"]
        carried = set(listing_tool.words(locales["en-US"]["keywords"]))
        for word in listing_tool.words(locales["ru"]["name"]):
            if word != "growingup" and len(word) > 1:
                self.assertIn(word, carried)
        broken = copy.deepcopy(self.listing)
        broken["localizations"]["en-US"]["keywords"] = "baby,widget"
        self.assertTrue(any("Russian name" in p for p in listing_tool.validate(broken)))

    def test_rejects_apple_limit_and_keyword_format_violations(self):
        broken = copy.deepcopy(self.listing)
        fields = broken["localizations"]["ru"]
        fields["name"] = "Ж" * 31
        fields["keywords"] = "малыш, дети,малыш,близких"
        problems = listing_tool.validate(broken)
        self.assertTrue(any("name has 31" in p for p in problems))
        self.assertTrue(any("without spaces" in p for p in problems))
        self.assertTrue(any("repeat a term" in p for p in problems))
        self.assertTrue(any("близких" in p for p in problems), "subtitle words must not be repeated")

    def test_yo_counts_as_ye(self):
        self.assertEqual(listing_tool.words("Ребёнок, ёж"), ["ребенок", "еж"])

    def test_plan_updates_only_the_search_fields(self):
        changes = listing_tool.plan(self.listing, listing_tool.read_state(FakeAPI()))
        by_target = {(kind, locale): attributes for kind, _, locale, attributes in changes}
        self.assertEqual(by_target[("appInfoLocalizations", "ru")],
                         {"name": "GrowingUp: сколько лет и дней", "subtitle": "Возраст близких и дни рождения"})
        self.assertNotIn(("appInfoLocalizations", "en-US"), by_target, "en-US name and subtitle stay")
        self.assertEqual(set(by_target[("appStoreVersionLocalizations", "en-US")]), {"keywords"})

    def test_apply_patches_then_reads_back_nothing_left(self):
        api = FakeAPI()
        state = listing_tool.read_state(api)
        listing_tool.apply(api, self.listing, state, listing_tool.plan(self.listing, state))
        self.assertTrue(all(call[0] == "PATCH" for call in api.calls))
        self.assertEqual(len(api.calls), 3)
        self.assertEqual(listing_tool.plan(self.listing, listing_tool.read_state(api)), [])

    def test_refuses_a_localization_missing_in_app_store_connect(self):
        listing = copy.deepcopy(self.listing)
        listing["localizations"]["en-GB"] = copy.deepcopy(listing["localizations"]["en-US"])
        with self.assertRaisesRegex(ValueError, "en-GB is missing"):
            listing_tool.plan(listing, listing_tool.read_state(FakeAPI()))

    def test_refuses_without_an_editable_version(self):
        api = FakeAPI()
        api.versions[1]["attributes"]["appStoreState"] = "WAITING_FOR_REVIEW"
        with self.assertRaisesRegex(ValueError, "editable App Store version"):
            listing_tool.read_state(api)


if __name__ == "__main__":
    unittest.main()
