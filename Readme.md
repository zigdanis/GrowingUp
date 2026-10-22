# GrowingUp

[![CI](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml?query=branch%3Amaster+event%3Apush)

iOS app for tracking people and viewing their current age broken down into
time components — years, months, days, hours, minutes and seconds — updating
live.

## Features

- Keep a list of people, each with a name, birth date and photo.
- Add or edit a person, including picking and cropping a photo.
- Person overview with the age counting up in real time.
- A **Home Screen widget** (WidgetKit) in three sizes shows up to six pinned
  people as photo tiles with a big milestone age and birthday countdowns,
  refreshing only when that text changes.
- **Lock Screen widgets** (ring, rectangular and inline) with the first pinned
  person's age and next birthday, also shown in StandBy.
- Data is shared between the app and the widget through a shared App Group.
- Localized in English and Russian.

## Architecture

The project follows **MVP + Clean Architecture**.

- **`Core`** — a framework holding the business logic, free of UIKit scene code:
    - `Entities` — `Person`, `PersonImage`, `AddPersonParameters`.
    - `UseCases` — `Add`/`Edit`/`Remove`/`FetchPersons` use cases.
    - `Gateways` / `EntityGateway` — persistence and caching behind protocols.
    - `AgeCalculator` — converts a birth date into time components.
- **`GrowingUp`** — the SwiftUI app target. `Presentation/` contains the people,
  overview, empty and editor scenes. Observable main-actor presenters own scene
  state, and `SceneConfigurator` injects Core use cases. `Scenes/EditPerson/ImageCapture/`
  contains the shared photo, crop and camera views and platform adapters.
- **`Widget`** — the WidgetKit extension (SwiftUI), reusing `Core` for its data.

### Persistence

- **Core Data** (`GrowingUp.xcdatamodeld`) is the source of truth, stored in a
  shared **App Group** container (`group.pro.ziganshin.aging`) so the app and
  the widget read and write the same data.
- **[Disk](https://github.com/saoudrizwan/Disk)** caches person images in the
  shared container.

## Dependencies

Managed with **Swift Package Manager** and resolved automatically by Xcode —
no Carthage or CocoaPods step is required:

- [Disk](https://github.com/saoudrizwan/Disk) — file/image persistence.

## Requirements

- Xcode 27.1 or newer. Release builds must use the iOS 27.1 SDK, the first whose
  builds fill both iPhone Duo displays instead of running letterboxed; the
  archive check rejects older SDKs. CI runs Xcode 27.1 on GitHub's `xcode-27`
  runners.
- iOS 18.1+ deployment target. CI's UI journeys cover iPhone 17 Pro (iOS 26.5)
  and iPhone Duo (iOS 27.1, Xcode 27.1) on every app change, plus iPhone 18 Pro
  (iOS 27.0) and iPhone 16 (iOS 18.5) on master.

## Tooling

- **[swift-format](https://github.com/swiftlang/swift-format)** uses the
  repository `.swift-format` policy. Run `scripts/format-swift.sh` to format all
  first-party Swift sources or `scripts/check-formatting.sh` to check without
  changing files. The scripts use the formatter from the selected Xcode
  toolchain on macOS and a standalone `swift-format` on Linux. On Linux,
  install the pinned toolchain with `swiftly install`. CI uses Xcode's formatter.
  VS Code formats on save through Xcode's SourceKit-LSP via `.vscode/settings.json`;
  install the recommended Swift and SweetPad extensions. For full code completion,
  install the SweetPad CLI (`brew install sweetpad-dev/tap/sweetpad`) and run
  `sweetpad bsp init` once per clone. The generated `buildServer.json` is
  machine-specific; keep it out of Git.
- **[SwiftLint](https://github.com/realm/SwiftLint)** runs as an optional build
  phase (skipped with a warning if not installed); run
  `scripts/lint-swift.sh` for the same strict check used in CI.
- **Git hooks** are installed once per clone with
  `scripts/install-git-hooks.sh`. They check formatting and SwiftLint before
  every commit. Fix reported violations instead of bypassing the hook.
- **[fastlane](https://fastlane.tools)** lanes under `fastlane/` handle
  TestFlight distribution and `match`-based signing for release builds.
- **CI** — GitHub Actions (`.github/workflows/ci.yml`) checks formatting, runs
  SwiftLint, and builds + tests on an iOS Simulator on every pull request and
  on pushes to `master`.

## TestFlight deployment

One-time Mac setup (an existing App Store Connect API key JSON, kept outside Git):

```sh
scripts/testflight setup local --api-key /path/to/asc_api_key.json
```

Generate English/Russian notes with your signed-in local Codex CLI and review the
printed text. No filename is needed:

```sh
scripts/testflight notes
```

Then choose **one** deployment location:

```sh
scripts/testflight deploy local --version 2.2.0  # build and upload on your Mac
# or
scripts/testflight deploy cloud --version 2.2.0  # build and upload in GitHub Actions
```

Both paths select the next free build number, apply matching app/widget versions,
sign, upload, publish EN/RU notes and distribute to the tester group. Omit `--version`
to choose the next patch above the recorded Apple/beta versions. New explicit
versions must exceed the approved App Store version. Notes are regenerated if the
source changes. Credentials stay in the Mac Keychain/private API key file locally,
or the existing protected GitHub `testflight` environment in the cloud.

`scripts/testflight check local` (or `cloud`) checks without uploading;
`archive local` (or `cloud`) creates an archive without uploading.
Use `status local` / `status cloud` to check the latest release and `resume local` /
`resume cloud` to continue it after an interruption, preserving its version/build.
An optional release ID selects an older release. Apple beta review may still be
required before the build appears on a tester's device.

See [release setup](fastlane/README.md) for prerequisites and compatibility commands.

## Authors

- **Danis Ziganshin** — _Initial work_ — [zigdanis](https://github.com/zigdanis)

## License

GrowingUp is available under the [MIT License](LICENSE).
