# Migration: Bump deployment target to iOS 18

> **Agent prompt — paste this to start the task.**
>
> You are raising GrowingUp's minimum deployment target to **iOS 18** across all
> targets and modernizing the source/build settings that the bump unlocks or
> requires. First produce a concrete plan (post it for review), then implement
> it.
>
> **Current state**
> - `IPHONEOS_DEPLOYMENT_TARGET = 12.0`, `objectVersion = 50`, Swift 5.0.
> - Targets: `GrowingUp` (app), `Core` (framework), `Widget` (Today extension),
>   `GrowingUpTests`.
> - Legacy source idioms exist, e.g. `protocol X: class` (`TodayView`,
>   `TodayProviding`), `#available` / availability guards for old iOS versions,
>   and a custom `Core/iOS Framework APIs/Obfuscator.swift`.
>
> **Goal**
> - Set the deployment target to **iOS 18.0** on every target consistently.
> - Remove now-dead backwards-compatibility code paths and modernize idioms the
>   new floor makes safe.
>
> **Plan must cover**
> 1. Setting `IPHONEOS_DEPLOYMENT_TARGET = 18.0` on app, Core, Widget and test
>    targets; bumping `objectVersion`/`LastUpgradeCheck` and Swift language
>    version to current; removing stale per-config overrides.
> 2. An audit of every `#available` / `if #available` / `@available` guard and
>    deletion of branches now unreachable below iOS 18.
> 3. Source modernization: `class`→`AnyObject` in protocol inheritance, remove
>    workarounds for pre-18 behavior, audit the dead `Obfuscator`.
> 4. **Device-support callout:** iOS 18 drops every device older than the
>    iPhone XS/XR generation. Confirm this is intended and state it in the PR.
> 5. Coordination with the WidgetKit ticket (needs ≥14) and the SwiftUI ticket
>    (uses `NavigationStack`/`@Observable`, ≥16) — iOS 18 satisfies both; note
>    merge ordering. **Overlaps PR #4 sub-task B (which proposed iOS 16); this
>    ticket supersedes that floor with iOS 18.**
>
> **Acceptance criteria**
> - All targets build and tests pass on the current Xcode/SDK with an iOS 18
>   minimum and no deprecated-setting warnings.
> - No remaining availability guards for iOS < 18.
> - `Readme.md` "Requirements" updated to iOS 18.0+.
