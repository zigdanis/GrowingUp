# New PR Thoughts

Use this file as a scratchpad for changes to land in the next PR.

## Ideas

- When the user taps the main/poster picture or widget picture, show a ChatGPT-style floating menu before opening image capture.
- The menu should have only two options: Camera and Photos.
- It should visually feel like the ChatGPT attachment menu: rounded translucent panel, large rows, icon circles on the left, label text on the right.
- Do not use the standard iOS action sheet style for this.
- After choosing Photos, show the photo preview grid directly, like ChatGPT does, without putting Camera as the first grid item.
- The photo preview screen should include a back button and an All Photos button, matching the ChatGPT example.
- The back button and All Photos button should feel like the same control family: similar visual weight/height and a Liquid Glass effect.
- Current liquid-style buttons in the app are not glassy enough for this interaction; this screen needs a stronger translucent/blurred/glass treatment.
- Scrolling the first photo preview modal should not expand the modal or take more screen space.
- The photo holder/modal stays the same size; only the photo grid inside it scrolls.
- Tapping All Photos should dismiss/replace the lightweight photo preview modal with the full system photo picker/control screen.
- The full photo screen should use the system-provided interface where possible, rather than building it from scratch.
- The full photo screen should give access to user collections, filtering, and photo search.
- When the user taps Back from the camera preview or lightweight photo preview modal without selecting/capturing an image, return them to the original two-option actions menu.
- The system-provided full photo screen is excluded from this back-button behavior because it owns its own navigation UI.
- The two-option actions menu can either remain behind the preview modal or be recreated when the preview modal dismisses via Back.

## Motivation

- The user needs to choose the image source explicitly, but the choice should feel lightweight and modern.
- The current flow goes straight into image capture/photo selection, which hides the source choice.
- If the user already chose Photos from the menu, a Camera navigation tile inside the photo grid is redundant.

## Scope

- Applies to both main/poster picture changes and widget picture changes.
- Camera opens the existing camera capture flow.
- Photos opens the existing photo library flow.
- The Photos flow opens straight to photo previews/all photos.
- The Photos grid should not include the current first Camera tile.
- The photo preview screen includes a back control and an All Photos control.
- The two controls should be visually balanced in size and use the same Liquid Glass styling direction.
- The first photo preview modal has a fixed visible height/footprint while browsing.
- Scrolling is constrained to the photos inside the holder, not the holder itself.
- The All Photos button transitions from the lightweight preview modal to the full system photo picker/control screen.
- Prefer native/system photo controls for collections, filtering, and search instead of custom-building those features.
- Back from the camera preview returns to the Camera/Photos actions menu.
- Back from the lightweight photo preview returns to the Camera/Photos actions menu.
- Back from the system-provided full photo screen follows the system picker behavior and does not need to restore the actions menu unless the system flow fully cancels back to our UI.
- The menu should dismiss when the user taps outside it.

## Open Questions

- Should the menu be anchored near the tapped image button or appear near the bottom input area style like ChatGPT?
- Should the menu include any animation or blur/background dimming beyond the translucent panel?
- Should the Photos preview be a full sheet, a partial sheet, or an inline panel similar to ChatGPT's expanded attachment picker?
- Should the Liquid Glass buttons be implemented as a reusable shared component for this flow, or kept local until the visual direction is proven?
- What fixed height should the first photo preview modal use across compact and large phones?
- Which system photo picker API best supports the desired full-screen collections/filter/search experience while still returning one cropped image into the existing flow?
- Is it cleaner to keep the actions menu mounted behind camera/photos previews, or dismiss and recreate it when the user backs out?
