# PR 13: Image Source Menu and Photo Preview Flow

This PR implements the image-source chooser and routes Camera and Photos through sibling flows into the existing crop/save handoff.

## Goal

Define the work needed to replace the current direct image-pick entry with a ChatGPT-style source chooser and a better photo preview flow.

## Desired Experience

- Tapping the main/poster picture or widget picture opens a floating actions menu.
- The actions menu has exactly two options: Camera and Photos.
- The menu visually follows the ChatGPT attachment menu direction: rounded translucent panel, large rows, circular icon wells, and simple labels.
- The standard iOS action sheet should not be used for this interaction.
- Choosing Camera opens the camera preview flow.
- Choosing Photos opens a lightweight photo preview modal.
- The lightweight photo preview modal shows photo previews immediately and does not include a Camera tile as the first item.
- The lightweight photo preview modal has a back button and an All Photos button.
- Back from Camera or the lightweight Photos preview returns to the original Camera/Photos actions menu.
- All Photos replaces the lightweight preview with the system-provided photo picker/full photo control where possible.

## Workstreams

1. Source chooser

- Define a two-option source menu for image changes.
- Make it work for both main/poster and widget image slots.
- Keep the menu lightweight and dismissible by tapping outside.

2. Camera preview

- Make Camera launch directly from the source chooser.
- Preserve the existing camera capture behavior.
- Make Back return to the source chooser when no image was captured.

3. Lightweight Photos preview

- Make Photos launch a preview grid directly.
- Remove the embedded Camera navigation tile from this photo-only preview.
- Keep the modal footprint fixed while only the grid scrolls.
- Add Liquid Glass-style Back and All Photos controls with balanced sizing.

4. Full Photos screen

- Make All Photos transition from the lightweight preview into the system-provided photo picker/control screen where possible.
- Prefer native/system capabilities for collections, filtering, and search.
- Return the selected image into the existing crop flow.

5. Crop and save handoff

- Preserve the current crop behavior for main/poster and widget images.
- Preserve the existing presenter handoff: picked image updates the correct image slot, then the table reloads.

6. Polish and verification

- Verify compact and large phone layouts.
- Verify camera denied/restricted/unavailable states.
- Verify Photos full, limited, denied, and restricted states.
- Verify Back/Cancel paths never lose the user's place unexpectedly.

## Completed Behavior

- Both image slots open the same floating Camera/Photos source menu.
- Camera and lightweight Photos preview are sibling destinations; Back returns to the source menu.
- Photos preview omits the old Camera tile and keeps scrolling inside a fixed-height sheet.
- All Photos replaces the sheet with a full-screen `PHPickerViewController`; picker cancellation or load failure returns to the lightweight preview.
- Camera, preview-grid, and system-picker selections use the shared crop step. Cancelling crop returns to the originating camera or photo surface.
- Leaving the photo grid cancels any in-flight full-resolution PhotoKit request.
- New controls and accessibility labels are localized in English and Russian.

## Non-Goals

- Do not build a full custom Photos app replacement.
- Do not add Files, Plugins, image generation, or any other source option.
- Do not compromise by keeping the current Camera tile inside the Photos preview.
- Do not refactor release automation or unrelated app features.

## Implementation Decisions

- Source menu uses a bottom-positioned translucent card.
- Host sheet uses a fixed custom detent at 62% of available height; grid scrolls inside it.
- All Photos uses `PHPickerViewController`, configured for one image.
- Coordinator recreates source-menu state when Back is chosen.
