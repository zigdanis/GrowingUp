# App Store localizations per storefront

GrowingUp has three listing localizations: `en-US` (primary), `en-GB` and `ru`. The search fields of each live in
[`marketing/app-store/listing.json`](../marketing/app-store/listing.json); `scripts/app-store-listing.py` checks them
and applies them to the editable version.

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

Apple's table also lists English (U.K.) in almost every other storefront, including Russia and Ukraine. Only
the United States, Canada and Japan lack it; they search `en-US` (Canada through fallback to the primary).

| Storefronts | Shown to a Russian-language device | Indexed for search |
|---|---|---|
| Russia, Ukraine | `ru` | `ru`, `en-GB` |
| United States | `ru` | `en-US`, `ru` |
| Kazakhstan, Belarus, Uzbekistan, Kyrgyzstan, Tajikistan, Turkmenistan, Azerbaijan, Armenia, Georgia, Moldova | `ru` | **`en-GB` only** |
| Baltics, Mongolia, Israel, Türkiye, Cyprus, UAE, Serbia, Montenegro, Germany and most of Europe | `en-GB` | `en-GB` (plus the local language) |
| United Kingdom, India, Australia and the rest of the world | `en-GB` | `en-GB` |
| Canada, Japan | `en-US` | `en-US` |

## Scheme

Decided by Danis on 2026-11-02: Russian search in Kazakhstan and the CIS matters more than English keywords
outside the US.

- **`ru`** is what Russian speakers read in Russia, Ukraine, the CIS and the US. Its name, «Кому сколько»
  (since 3.1.1, 2026-11-08; also the Russian name under the home screen icon), and subtitle, «Возраст близких и дни рождения», say what the app does for anyone: children,
  adults, family, pets or a date such as the day you quit smoking. Its keywords target Russia, Ukraine and the
  US, where `ru` is indexed, and add those uses (родные, питомец, не курю, трезвость).
- **`en-GB`** is the only index of the CIS storefronts. Its name and subtitle stay English, because English-language
  devices in the UK, Europe and India read them, but all its keyword room (99 of 100 characters), which nobody sees, is
  Russian: every word of the Russian name (кому, сколько) plus the common forms of how-old, birthday, age, counter,
  calculator, child and "days since" queries (лет, дней, день, дни, рождения, возраст, возраста, счетчик,
  калькулятор, ребенок, отсчет, прошло). Russia and Ukraine index it next to `ru`, and Russian speakers in the Baltics,
  Israel or Germany find the app too. Its description, What's New and promotional text are copies of `en-US`, and its
  screenshots default to the primary language's.
- **`en-US`** keeps English keywords. Outside the United States, Canada and Japan English searches match only the
  name and subtitle words (GrowingUp, Watcher, exact, age, birthday, widgets).

If App Analytics later shows English downloads outside the US matter more, move some English words into `en-GB`.

App Store search treats ё as е, so keywords use е. Apple combines words from the name, subtitle and keywords of
one localization, never across localizations, and repeating a name or subtitle word in the keywords wastes room;
`scripts/tests/test_app_store_listing.py` checks this, the limits (30/30/100), that `en-GB` carries the
Russian name and that `en-US` stays English.

**Not covered.** Russian speakers in the Baltics, Israel and Europe see the English page, because those
storefronts don't show Russian; only their search is Russian. Generic Russian searches beyond these words still
match only where `ru` is indexed. App Store search may not match other word forms, so the keywords carry the forms
people type (день, дни, дней; возраст, возраста).

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
subtitle and keywords of existing localizations and copies the `en-US` description, What's New, promotional text and
URLs into `en-GB`. It never creates a version or localization, edits the `en-US` or `ru` texts, touches
screenshots, or submits. After editing the `en-US` texts in App Store Connect, run `plan` and `apply` again.

Applied to 3.1.0 on 2026-11-02 (read back matched). On a machine without PyJWT, run the script from a venv with
`pyjwt` and `cryptography`.

The `en-GB` localization was created once, on 3.1.0 (2026-11-02), with the API: POST an `appInfoLocalizations`
entry (name, subtitle, privacy policy URL), which also creates an empty `appStoreVersionLocalizations` entry,
then PATCH that with copies of the `en-US` description, What's New, promotional text and support URL. Later
versions inherit the localization.

**After release** (indexing takes hours to two days), check per storefront, a few seconds apart:
`https://itunes.apple.com/search?term=кому+сколько&country=kz&entity=software` should list `1461697772`,
as should «сколько лет», «возраст», «день рождения» and «счетчик дней» in kz, by and ge, and «toddler» in us. On a Kazakhstan Apple ID with a Russian iPhone, the
page should read «Кому сколько» with the Russian screenshots.
