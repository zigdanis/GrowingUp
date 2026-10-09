# App Store screenshots

The approved set has four dark frames: Mia, Leo's birthday celebration, Mango
with Teddy's phone behind, and three WidgetKit sizes. It uses original generated
photos from `docs/app-store-demo-photos` and Russian/English copy. The celebration
frame says “Happy birthday!” / “С днём рождения!” because the actual app only
plays its birthday confetti on the birthday itself.

The **App Store Screenshots** PR workflow uses an existing iPhone 17 Pro Max
simulator on iOS 26.5 with Xcode 26.6. Its opt-in XCUI journey enters names and
birthdays, selects and crops both photos, saves four pinned people, verifies
persistence, and records the native birthday popover and confetti. Widget crops
come from the extension's actual `AgeWidgetContentView` through the existing
DEBUG harness; the composed Home Screen background is marketing artwork, not a
claim of SpringBoard hosting. Normal UI journeys retain their existing fixtures.

Download the current-head `app-store-capture-attempt-N` Actions artifact outside
the repository. Inspect both languages, the actual animation recording, and all
eight images in `final/`. Copy only the reviewed final deliverables into
`marketing/app-store/screenshots`, including `source.json`. Final marketing PNGs
are intentionally versioned at Danis's request; raw captures, recordings,
xcresult and DerivedData stay outside the repository. The final images are opaque
1320 × 2868 PNGs. Smaller iPhone categories can use App Store Connect scaling;
the iPhone-only app does not need an iPad set.
Browse the committed final images in `docs/app-store-screenshots-preview.html`.

CI composes the images with `scripts/render-app-store-screenshots.py`, Pillow
12.3.0 and the licensed fonts in `marketing/fonts`. For a local recomposition:

```bash
python3 scripts/render-app-store-screenshots.py /tmp/CAPTURE --output /tmp/FINAL
```

The output directory must be empty. `source.json` records native input hashes,
final image hashes and the source commit/run/attempt. A later change to capture
inputs requires new simulator evidence and recomposition.

## Prepare the App Store draft

The **App Store Metadata** workflow runs manually from reviewed, green `master`
using the existing `testflight` environment's Apple API key. Its `inventory`
operation is read-only. Its `upload` operation creates or reuses the next minor
draft after the live App Store version, prepares EN/RU screenshot placements,
and verifies processing and ordering. Both new sets must pass verification before
old inherited or managed screenshots in other iPhone groups are removed, so
smaller iPhones use the new scaled set. Other draft artwork blocks the operation;
iPad placements, previews and library image assets are retained. It does not upload an app binary or submit
a release for App Review. These operations need Danis's instruction; the current
screenshot task explicitly authorizes preparing the draft and uploading images.

```bash
gh workflow run app-store-metadata.yml --ref master \
  -f operation=inventory -f source_sha=FULL_REVIEWED_MASTER_SHA -f version=next
gh workflow run app-store-metadata.yml --ref master \
  -f operation=upload -f source_sha=FULL_REVIEWED_MASTER_SHA -f version=2.1.0
```

`2.1.0` is valid when the live store version is `2.0.0`; existing TestFlight
versions do not set this draft's marketing version. An existing different next
App Store draft is reported rather than silently changed. Existing metadata in
EN/RU is retained. The uploader refuses to replace unrelated draft screenshots.
Use a merge commit for this PR so the recorded capture commit remains an
ancestor of the reviewed source. The workflow checks that no app, capture,
photo, compositor or font input changed after that capture.

Download and inspect the `app-store-metadata-RUN-ATTEMPT` receipt. Completion
means the draft is `PREPARE_FOR_SUBMISSION` and all eight screenshot placements
have the verified order and processed assets. Credentials stay in GitHub's
master-only environment; receipts contain no private keys or signed upload URLs.

API references: [App Asset Library](https://developer.apple.com/documentation/appstoreconnectapi/app-asset-library),
[image uploads](https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets),
[placements](https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces),
[screenshot dimensions](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
