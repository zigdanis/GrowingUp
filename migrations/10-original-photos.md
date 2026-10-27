# Migration: original photos and source-relative crops (`GrowingUpOriginalPhotos` model)

## What changed

- New Core Data model version `GrowingUpOriginalPhotos.xcdatamodel`, now the current version of
  `GrowingUp.xcdatamodeld`. It is a copy of `GrowingUpDisplayOrder` with three new optional `String`
  attributes on `CoreDataPerson`:
  - `originalPicId` — the photo as it was picked, which both pictures are framed from;
  - `appPicCrop`, `widgetPicCrop` — the region of that original each picture shows, as
    `PhotoCrop.storedValue`: four comma-separated unit coordinates that read back exactly.
- The original is the uncropped working image (`WorkingImage`, upright, at most 4096 px on its long
  side), written once as HEIC at quality 0.9 (lossless PNG where HEIC is unavailable) under the
  same App Group directory as the pictures. The pictures the app and the widget show stay PNG and
  are always rendered from the original, never from another picture.
- `CachePersonsGateway` stores the original beside the pictures, rolls all three back together on a
  failed save, and deletes a file only when no role refers to it any more.

## Why lightweight migration is enough

Adding optional attributes is an inferable change, so no mapping model is needed. Existing people
get `nil` for all three: no original and unknown regions.

## Photos picked before this version

Their discarded pixels cannot be recovered. Such a person keeps their pictures as they are. The
editor frames the stored main picture as its own original, shown whole; the first time either picture
is framed again, that main picture becomes the stored original (`originalPicId` = the old
`appPicId`) and stays on disk, so later edits never crop a crop again. A widget picture framed before
this version has no known region, so its circle crop opens centred, as before.

## How to verify

- Unit tests: `CoreDataPersonsGatewayTests.test_OriginalPhotosUpgradePreservesPeople` migrates a
  `GrowingUpDisplayOrder` store; `test_OriginalAndRegionsRoundTrip` stores and clears the new fields;
  `PersonPhotoFramingTests` runs pick → tight crop → save → reopen → zoom out → save → relaunch
  through the real gateways, including a pre-existing photo and Cancel.
- Upgraded install: with people saved by the previous build, install this build over it. Pictures,
  widgets and the mosaic are unchanged. Reframe a person's photo, relaunch, and reopen the editor: it
  opens on the new framing and can move back over the whole earlier picture.
