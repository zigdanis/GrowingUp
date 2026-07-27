# Migration: R.swift, build settings, CI & release modernization

> **Agent prompt — paste this to start the task.**
>
> You are modernizing GrowingUp's tooling, build configuration, CI and release
> pipeline. First produce a concrete plan (post it for review), then implement
> it. The four sub-tasks below are independent — sequence them and, if useful,
> land them as separate commits within this branch.
>
> ## Sub-task A — R.swift generator modernization
> **Current:** the `rswift` generator is a **vendored binary** committed under
> `GrowingUp/3rd Party Libraries/rswift/` and run as a build phase to produce
> `R.generated.swift`; the `Rswift` runtime comes from the
> `R.swift.Library` SPM package. The binary in the repo is stale.
> **Goal:** stop vendoring the binary. Either (a) adopt the official **R.swift
> SPM build-tool plugin**, or (b) migrate off R.swift entirely to **Xcode's
> generated asset/string symbols** (`#Resource`-style, available in modern
> Xcode). Evaluate both and recommend one in the plan.
> **Done when:** no binary is committed in the repo; resources are still
> type-safe; app + tests build; `.swiftlint.yml`'s R.generated.swift exclusion
> updated/removed as appropriate.
>
> ## Sub-task B — Deployment target & build-settings cleanup
> **Current:** `IPHONEOS_DEPLOYMENT_TARGET` is **12.0**; `objectVersion = 50`;
> Swift 5.0; legacy `protocol X: class` declarations exist (e.g. `TodayView`,
> `TodayProviding`).
> **Goal:** bump the deployment target to a modern floor (recommend **iOS 16**;
> coordinate with the SwiftUI/WidgetKit tickets which assume 14+/16+), set the
> Swift language version current, remove dead/legacy build settings, and modern­
> ize source: `class`→`AnyObject` in protocol composition, remove
> `ENABLE_BITCODE` if present, audit the custom `Core/iOS Framework
> APIs/Obfuscator.swift` (is it still used? remove if dead).
> **Done when:** project builds on the current Xcode/SDK with no deprecated
> build-setting warnings; deployment target consistent across all targets.
>
> ## Sub-task C — GitHub Actions CI
> **Current:** the old Bitrise badge was removed from the README; there is **no
> CI** in the repo today.
> **Goal:** add a GitHub Actions workflow (`.github/workflows/ci.yml`) that, on
> PR and push to `master`, builds the app and runs the `GrowingUp` unit tests on
> an iOS Simulator, and runs SwiftLint. Use the `xcodebuild` invocations already
> documented in `Readme.md`. Cache SPM where sensible.
> **Done when:** the workflow is green on a test PR; README gets a status badge.
>
> ## Sub-task D — fastlane / release hygiene
> **Current:** `fastlane/Fastfile` uses `gym(... include_bitcode: true)`
> (bitcode is deprecated and removed from Xcode 14+), and the `app_store` lane
> sends a Telegram notification through a **hardcoded HTTP proxy with inline
> credentials** (`proxy: "https://zigdanis:...@.../"`).
> **Goal:** remove `include_bitcode`; move all secrets (Telegram token, proxy,
> any creds) to env/`.env`/CI secrets and out of source; verify the lanes work
> with modern fastlane and `match`. Confirm `fastlane/.env` is gitignored and
> scrub any committed secrets from history if found.
> **Done when:** no bitcode, no secrets in tracked files, lanes documented in
> `Readme.md`.
>
> **Overall acceptance criteria**
> - Repo no longer ships a vendored generator binary; resources stay type-safe.
> - App + tests build and run on current Xcode; CI proves it on every PR.
> - No deprecated bitcode flag; no secrets committed.
> - `Readme.md` updated (dependencies, requirements, CI badge, tooling).
