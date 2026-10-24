---
name: app-store-screenshots
description: Re-shoot, compose and upload the GrowingUp App Store screenshots (EN + RU) after a design change. Use when the UI changes and the store screenshots must be refreshed, or a new device family is added. Not for app preview videos.
---

# App Store screenshots

One real UI test captures the real app on a simulator, a renderer turns the captures into store cards per locale, and one uploader places them on the editable App Store version. Do not invent another route: no hand-made mocks, no extra tests, no injected dates.

## What gets shot (flexible)

The story follows the app's *current* design; nothing about the screens, people or cards is fixed. Rules that stay:

- **The main screens are in the set.** Whatever the app's primary screens are today (for the October 2026 redesign in `docs/design-proposals/2026-10-redesign/`: the mosaic home, a person's full-screen view, in-place edit, and the Home Screen widgets; plus the empty first launch or light theme if they sell the app), each gets a card. A screen that no longer exists gets no card; a new main screen must get one.
- **One test, rewritten per design.** `GrowingUpUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots` is the only capture test (EN and RU, dark by default). When the design changes, edit that test so it walks the new flow through the real UI (same style: real editor, native pickers, no injected dates or persistence) and takes one named `checkpoint(...)` per screen. Delete the steps for screens that are gone; do not add a second test.
- **Demo data serves the story, not the other way round.** Use a few people with the demo photos in `docs/app-store-demo-photos` (enough to fill the home screen well, a mix of children and pets, one birthday moment if the design still has one) and a fixed clock. The old set was Mia, Leo (midnight birthday confetti), Mango, Teddy and widget small/medium/large; keep it if it still fits, change it freely if not.
- **The renderer follows the test.** Checkpoint names are the contract: the test names them, `scripts/render-app-store-screenshots.py` (and `render-duo-app-store-screenshots.py`) lists them in `NAMES`, `COPY`, layouts and output `FILES`, and `families.json` lists the resulting files. Change all of them together, and update `scripts/tests` that expect four cards.
- **Copy is short, EN and RU, in the renderer.** Headlines come from the design's own wording; check RU fits.

## Steps

1. **Adapt the test to the current design.** List the main screens of the design and rewrite the capture test, renderer copy and layout for them (see above).
2. **Pick the sets from what App Store Connect requires, not from the deployment target.** Check Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) for the current rules, then shoot the smallest set that satisfies them plus a few optional ones, one simulator per set, never more:

   | Set (`--family`) | Apple status | Native size | Group |
   |---|---|---|---|
   | `dynamic-island`, medium (iPhone 16/17 Pro class) | required | 1206×2622 | `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE` |
   | `dynamic-island`, large (Pro Max class) | satisfies "Face ID large required unless Dynamic Island large is provided" | 1320×2868 | `IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE` |
   | `face-id`, notch (14 Plus class) | optional; only if its cards should differ from Dynamic Island | 1284×2778 | `IPHONE_FACE_ID_LARGE_PROFILE` |
   | `home-button` (SE 3 class) | optional | 750×1334 | `IPHONE_HOME_BUTTON_MEDIUM_PROFILE` |
   | `duo-outer` (iPhone Duo, outer display) | optional now, required from April 2027 for apps built with the iOS 27.1 SDK | 1398×2034 | `IPHONE_DUO_PROFILE` |

   Everything else (3.5", 4", Face ID medium, landscape) stays unshot; Apple scales or falls back. `marketing/app-store/screenshots/families.json` lists slugs, devices and sizes.

   **Simulators: use existing ones, never create new.** Run `xcrun simctl list devices available` and take any device with the same native pixel size as the set (an iPhone 16 Pro and a 17 Pro both give 1206×2622). If no existing simulator has the size, stop and tell Danis which size is missing; do not create one. Boot one at a time, shut it down after.
   **Xcode: the newest installed one, with its newest simulator runtime.** Never pin or fall back to an older major version; the runner records the active Xcode and the simulator's runtime itself.
3. **Before every capture, check that the Mac is idle** and that no other thread's simulator or Xcode build is running; if it is busy, stop and tell Danis who is using it instead of capturing through the slowdown or killing their work. Then boot the one simulator and set a clean status bar (9:41, full battery and signal).
4. **Capture one family at a time with `scripts/run-local-app-store-screenshots.py`** (see its `--help`; EN and RU run in one command; logs and evidence go outside the repo). It detects Xcode and runtime itself. Confirm both locales passed with no failed tests, and never delete a passing capture before its replacement exists.
5. **iPhone Duo: shoot the outer display only**, with the Duo folded (fold with agent-device's fold helper, then reapply the status bar). Apple accepts the inner display too, but we don't ship it.
6. **Compose the cards** with `scripts/render-app-store-screenshots.py` (standard families) or `scripts/render-duo-app-store-screenshots.py` (Duo), into an empty folder under `marketing/app-store/screenshots/families/`. Change the design in the renderer (copy, layout, backgrounds), not in the app.
7. **Look at every PNG.** Open all cards one by one: correct locale, no clipped text (RU headlines are longer), no cut-off device frame or widgets, any animation shown (e.g. confetti) is real, nothing from another app, correct pixel size, no alpha channel. Fix problems in the renderer or touch up the PNG directly, whichever is quicker; if you edit a PNG, update its hash in `source.json`.
8. **Update the manifest and build the review page** in `docs/` (like `docs/app-store-hardware-preview.html`): every uploaded screenshot, grouped by device and locale, in one file that is quick to browse. Don't wait for Danis.
9. **Upload the groups you re-shot** with `scripts/app-store-families.py` (see `--help`), without waiting for approval. Never print or commit the App Store Connect key, never submit for App Review, and commit the receipt. Then open the review page from step 8 for Danis (it shows exactly what was uploaded, per device and locale), so he can check it without opening App Store Connect.
10. **Deliver.** Commit tooling, manifest, assets, retained native captures and receipt; open the PR through `full-send`. Shut down and delete any simulator you created, remove temp keys and DerivedData.

## Rules that save time

- Never run extra "probe" tests, diagnostics or re-captures to check consistency. If a capture passed and no input changed, use it.
- Do not change app code to make a screenshot work; if the app looks wrong on a device, report it.
- One simulator at a time; do not touch simulators you did not start.
- No full-screen or browser screenshots while working; they can expose unrelated content.
- Do not submit for App Review and do not edit other store metadata or delete other devices' screenshots.
