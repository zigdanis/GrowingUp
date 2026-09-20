# GrowingUp

[![CI](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml/badge.svg?branch=master&event=push)](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml?query=branch%3Amaster+event%3Apush)

iOS app for tracking people and viewing their current age broken down into
time components — years, months, days, hours, minutes and seconds — updating
live.

## Features

* Keep a list of people, each with a name, birth date and photo.
* Add or edit a person, including picking and cropping a photo.
* Person overview with the age counting up in real time.
* A **Home Screen widget** (WidgetKit) that surfaces up to three pinned people
  at a glance, with their age updating at minute granularity.
* Data is shared between the app and the widget through a shared App Group.
* Localized in English and Russian.

## Architecture

The project follows **MVP + Clean Architecture**.

* **`Core`** — a framework holding the business logic, free of UIKit scene code:
  * `Entities` — `Person`, `PersonImage`, `AddPersonParameters`.
  * `UseCases` — `Add`/`Edit`/`Remove`/`FetchPersons` use cases.
  * `Gateways` / `EntityGateway` — persistence and caching behind protocols.
  * `AgeCalculator` — converts a birth date into time components.
* **`GrowingUp`** — the SwiftUI app target. `Presentation/` contains the people,
  overview, empty and editor scenes. Observable main-actor presenters own scene
  state, and `SceneConfigurator` injects Core use cases. `Scenes/EditPerson/ImageCapture/`
  contains the shared photo, crop and camera views and platform adapters.
* **`Widget`** — the WidgetKit extension (SwiftUI), reusing `Core` for its data.

### Persistence

* **Core Data** (`GrowingUp.xcdatamodeld`) is the source of truth, stored in a
  shared **App Group** container (`group.pro.ziganshin.aging`) so the app and
  the widget read and write the same data.
