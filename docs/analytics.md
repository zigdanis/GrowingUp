# Analytics and crash reporting

GrowingUp records anonymous product events with [PostHog](https://posthog.com) and crashes, hangs and
handled failures with [Sentry](https://sentry.io). Both run behind one `AnalyticsGateway` that the
composition root (`AppComposition` → `SceneConfigurator`) owns; presenters talk to the gateway, never
to an SDK.

## What is recorded

The app is about children and other loved ones, so events carry categories, flags and counts only.
A person's name, birthday, age, photo and anything a widget shows are never part of an event, a
breadcrumb or a crash report, and nothing reveals a birthday by its timing (no "birthday today"
event). The catalog lives in `GrowingUp/Analytics/AnalyticsEvent.swift`; `AnalyticsEventTests` keeps
every name, key and text value a snake_case word.

| Event | Properties | Fires when |
|-------|------------|------------|
| `person_viewed` | `source` tile/widget/swipe | The viewer shows a person: a mosaic tile, a widget link, or a swipe (or VoiceOver next/previous) to a neighbour |
| `widget_link_opened` | `target` person/add_person | A Home or Lock Screen widget opened the app |
| `person_editor_opened` | `mode` create/edit, `source` add_button/widget/viewer | The in-place edit mode opens |
| `person_editor_closed` | `mode`, `outcome` saved/cancelled/removed | The edit mode ends through Done, Cancel or Remove |
| `birthday_picker_opened` | `field` date/time | The date or time card opens |
| `photo_picked` | `source` photos/camera | A newly picked photo is framed and placed |
| `photo_removed` | – | Remove in the photo menu |
| `photo_reframed` | – | Done saves a pinch or drag of the photo |
| `widget_picture_framed` | – | The widget circle is framed separately |
| `person_saved` | `mode`, `has_photo`, `photo_changed`, `has_birth_time`, `on_widget`, `celebrates_birthdays`, `people_count`, `widget_people_count` | A person is stored |
| `person_removed` | `people_count` | A person is removed |
| `people_reordered` | `people_count` | A new mosaic order is stored |

PostHog adds its own `Application Installed / Updated / Opened / Backgrounded` events (app version
and build only) and attaches these super properties to everything: `app_environment`
(debug/testflight/appstore), `people_count`, `widget_people_count`. The same counts travel to Sentry
as the `app_state` context, and every product event becomes a Sentry breadcrumb.

Handled failures (`AnalyticsFailure`) go to Sentry only, tagged with `operation`: `load_people`,
`save_order`, `load_widget_people`, `save_person`, `remove_person`, `load_photo`. Only the error's
domain, code and Swift type travel (`AnalyticsFailure.sanitizedError`): a Core Data error can carry
the failing record, and a `CoreError` message can quote one. Cancellation and the six-person widget
limit, which the alert explains, are not reported.

Switched off on purpose:

- PostHog: every swizzling integration (`enableSwizzling = false`): screen views, element and SwiftUI
  autocapture, rage clicks (they read element text), session replay, push. Also GeoIP enrichment
  (`disableGeoIp`), crash autocapture (Sentry owns crashes), feature flags and person profiles; the
  app never calls `identify`.
- Sentry: automatic breadcrumbs (they record view titles and accessibility labels, which name
  people), network breadcrumbs, failed-request capture, screenshots, view hierarchies and default
  PII (IP address, device name). Tracing, profiling and replay stay off (no sample rates are set).

## The widget

The widget extension links neither SDK and reports nothing. It renders exactly the data that must
not leave the device, runs in short-lived processes under a tight memory budget, and its taps are
already counted: a widget link opens the app, which records `widget_link_opened`. Widget crashes
reach Apple's crash reports in Xcode Organizer from users who share analytics with developers.

## When nothing is sent

- The Simulator, unit tests (XCTest variables) and every launch with a `GROWINGUP_` environment
  variable (UI journeys, App Store captures, widget previews) never start the SDKs. UI-test launches
  also use the silent `NoopAnalyticsGateway`.
- Debug builds additionally log every call to the unified log (`subsystem pro.ziganshin.GrowingUp`,
  category `Analytics`). A Debug build on a real device does report, tagged
  `app_environment = debug`, so a run from Xcode can be checked in PostHog and Sentry; filter it out
  of product dashboards.
- An empty key leaves that service off.

There is no in-app switch by design: the data is anonymous.

## Keys

The keys are public client identifiers and live in the `GrowingUp` target build settings, Debug and
Release, exposed through `GrowingUp/Supporting Files/Info.plist`:

| Build setting | Info.plist key | Value |
|---------------|----------------|-------|
| `POSTHOG_API_KEY` | `PostHogAPIKey` | Project API key (`phc_…`) of the GrowingUp project, in its own free PostHog organization (EU Cloud) |
| `POSTHOG_HOST` | `PostHogHost` | `https://eu.i.posthog.com`; empty also means EU |
| `SENTRY_DSN` | `SentryDSN` | DSN of the `apple-ios` project in the `denis-ganshin` Sentry organization (EU, Frankfurt) |

The packages (`posthog-ios`, `sentry-cocoa`) are pinned to "up to next major" ranges and resolved
through the tracked `Package.resolved`, so release builds use the same versions.

## Crash symbols

The TestFlight workflow keeps the archive's dSYMs as the `dsyms-RUN_ID-ATTEMPT` artifact for 90 days
and uploads them to Sentry whenever a `deploy` or `resume` run archived a build, even if a later
distribution step failed. It downloads the pinned `sentry-cli` release binary and checks its
SHA-256 before running it. It needs, in the `testflight` environment:

- secret `SENTRY_AUTH_TOKEN`, an organization token of `denis-ganshin` (`org:ci`);
- variables `SENTRY_ORG` (`denis-ganshin`) and `SENTRY_PROJECT` (`apple-ios`).

Without them it prints a skip notice and the release continues. A build released from a Mac
(`scripts/testflight deploy local`) does not upload symbols; upload them by hand with
`sentry-cli debug-files upload --wait PATH/GrowingUp.xcarchive/dSYMs`.

## App Store privacy

`GrowingUp/Supporting Files/PrivacyInfo.xcprivacy` declares what the app collects; the SDKs ship
their own manifests. App Store Connect → App Privacy must say the same, and the privacy policy at
<https://ziganshin.pro/growing-up/privacy-policy> must describe it:

- Data collection: **Yes**.
- **Identifiers → Device ID** (the random installation IDs PostHog and Sentry create): Analytics; not
  linked to the user; not used for tracking.
- **Usage Data → Product Interaction** (the events above): Analytics; not linked; no tracking.
- **Diagnostics → Crash Data, Performance Data** (crashes, hangs, crash-free sessions) and **Other
  Diagnostic Data** (handled failures): App Functionality; not linked; no tracking.
- Nothing else: no contact info, location, photos, user content or health data leaves the device.
