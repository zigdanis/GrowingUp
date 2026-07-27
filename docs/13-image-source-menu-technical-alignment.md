# PR 13 Technical Design: Image Source Menu and Photo Preview Flow

This document records implemented image-capture architecture, scope, and acceptance behavior.

## Current Flow Map

- `ImagesTableViewCell.swift`
  - Owns the two image buttons: main/poster and widget.
  - Calls `ImagesCellViewDelegate.showAppPicImagePickerFor(row:)` or `showWidgetPicImagePickerFor(row:)`.
  - Also owns remove badges for each image slot.

- `EditPersonViewController.swift`
  - Implements `ImagesCellViewDelegate`.
  - Maps main/poster to rectangular crop and widget to circular crop.
  - Presents `ImageCaptureFlowView` in a `UIHostingController` page sheet.
  - Receives the final `UIImage`, wraps it in `PersonImage`, sends it to the presenter, and reloads the table.

- `ImageCaptureFlowView.swift`
  - Current root of image selection.
  - Starts at `PhotoGridView`.
  - Pushes camera through `NavigationStack` when the first grid tile is tapped.
  - Shows `CropStep` as a full-screen cover after a photo-library pick or camera capture.

- `PhotoGridView.swift`
  - Owns the current custom grid UI.
  - Always places `CameraTile` before photo assets.
  - Handles limited-library management with `LimitedLibraryPickerPresenter`.
  - Delegates photo loading to `PhotoGridViewModel`.

- `PhotoGridViewModel.swift`
  - Owns PhotoKit authorization, asset fetch, thumbnail loading, iCloud progress, cancel, and live refresh.
  - Fetches image assets sorted by creation date.
  - Loads full-resolution images for crop.

- `CameraSourceModel.swift`
  - Owns camera permission state and `CameraSessionController`.
  - Has injectable permission and hardware seams used by tests.

- `CameraCardView.swift`
  - Renders the live camera preview, shutter, flash, flip, and back/close controls.
  - Current close path returns to the photo grid, because camera is currently a grid destination.

- `CropStep.swift`
  - Owns crop UI and crop math.
  - Has local glass button styling for cancel/use.
  - The current glass style is not enough for the new ChatGPT-like controls and should not be copied blindly.

## Main Alignment Problem

The current architecture treats Photos as the entry point and Camera as a tile inside Photos. The new requirement treats Camera and Photos as sibling actions chosen from a source menu.

That means the flow should not be patched by hiding pieces in place. The root flow should be realigned around source selection:

- Source menu first.
- Camera preview and lightweight Photos preview as sibling destinations.
- Crop as the shared final step.
- System All Photos picker as a separate replacement for the lightweight preview.

## Recommended Shape

Use a single image-capture coordinator/root for the whole interaction. The coordinator owns the current stage and routes events between surfaces.

Suggested stages:

- `sourceMenu`
- `cameraPreview`
- `photoPreview`
- `systemPhotoPicker`
- `crop`
- `finished`
- `cancelled`

Suggested flow boundaries:

- UIKit host: still only knows image slot, crop shape, completion, and cancellation.
- SwiftUI image-capture coordinator: owns the source menu, preview screens, back behavior, All Photos handoff, and crop routing.
- Camera surface: only camera UI and camera permission/capture state.
- Lightweight photo surface: only preview grid, fixed holder sizing, Back, All Photos, and photo selection.
- System photo picker adapter: only native picker presentation and result conversion.
- Crop surface: remains the final crop step for all image sources.

## Existing Pieces To Refine

### `EditPersonViewController.swift`

Keep it as the UIKit boundary, but avoid growing it into a menu/picker coordinator.

Refine toward:

- Passing an explicit image slot and crop shape into a single image-capture flow.
- Receiving one completed image.
- Not owning source-menu UI details.

Potential cleanup:

- Replace row-based source methods with an image-slot concept when implementation starts.
- Keep presenter updates exactly where they belong: app image updates app slot; widget image updates widget slot.

### `ImagesTableViewCell.swift`

Keep it focused on displaying and removing image slots.

Potential cleanup:

- The cell should signal "image slot tapped" rather than "show image picker for row".
- The row is only needed because the current presenter storage is row-indexed. Do not let that leak into new capture UI more than necessary.

### `ImageCaptureFlowView.swift`

This file likely needs the largest rewrite.

Current responsibility is too broad and assumes Photos-first navigation. It should become, or be replaced by, a coordinator/root that:

- Starts with the source menu.
- Can enter Camera directly.
- Can enter lightweight Photos directly.
- Can recreate or reveal the source menu when Back is tapped from Camera/Photos.
- Can launch the system picker from All Photos.
- Can route any selected image into `CropStep`.

Remove this assumption from the root:

- Photos are always the first screen.
- Camera is always a tile inside Photos.
- Back from camera means "return to grid".

### `PhotoGridView.swift`

Split the current grid responsibilities.

Current `PhotoGridView` mixes:

