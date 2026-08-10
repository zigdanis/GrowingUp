# Migration: UIKit + XIB/Storyboard + MVP → SwiftUI

> **Agent prompt — paste this to start the task.**
>
> You are migrating GrowingUp's UI layer from UIKit (XIBs/storyboards) with a
> hand-wired MVP/Clean setup to **SwiftUI**. First produce a concrete,
> scene-by-scene migration plan (post it for review), then implement it
> incrementally.
>
> **Current state**
> - The app target `GrowingUp` uses UIKit. Each feature under `Scenes/` is a
>   **View ↔ Presenter ↔ Configurator** triple:
>   `PersonsList`, `PersonOverview`, `EditPerson`, `EmptyPerson`, plus cell
>   presenters (`TextFieldCell`, `DateCell`, `ImagesCell`, `ToggleCell`).
> - Views are `.xib`-backed `UIViewController`s; navigation is via `*Router`
>   types; DI is manual in `*Configurator` (e.g.
>   `PersonsListConfiguratorImplementation`).
> - Business logic lives in the `Core` framework (Entities, UseCases,
>   Gateways, `AgeCalculator`) and must be **kept and reused** — this migration
>   is UI-only.
> - Custom views in `GrowingUp/Views/` (`GradientView`, `VerticalButton`,
>   `ImagePickerButton`) and a vendored `WDImagePicker` for photo cropping.
> - Resources are referenced via R.swift (`R.generated.swift`). Coordinate with
>   the R.swift modernization ticket if relevant.
>
> **Goal**
> - Replace the UIKit scenes with SwiftUI views + observable view models,
>   driving the same `Core` use cases. Preserve all existing behavior
>   (add/edit/remove person, photo pick+crop, live age counting, EN/RU
>   localization, App Group data sharing).
>
> **Plan must cover**
> 1. Migration order (suggest leaf-first: `EmptyPerson` → `PersonOverview` →
>    `EditPerson` (with its cells) → `PersonsList`), and whether to do a
>    `UIHostingController` bridge incrementally or a single cutover.
> 2. View-model strategy: map each Presenter to an `@Observable` /
>    `ObservableObject` view model that calls the existing `Core` use cases;
>    what to delete (Presenters, Configurators, Routers, XIBs) vs. keep.
> 3. Navigation: replace `*Router` with `NavigationStack` / value-based routing.
> 4. Photo pick + crop: replace `WDImagePicker` with `PhotosPicker` +
>    a SwiftUI cropping approach (evaluate dropping the vendored library).
> 5. Live age: replace timer-driven `UILabel` updates with a SwiftUI
>    `TimelineView`/timer publisher feeding `AgeCalculator`.
> 6. App entry point: keep `AppDelegate` (or move to `App`/`Scene` lifecycle)
>    and how Core Data + App Group wiring is preserved.
> 7. Tests: the `Core`-level tests must keep passing; assess which presenter
>    tests are replaced by view-model tests.
> 8. Deployment target: SwiftUI features assumed — coordinate with the
>    deployment-target bump ticket (target iOS 16+ for `NavigationStack` /
>    `@Observable` or note the floor used).
>
> **Acceptance criteria**
> - App builds and runs with feature parity; no remaining `.xib`/scene
>   storyboards for migrated screens.
> - `Core` business logic unchanged and still unit-tested (green).
> - MVP scaffolding (Presenter/Configurator/Router) for migrated scenes removed.
> - EN/RU localization and App Group data sharing still work.
> - `Readme.md` architecture section updated to describe the SwiftUI structure.
