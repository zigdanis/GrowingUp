# SwiftUI migration with MVP + Clean Architecture

## Problem and intended result

GrowingUp currently combines UIKit scenes and navigation with a SwiftUI photo flow presented through a hosting controller. This migration gives the app SwiftUI screens, navigation and presentation while preserving presenters, injected Core use cases and existing persisted data.

The photo-preview controls also need a defined visual result. The reference LiquidGlassSwiftUI demo uses clear interactive glass over photographic content, while the existing preview uses regular glass with a different background. Compare those conditions before attributing the appearance to UIKit hosting.

## Required boundaries

- Keep MVP + Clean Architecture: views render presenter state and send user intents; presenters call injected Core use cases.
- Keep Core Data, the existing schema, image storage transaction ordering, and App Group `group.pro.ziganshin.aging`.
- Keep iOS 18 as the minimum deployment target. Gate newer glass effects by runtime availability.
- Reuse the existing SwiftUI camera, photo picker and cropper. Narrow UIKit adapters for platform APIs may remain.
- Remove obsolete app view controllers, XIBs, scene storyboards, table-cell scaffolding and explicit UIHostingController composition as their scenes are migrated.
- Preserve English/Russian localization, live age updates, the three-person widget limit, stable pin order and widget deep links.
- Keep persistence/business logic out of SwiftUI view bodies. Do not introduce TCA or a second presentation abstraction alongside presenters.

## Delivery sequence

1. Introduce SwiftUI scene composition and observable presenter state, preserving Core contracts.
2. Migrate empty/overview and add/edit/list flows, integrate photo presentation, and remove obsolete UIKit scene code.
3. Add deterministic UI-test fixtures and focused XCUI journeys, preserve useful unit/presenter coverage, and verify appearance.
4. Add reproducible GitHub UI checks and artifacts; update architecture/review guidance.
5. Address independent review/test findings in focused commits and validate the final PR head.

Each commit should describe one coherent change. Keep the app runnable at the meaningful integration checkpoints.

## Acceptance journeys

| Journey | Observable result |
| --- | --- |
| Empty state → add person | Save a name/date, open the correct overview, relaunch and confirm persistence. |
| Edit → photo → crop → save | Select a deterministic photo for each image slot, crop, save, reopen and confirm the result. |
| Cancel and recover | Cancelling preserves saved data; failed saves show an error and restore usable controls. |
| Widget pinning and deep link | Enforce three pins and resolve a widget URL to the correct person. |
| Delete | Show the correct remaining/empty screen and keep the person deleted after relaunch. |

## Visual and CI acceptance

- Use XCUI to drive the actual application, with isolated data and fixed photo fixtures.
- Assert UI behavior and compare selected rendered screenshots to accepted image baselines. Attach expected, actual and difference images when comparisons fail.
- Prove that an intentional opaque replacement for the glass controls fails the visual comparison. A screenshot attachment alone is not an appearance assertion.
- Fix the simulator/runtime, Xcode, locale, appearance, content size and time used for image comparisons. Do not auto-accept baselines in CI.
- Cover EN/RU form/photo checkpoints and light/dark glass controls without multiplying every journey across every setting.
- Retain the required format, lint, secret and unit checks. Publish XCUI result bundles and visual evidence in GitHub Actions, including failed runs.
- Validate iOS 18 behavior and a modern glass-capable runtime. Verify available runner/runtime combinations before finalizing CI pins.
- Record real-device camera and dynamic-material limitations separately from simulator, still-image and functional evidence.

## Review and handoff

The orchestrator owns PR creation, pushes and agent coordination. The implementation worker makes focused commits; independent tester and reviewer report issues through the orchestrator for the worker to fix.

Keep the tracking PR draft and prevent automatic review-bot execution. Do not request bot reviews. Final delivery requires independent review, relevant local/UI verification, and green CI for the current head. Do not merge or enable auto-merge; Danis performs final review.
