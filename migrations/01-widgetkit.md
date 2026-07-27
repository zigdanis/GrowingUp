# Migration: Today extension → WidgetKit

> **Agent prompt — paste this to start the task.**
>
> You are migrating the `Widget` target of GrowingUp from a legacy iOS Today
> extension to modern **WidgetKit**. First produce a concrete migration plan
> (post it for review), then implement it.
>
> **Current state**
> - `Widget/` is a Today extension: `NSExtensionPointIdentifier =
>   com.apple.widget-extension`, `NSExtensionMainStoryboard = MainInterface`.
> - `TodayViewController` implements `NCWidgetProviding` (`import
>   NotificationCenter`) and renders up to 3 pinned people in a `UIStackView`
>   built from a `MainInterface.storyboard`.
> - It reuses the `Core` framework for data, reading Core Data from the shared
>   App Group `group.pro.ziganshin.aging`. Disk caches the person images.
> - Today extensions were removed from iOS in 14.0, so this no longer appears
>   on device.
>
> **Goal**
> - Replace the Today extension with a WidgetKit widget that shows the same
>   pinned people and their live age, reusing `Core` (entities, gateways,
>   `AgeCalculator`) and the shared App Group container.
>
> **Plan must cover**
> 1. New `WidgetKit` extension target + `App Group` entitlement wiring (keep
>    `group.pro.ziganshin.aging`); how the old `com.apple.widget-extension`
>    target is removed/replaced in `project.pbxproj`.
> 2. `TimelineProvider` design: how often the age "ticks" and the timeline
>    refresh/budget strategy (age changes every second — pick a sane cadence,
>    e.g. minute-level entries + relative text, since per-second refresh is not
>    allowed for home-screen widgets).
> 3. Widget families to support (`.systemSmall` / `.systemMedium`) and the
>    SwiftUI views, reusing `AgeCalculator` from `Core`.
> 4. Deep-linking back into the app on tap (preserve current "open the correct
>    person" behavior) via `widgetURL` / `Link`.
> 5. Reading Core Data + Disk images from the App Group inside the widget
>    process; handling the 3-person limit.
> 6. Deployment target implications (WidgetKit needs iOS 14+). Coordinate with
>    the deployment-target bump if that PR has not merged yet.
>
> **Acceptance criteria**
> - App builds and runs; the WidgetKit widget appears on the Home Screen and
>   shows pinned people with up-to-date age.
> - Tapping a person opens the app on that person.
> - The old Today extension target and `NotificationCenter`/`NCWidgetProviding`
>   code are gone.
> - `Core` is still shared (no business-logic duplication).
> - Update `Readme.md` (remove the "older Today extension" note).
