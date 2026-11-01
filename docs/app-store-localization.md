# App Store localizations per storefront

GrowingUp has three listing localizations: `en-US` (primary), `en-GB` and `ru`. The search fields of each live
in [`marketing/app-store/listing.json`](../marketing/app-store/listing.json); `scripts/app-store-listing.py`
checks them and applies them to the editable version.

## Shown and searched are different things

Each storefront **shows** the listing in the customer's device language when that storefront supports it, and
**searches** only the localizations Apple indexes there. Apple's
[App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/)
table lists English (U.K.) as the only language of Kazakhstan and most of the CIS. That is true for search but
not for display. Checked on 2026-11-01:

- **Shown in Russian** (`apps.apple.com/CC/app/id1461697772?l=ru` returns the `ru` description): ru, ua, by,
  kz, uz, kg, tj, tm, az, am, ge, md and us. Not in lv, lt, ee, mn, il, tr, cy, ae, rs, me, de, gb, pl or fi.
- **Searched in Russian** (iTunes Search API, «кто че подарил» for Who Gave What 1.0, whose Russian words were
  only in `ru`): found in ru, ua and us. Not found in kz, by, uz, az, tj, ge, am, il, tr, rs, de or ae.

| Storefronts | Shown to a Russian-language device | Indexed for search |
|---|---|---|
| Russia | `ru` | `ru`, `en-GB`, Ukrainian |
| Ukraine | `ru` | `en-GB`, `ru`, Ukrainian |
| United States | `ru` | `en-US`, `ru` and 7 other languages |
| Kazakhstan, Belarus, Uzbekistan, Kyrgyzstan, Tajikistan, Turkmenistan, Azerbaijan, Armenia, Georgia, Moldova | `ru` | `en-GB` only |
| Baltics, Mongolia, Israel, Türkiye, Cyprus, UAE, Serbia, Montenegro, Germany and most of Europe | `en-GB` | `en-GB` (plus the local language) |
| United Kingdom, India, Ireland, Africa, most of Asia | `en-GB` | `en-GB` |
| Canada, Japan | `en-US` (no `en-CA` or `ja`) | `en-US` |

Without `en-GB`, every English (U.K.) storefront falls back to the primary `en-US`.

## Scheme

- **`ru`** is what Russian speakers read in Russia, Ukraine, the CIS and the US. Its name is Russian,
  «GrowingUp: возраст детей», so the page and search results read as a Russian app. Its keywords target Russia,
  Ukraine and the US, where `ru` is indexed.
- **`en-GB`** is the only index of the CIS storefronts. Its name and subtitle stay English, because the UK,
  India and the rest of the English (U.K.) world read them, and its subtitle carries the English search words
  (kids, age, birthday, countdown). Its keywords, which nobody sees, carry Russian: every word of the Russian
  name, plus «сколько лет», «день рождения», «малыш», «виджет». So «возраст детей» or «возраст ребенка»
  finds the app in Kazakhstan, and Russian speakers in the Baltics, Israel or Germany find it too. Its
  description, promotional text, What's New and URLs mirror `en-US` (`"mirror": "en-US"`), so there is no
  second English text to maintain.
- **`en-US`** stays fully English for the US, Canada and Japan; the US also indexes `ru`.

App Store search treats ё as е, so keywords use е. Apple combines words from the name, subtitle and keywords of
one localization, never across localizations, and repeating a name or subtitle word in the keywords wastes room;
`scripts/tests/test_app_store_listing.py` checks this, the limits (30/30/100) and that `en-GB` carries the
Russian name.

**Not covered.** Putting Russian into the `en-GB` name or description would show it in the UK and India, so
Russian speakers in the Baltics, Israel and Europe still see the English page; only their search is Russian.
Canada has no Russian search. A real Ukrainian (`uk`) localization would add Ukrainian display in Ukraine and a
third index in Russia, but the app itself has no Ukrainian UI yet.

## The app itself

The app follows the device language, not the storefront: a Russian-language iPhone in Kazakhstan gets the
Russian UI. `scripts/tests/test_strings_parity.py` keeps every English string table paired with a Russian one
with the same keys.

## Applying

Name, subtitle, keywords and new localizations change only on an editable version (not while one waits for
review). After the current version is released and the next one exists in App Store Connect:

```sh
python3 scripts/app-store-listing.py check          # offline
python3 scripts/app-store-listing.py plan           # read-only diff against App Store Connect
python3 scripts/app-store-listing.py apply --confirm 3.1   # writes, then reads back
```

The script uses `ASC_KEY_PATH`/`ASC_KEY_ID`/`ASC_ISSUER_ID` or the Fleet team key and never creates a version,
touches screenshots or submits. Run `apply` again after What's New or the description of `en-US` changes, so
`en-GB` follows. Afterwards, confirm in App Store Connect that `en-GB` uses the `en-US` screenshots; if it shows
none, upload the `en-US` sets to it as well.

**After release** (indexing takes hours to two days), check per storefront, a few seconds apart:
`https://itunes.apple.com/search?term=возраст+детей&country=kz&entity=software` should list `1461697772`, as
should «возраст ребенка» in kz, by and ge. On a Kazakhstan Apple ID with a Russian iPhone, the page should
read «GrowingUp: возраст детей» with the Russian screenshots.
