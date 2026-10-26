# Mosaic scrolling and photo editing fixes

Delivery: an open PR with reviewed screenshots and merge recommendations; no merge or release.

## Reported behavior

- Vertical scrolling starts only at the far right edge or in empty space. A swipe starting on a person or pet photo must scroll normally.
- The Photo control in the editor looks uneven and sits differently from the other round controls.
- Cancel is larger than Done. Both actions should use the compact dimensions of Done.
- Opening Circle resets the photo instead of restoring the region shown by the saved circular thumbnail.
- After the first photo crop, the editor can only move/zoom the already cropped image. It must retain the original photo and allow recovering previously excluded areas when reframing later.

## Investigation and implementation

1. Reproduce mosaic scrolling on MBP through T3 Device Connect, including swipes starting in the center of photo tiles. Inspect `MosaicTileButton`'s long-press/zero-distance-drag sequence and scroll disabling. Fix gesture arbitration while retaining tap-to-open, deliberate hold-to-reorder, dropping, and subsequent scrolling.
2. Inspect the Photo menu's system styling and `EditModeControlLabel` geometry. Give all five circular controls equal bounds and center their glyphs; inspect Russian labels on iOS 27.
3. Align the Cancel and Done capsule heights and padding, including disabled Done and accessibility text sizes.
4. Trace the circular crop source, initial framing, and persistence. `frameWidgetPicture()` currently supplies only the main photo; `CropStep` starts at scale 1 and offset zero, and persisted images expose no crop transform. Preserve a source-relative crop through save/reopen/relaunch, define compatibility for existing photos, and avoid cumulative image degradation or resetting a separately framed circle when editing the main photo. Reuse existing storage and crop geometry where appropriate; choose the smallest durable implementation after checking the model.
5. Preserve the original photo at the first selection, before the initial crop. Persist independent main-photo and circular crop coordinates against that source; render display images from it without replacing the source with a crop. Reopening the main editor must restore its saved framing while allowing zooming out and panning into areas outside the previous crop. Keep this behavior after saving and relaunching, keep Cancel transactional, and handle source replacement/removal consistently. Older records without an original cannot recover discarded pixels; retain their existing image and make future edits non-destructive.

## Acceptance and evidence

- Swipe up/down from the centers of several people and pet tiles, both immediately and after a reorder; the viewport changes without opening a person or accidentally lifting a tile.
- Tap still opens a person, deliberate long press still reorders, and drop releases scrolling.
- Photo's circle and icon align with neighboring controls. Cancel and Done have equal compact heights in Russian and English.
- Frame an off-center subject for Circle, confirm, reopen, save the person, reopen the editor, and relaunch: the subject and zoom agree with the thumbnail. Check cancel, a replaced main photo, and legacy records.
- Pick a photo, crop it tightly, save, reopen the main editor, zoom out and move the frame to reveal previously excluded content. Save and relaunch; both main and circular crops still restore against the retained original, with no progressive loss after repeated edits.
- Add meaningful gesture/UI and crop/persistence regression coverage. Run Linux tooling/secrets checks and the PR's macOS unit/Glass UI checks within the repository's three-run CI budget.
- Inspect latest-head CI exports with `scripts/pr-evidence.sh`; publish 1–3 reviewed screenshots with `scripts/pr-visual-evidence.py` while the PR is open. Screenshots substantiate layout/crop; gesture assertions and interactive MBP checks substantiate scrolling.
- Opus 5.5 implements. Lead Codex reviews correctness; Fable independently reviews the requested fixes and visual behavior. Confirmed findings return to Opus, followed by fresh review. Record unresolved limits and merge recommendation in the PR.