* **[Disk](https://github.com/saoudrizwan/Disk)** caches person images in the
  shared container.

## Dependencies

Managed with **Swift Package Manager** and resolved automatically by Xcode —
no Carthage or CocoaPods step is required:

* [Disk](https://github.com/saoudrizwan/Disk) — file/image persistence.
* [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) — UI-test image comparisons only.

Type-safe resources use **Xcode's generated asset symbols** (e.g.
`UIImage(resource: .personCrowned)`) for images and `String(localized:)` for
localized strings — there is no longer a vendored code generator or R.swift
dependency.

## Requirements

* Xcode 26 or newer (CI pins Xcode 26.6 and 26.3).
* iOS 18.0+ deployment target.

## Building & Running

```
git clone https://github.com/zigdanis/GrowingUp.git
cd GrowingUp
scripts/install-git-hooks.sh
open GrowingUp.xcodeproj
```

Select the **GrowingUp** scheme and run on any iOS Simulator. Xcode resolves
the Swift packages on first open. Debug builds use automatic ("Sign to Run
Locally") code signing, so no provisioning profile is needed for the simulator.

From the command line:

```
xcodebuild -project GrowingUp.xcodeproj -scheme GrowingUp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Tests

Unit tests live in `GrowingUpTests/` (covering gateways, presenters and use
cases) and run via the **GrowingUp** scheme (⌘U) or:

```
xcodebuild test -project GrowingUp.xcodeproj -scheme GrowingUp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Tooling

* **[swift-format](https://github.com/swiftlang/swift-format)** uses the
  repository `.swift-format` policy. Run `scripts/format-swift.sh` to format all
  first-party Swift sources or `scripts/check-formatting.sh` to check without
  changing files. The scripts use the formatter from the selected Xcode
  toolchain on macOS and a standalone `swift-format` on Linux. On Linux,
  install the pinned toolchain with `swiftly install`. CI uses Xcode's formatter.
  Zed uses the same formatter automatically on save via `.zed/settings.json`.
* **[SwiftLint](https://github.com/realm/SwiftLint)** runs as an optional build
  phase (skipped with a warning if not installed); run
  `scripts/lint-swift.sh` for the same strict check used in CI.
* **Git hooks** are installed once per clone with
  `scripts/install-git-hooks.sh`. They check formatting and SwiftLint before
  every commit. Fix reported violations instead of bypassing the hook.
* **[fastlane](https://fastlane.tools)** lanes under `fastlane/` handle
  TestFlight distribution and `match`-based signing for release builds.
* **CI** — GitHub Actions (`.github/workflows/ci.yml`) checks formatting, runs
  SwiftLint, and builds + tests on an iOS Simulator on every pull request and
  on pushes to `master`.

### Editor integration

Zed formats Swift files on save using the project `.zed/settings.json`. It
passes the unsaved buffer through Xcode's `swift-format` and uses the file path
to discover the repository `.swift-format` configuration.

For build diagnostics and code completion, install
[`xcode-build-server`](https://github.com/SolaWing/xcode-build-server) and
generate its machine-specific configuration from the repository root:

```bash
brew install xcode-build-server
xcode-build-server config -project GrowingUp.xcodeproj -scheme GrowingUp
```

The generated `buildServer.json` contains absolute local paths and is ignored
by Git.

The official `swift-format` project does not provide a repository-aware Xcode
Source Editor Extension. Xcode's **Editor → Structure → Re-Indent** command also
does not apply `.swift-format`. To format one saved file exactly, run:

```bash
cd /path/to/GrowingUp
xcrun swift-format format --configuration .swift-format --in-place path/to/File.swift
```

An editor automation may wrap this command, but it is optional; the repository
scripts and CI check remain the source of truth.

## Authors

* **Danis Ziganshin** — *Initial work* — [zigdanis](https://github.com/zigdanis)

## License

GrowingUp is available under the [MIT License](LICENSE).


### SwiftUI scenes and validation

The iOS 18+ app uses SwiftUI with MVP + Clean Architecture: scene views send intents to observable main-actor presenters; `SceneConfigurator` injects Core use cases. Core Data and shared App Group image transactions remain in Core. SwiftUI owns paging and sheet navigation; the remaining UIKit adapters are limited to camera/photo platform APIs and startup file protection.

Run `scripts/check-formatting.sh`, `scripts/lint-swift.sh`, and the `GrowingUp` scheme tests. `GrowingUpUI` runs five XCUI journeys (add/persist, both photo slots/crop, cancel/error recovery, pin/deep link, delete/persist) plus focused EN/RU and light/dark screenshots. Each test uses a UUID-scoped SQLite/image directory and original deterministic landscape fixtures; normal app/widget storage is not reset.

Visual comparisons use SnapshotTesting pinned at revision `98ba2e1a302c405dd8752e9fcacef0d5f500cac9`. The Glass CI job compares full checkpoints and photo-control regions on iOS 26.5 / iPhone 17 Pro / arm64. The iOS 18.5 / iPhone 16 job checks behavior and retains screenshots. Both upload `.xcresult` bundles, including expected/actual/difference attachments for failed image comparisons.

For deliberate baseline recording on the pinned simulator, set its status bar to 09:41, then run `xcodebuild test -scheme GrowingUpUI -destination 'id=SIMULATOR_UUID' -parallel-testing-enabled NO GROWINGUP_VISUAL_CHECKS=1 GROWINGUP_RECORD_SNAPSHOTS=1`. Inspect every image in `GrowingUpUITests/__Snapshots__/JourneyTests` before committing. Normal comparisons use `GROWINGUP_VISUAL_CHECKS=1 GROWINGUP_RECORD_SNAPSHOTS=0`; missing images fail. Toolchain or appearance changes require reviewed baselines. Camera hardware capture and animated glass refraction still require a device check.

The XCUI target explicitly clears `OTHER_SWIFT_FLAGS` because Xcode otherwise inherits the `Testing=_Testing_Unavailable` alias, preventing SnapshotTesting's Swift Testing support from being imported. This target-scoped configuration uses the [upstream discussion workaround](https://github.com/pointfreeco/swift-snapshot-testing/discussions/901); app and unit-test compiler flags remain inherited.
