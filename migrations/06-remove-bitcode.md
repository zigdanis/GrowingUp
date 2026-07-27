# Migration: Remove bitcode

**Status:** Completed by `5535ec4` and verified after merging `master` into this branch.

> **Agent prompt — paste this to start the task.**
>
> You are removing all bitcode usage from GrowingUp. First produce a short plan
> (post it for review), then implement it. This is a small, self-contained task.
>
> **Background**
> - Apple **deprecated bitcode in Xcode 14 and removed it** (the App Store no
>   longer accepts bitcode; modern Xcode ignores/strips it). Keeping it produces
>   warnings and dead configuration.
>
> **Original state**
> - `fastlane/Fastfile` called `gym(... include_bitcode: true)` in the
>   `app_store` lane.
> - Check `GrowingUp.xcodeproj/project.pbxproj` for `ENABLE_BITCODE` build
>   settings on every target/configuration (app, `Core`, `Widget`, tests).
>
> **Goal**
> - Remove bitcode from both the build settings and the release pipeline.
>
> **Plan must cover**
> 1. Remove `include_bitcode: true` from the `gym` call in `Fastfile` (or set it
>    to `false`/omit, per current `gym` defaults).
> 2. Remove any `ENABLE_BITCODE = YES` from `project.pbxproj`; rely on the modern
>    default (no bitcode). Verify no target still sets it.
> 3. Confirm no other references (xcconfig, scripts, CI).
>
> **Acceptance criteria**
> - No `include_bitcode` / `ENABLE_BITCODE` anywhere in the repo.
> - App + Widget build cleanly with no bitcode-related warnings.
> - Release lane (`gym`) builds without the deprecated option.
>
> **Implementation**
> - `include_bitcode: true` was removed from the `gym` call.
> - The Xcode project has no `ENABLE_BITCODE` build settings.
> - Repository-wide verification found no remaining active bitcode configuration.
>
> **Overlap note:** PR #4 sub-task D and the fastlane ticket both touch the
> Fastfile; this ticket is the source of truth for the bitcode removal
> specifically. Coordinate to avoid a merge conflict on the `gym` call.