- Photo preview grid.
- Camera navigation tile.
- Limited library banner.
- Full-resolution selection.
- Limited-library system picker bridge.

For the new alignment:

- The lightweight Photos preview should not know about Camera.
- The Camera tile should be removed from the photo-only preview path.
- Limited-library management can stay, but it should be evaluated against the new All Photos system picker path.

Possible direction:

- Keep a reusable `PhotoAssetGrid` or equivalent for rendering assets.
- Put the fixed holder, Back button, All Photos button, and Liquid Glass controls in a separate lightweight preview screen.
- Keep `PhotoGridViewModel` as the data source if its current PhotoKit behavior still fits.

### `PhotoGridViewModel.swift`

This is a useful seam and should not be discarded without reason.

Keep or refine:

- Authorization state mapping.
- Recent image fetch.
- Thumbnail loading.
- Full-resolution loading with iCloud progress.
- Change observation.

Inspect before implementation:

- Whether the lightweight preview should request `.readWrite` access or use a more limited/native picker path.
- Whether limited-library state should show an inline banner, defer to All Photos, or both.
- How cancellation should reset `isPreparingSelection` and progress when navigating back.

### `CameraCardView.swift`

The camera UI can mostly remain, but its navigation meaning changes.

Refine:

- Back should mean "return to source menu" when launched from the source menu.
- Capturing still routes to crop.
- Denied/restricted/unavailable states should still be handled through `PermissionExplainerView`.

Avoid:

- Camera depending on the photo grid as its parent.

### `CropStep.swift`

Keep crop behavior as a shared final step.

Refine only if needed:

- The local glass button styling should not define the new source-menu or photo-preview button system.
- If a stronger Liquid Glass style is created, decide whether crop buttons adopt it later or stay separate.

### `PermissionExplainerView.swift`

Keep this as a reusable permission surface.

Inspect:

- Whether camera and photo permission states appear inside the new modal structure cleanly.
- Whether Back from permission screens should return to source menu.

## Implemented Concepts

Implementation uses these concepts:

- Existing UIKit row and crop-shape mapping continues to distinguish app/main/poster and widget images.
- `ImageCaptureSelectionOrigin`: camera vs photo preview.
- `ImageCaptureStage`: source menu, camera preview, photo preview, and system picker.
- `ImageSourceMenuView`: ChatGPT-style two-option actions menu.
- `LightweightPhotoPreviewView`: fixed-size photo preview holder.
- `GlassControl`: shared Back and All Photos presentation.
- `SystemPhotoPicker`: full-screen `PHPickerViewController` adapter with cancel/failure routing.

## Native Photo Picker Investigation

Use Apple's PhotosUI/PhotoKit APIs where they satisfy the All Photos requirement. The implementation pass should compare:

- SwiftUI `PhotosPicker`.
- UIKit `PHPickerViewController`.
- Existing custom `PhotoGridViewModel` plus PhotoKit.

Decision criteria:

- Can it provide the system collections/filter/search experience the user expects?
- Can it return one image into the existing crop flow?
- Can it avoid unnecessary full-library permissions?
- Can it coexist with the lightweight preview grid?
- Can cancellation/back behavior be mapped cleanly to our source menu?

Reference starting points:

- Apple PhotosUI overview: https://developer.apple.com/documentation/photosui
- Apple `PhotosPicker` documentation: https://developer.apple.com/documentation/PhotosUI/PhotosPicker
- Apple WWDC "Meet the new Photos picker": https://developer.apple.com/videos/play/wwdc2020/10652/

## Completed Migration

1. Introduce a coordinator/root concept for image capture.
2. Move the source-choice state out of `PhotoGridView`.
3. Make Camera and Photos sibling paths.
4. Split the photo preview grid from camera navigation.
5. Add the fixed lightweight photo preview holder and controls.
6. Wire All Photos to the selected native picker API.
7. Preserve crop output and presenter updates.
8. Remove dead Photos-first assumptions and stale names.

## Test And Verification

Unit-level checks:

- Camera source state stays covered by existing `CameraSourceTests`.
- Event-driven tests cover Back from both sibling destinations, picker cancel/failure, and crop cancellation to each origin.
- Photo-grid disappearance invokes `cancelSelection()`, resetting and cancelling any active PhotoKit image request.

Manual checks:

- Tap main/poster image -> source menu.
- Tap widget image -> same menu, but final crop stays circular.
- Camera -> Back -> source menu returns.
- Photos -> Back -> source menu returns.
- Photos -> scroll -> modal does not expand.
- Photos -> All Photos -> native picker replaces lightweight preview.
- All Photos cancel path is acceptable and documented.
- Camera denied/restricted/unavailable states remain understandable.
- Photo denied/restricted/limited states remain understandable.
- Selected camera/photo/system-picker image reaches crop and then updates the correct image slot.

## Acceptance Standard

Acceptance requires source-menu-first navigation, correct Back/cancel restoration, localized controls, unchanged crop/save output, and no release-automation changes in feature diff.
