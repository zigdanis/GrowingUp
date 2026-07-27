# GrowingUp

[![CI](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml/badge.svg)](https://github.com/zigdanis/GrowingUp/actions/workflows/ci.yml)

iOS app for tracking people and viewing their current age broken down into
time components — years, months, days, hours, minutes and seconds — updating
live.

Current version: **2.0.0**.

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
* **`GrowingUp`** — the app target. Each feature under `Scenes/`
  (`PersonsList`, `PersonOverview`, `EditPerson`, `EmptyPerson`) is wired as a
  View ↔ Presenter ↔ Configurator triple.
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

Type-safe resources use **Xcode's generated asset symbols** (e.g.
`UIImage(resource: .personCrowned)`) for images and `String(localized:)` for
localized strings — there is no longer a vendored code generator or R.swift
dependency.

## Requirements

* Xcode 16 or newer (developed against Xcode 26 / iOS 26 SDK).
* iOS 18.0+ deployment target.

## Building & Running

```
git clone git@github.com:zigdanis/GrowingUp.git
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
  changing files. The formatter bundled with the selected Xcode toolchain is
  used locally and in CI. Zed uses the same formatter automatically on save via
  `.zed/settings.json`.
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

## Security

Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).
