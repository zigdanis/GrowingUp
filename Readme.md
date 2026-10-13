# GrowingUp

[![CI](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml?query=branch%3Amaster+event%3Apush)

iOS app for tracking people and viewing their current age broken down into
time components — years, months, days, hours, minutes and seconds — updating
live.

## Features

- Keep a list of people, each with a name, birth date and photo.
- Add or edit a person, including picking and cropping a photo.
- Person overview with the age counting up in real time.
- A **Home Screen widget** (WidgetKit) that surfaces up to three pinned people
  at a glance, with their age updating at minute granularity.
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
- [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) — UI-test image comparisons only.

## Requirements

- Xcode 26 or newer (CI pins Xcode 26.6 and 26.3).
- iOS 18.1+ deployment target.

## Tooling

- **[swift-format](https://github.com/swiftlang/swift-format)** uses the
  repository `.swift-format` policy. Run `scripts/format-swift.sh` to format all
  first-party Swift sources or `scripts/check-formatting.sh` to check without
  changing files. The scripts use the formatter from the selected Xcode
  toolchain on macOS and a standalone `swift-format` on Linux. On Linux,
  install the pinned toolchain with `swiftly install`. CI uses Xcode's formatter.
  Zed uses the same formatter automatically on save via `.zed/settings.json`.
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

## Authors

- **Danis Ziganshin** — _Initial work_ — [zigdanis](https://github.com/zigdanis)

## License

GrowingUp is available under the [MIT License](LICENSE).
