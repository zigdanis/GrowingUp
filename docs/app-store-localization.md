# App Store localizations per storefront

GrowingUp has two listing localizations: `en-US` (primary) and `ru`. The search fields of each live in [`marketing/app-store/listing.json`](../marketing/app-store/listing.json); `scripts/app-store-listing.py`
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
| Russia | `ru` | `ru` (and English) |
| Ukraine | `ru` | `en-US`, `ru` |
| United States | `ru` | `en-US`, `ru` |
| Kazakhstan, Belarus, Uzbekistan, Kyrgyzstan, Tajikistan, Turkmenistan, Azerbaijan, Armenia, Georgia, Moldova | `ru` | **`en-US` only** |
| Baltics, Mongolia, Israel, Türkiye, Cyprus, UAE, Serbia, Montenegro, Germany and most of Europe | `en-US` | `en-US` (plus the local language) |
| United Kingdom, India, Canada, the rest of the world | `en-US` | `en-US` |

We have no `en-GB`, so every English (U.K.) storefront falls back to the primary `en-US` for both.

## Scheme

- **`ru`** is what Russian speakers read in Russia, Ukraine, the CIS and the US. Its name, «GrowingUp: сколько
  лет и дней», and subtitle, «Возраст близких и дни рождения», say what the app does for anyone: children,
  adults, family, pets or a date such as the day you quit smoking. Its keywords target Russia, Ukraine and the
  US, where `ru` is indexed, and add those uses (родные, питомец, не курю, трезвость).
- **`en-US`** is the only index of the CIS storefronts, so its keywords, which nobody sees, give up some English
  words (toddler, newborn, calculator, lock screen, milestone) for Russian: every word of the Russian name
  (сколько, лет, дней) plus возраст, счетчик and рождения. «сколько лет и дней», «возраст» or «счетчик дней»
  then find the app in Kazakhstan, and Russian speakers in the Baltics, Israel or Germany find it too. Its name
  and subtitle stay English.

Most users are expected in Russia, which indexes `ru` fully, so the English keyword room is the cheaper one to
spend. If App Analytics later shows most downloads abroad, move words back, or add an `en-GB` localization with
the Russian keywords: it would take over search in every English (U.K.) storefront and leave `en-US` to the US.

App Store search treats ё as е, so keywords use е. Apple combines words from the name, subtitle and keywords of
one localization, never across localizations, and repeating a name or subtitle word in the keywords wastes room;
`scripts/tests/test_app_store_listing.py` checks this, the limits (30/30/100) and that `en-US` carries the
Russian name.

**Not covered.** Russian speakers in the Baltics, Israel and Europe see the English page, because those
storefronts don't show Russian; only their search is Russian. Generic Russian searches beyond these words still
match only where `ru` is indexed.

## The app itself

The app follows the device language, not the storefront: a Russian-language iPhone in Kazakhstan gets the
Russian UI. `scripts/tests/test_strings_parity.py` keeps every English string table paired with a Russian one
with the same keys.

## Applying

Name, subtitle and keywords change only on an editable version (not while one waits for
review). After the current version is released and the next one exists in App Store Connect:

```sh
python3 scripts/app-store-listing.py check          # offline
python3 scripts/app-store-listing.py plan           # read-only diff against App Store Connect
python3 scripts/app-store-listing.py apply --confirm 3.1.0 # writes, then reads back
```

The script uses `ASC_KEY_PATH`/`ASC_KEY_ID`/`ASC_ISSUER_ID` or the Fleet team key. It changes only name,
subtitle and keywords of existing localizations, and never creates a version, touches texts or screenshots, or
submits.

Applied to 3.1.0 on 2026-11-02 (read back matched). On a machine without PyJWT, run the script from a venv with
`pyjwt` and `cryptography`.

**After release** (indexing takes hours to two days), check per storefront, a few seconds apart:
`https://itunes.apple.com/search?term=сколько+лет+и+дней&country=kz&entity=software` should list `1461697772`,
as should «возраст» and «счетчик дней» in kz, by and ge. On a Kazakhstan Apple ID with a Russian iPhone, the
page should read «GrowingUp: сколько лет и дней» with the Russian screenshots.
