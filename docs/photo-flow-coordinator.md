# Photo flow coordinator

## Problem

Photo selection and crop dismissal are split between ImageCaptureCoordinator
and ImageCaptureFlowView. The coordinator describes the source stage, while the
view owns the selected image and both pending results. Understanding or testing
the flow therefore requires knowing presentation ordering outside the module.
A previous fix had to delay the parent's completion until the crop cover closed.

## Intended result

Deepen the existing main-actor coordinator so it owns photo flow state and result
handoff. The SwiftUI view renders that state and forwards selection, cancellation
and dismissal events. Camera, photo-library and crop views remain platform
adapters. Keep the existing app and widget photo behavior and appearance.

## Acceptance criteria

1. Selecting a camera or preview image opens cropping for that image and records
   the source to return to when cropping is cancelled.
2. A successful system picker selection first requests picker dismissal. Cropping
   starts only after the system picker reports dismissal, using the picked image.
   Cancelling or failing the picker returns to photo preview without cropping.
3. Completing a crop requests crop dismissal and retains its result. The parent
   receives that result only after crop dismissal, at most once. Repeated finish
   or dismissal events must not replace or redeliver the result.
4. Cancelling cropping returns to its camera or preview source without delivering
   an image. Dismissing and then selecting another image starts a fresh crop.
5. SwiftUI binding resets after successful picker/crop completion preserve the
   pending result. A binding reset without a result cancels the active selection.
6. ImageCaptureFlowView has no selected/pending image state or independent
   dismissal-ordering implementation. It retains cover bindings, framework
   callbacks, image downsizing, camera authorization and scene-phase handling.

## Interface and testing decisions

Use one existing seam: ImageCaptureCoordinator's scene state and event interface.
Tests supply real UIImage values and observe the crop presentation and returned
result, rather than private pending fields or mocked internal collaborators.
Replace the five stage-only coordinator tests with focused flow scenarios;
retain camera permission/flash tests and the existing XCUI journeys.

Work in vertical TDD slices: one failing scenario, its minimal implementation,
then the next scenario. On Linux, record RED and GREEN using this PR's macOS
Build & Test job. Compilation failures for newly required interface are RED
evidence, not evidence that the behavior has been exercised.

For the final head, require formatting, lint and unit checks plus both UI jobs.
Inspect exported photo/crop/persistence/cancel checkpoints and recording frames
using scripts/pr-evidence.sh; a green build alone does not verify dismissal.
Keep all downloaded evidence outside the repository and remove it after review.

## Scope

Preserve MVP + Clean Architecture, iOS 18 support, localization, current cover
detents, crop shapes/downsize limits and photo fixture injection. Do not change
Core use cases, persistence transactions, App Group storage, pinning or widget
timelines. No new presentation framework, protocols or dependencies are needed.

Review against the starting master commit 39d5d4e178d6f118a755fd663bb06b1f18a458be
and this specification. Resolve actionable review findings, then follow the
[AGENTS.md merge policy](../AGENTS.md#merge-and-approval-policy) and
[growingup-delivery workflow](../.agents/skills/growingup-delivery/SKILL.md).
