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
- **Demo data serves the story, not the other way round.** Use a few people with the demo photos in `docs/app-store-demo-photos` (enough to fill the home screen well, a mix of children and pets, one birthday moment if the design still has one) and a fixed clock. The current set uses Mia, Leo's birthday fireworks, Mango, Teddy and widget small/medium/large; change it when the story needs it.
- **The renderer follows the test.** Checkpoint names are the contract: the test names them, `scripts/render-app-store-screenshots.py` (and `render-duo-app-store-screenshots.py`) lists them in `NAMES`, `COPY`, layouts and output `FILES`, and `families.json` lists the resulting files. Change all of them together, including the uploader's `FILES` and `scripts/tests`. Current six cards: `mosaic`, `mia`, Leo's fireworks (`leo-fireworks-<ms>`, selected with `--fireworks`), `editor`, `mango`+`teddy`, and `widget-*`. The test captures fireworks candidates at 1500–2500 ms after the return swipe and attaches timing JSON. Inspect the candidates and choose the widely spread burst; retain the selected native frame as `leo-fireworks-<ms>.png` with its timing evidence.
- **Copy is short, EN and RU, in the renderer.** Headlines come from the design's own wording; check RU fits.

## Steps

1. **Adapt the test to the current design.** List the main screens of the design and rewrite the capture test, renderer copy and layout for them (see above).
2. **Pick the sets from what App Store Connect requires, not from the deployment target.** Check Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) for the current rules, then shoot the smallest set that satisfies them plus a few optional ones, one simulator per set, never more:

   | Set (`--family`) | Apple status | Native size | Group |
   |---|---|---|---|
   | `dynamic-island`, medium (iPhone 16/17 Pro class) | required | 1206×2622 | `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE` |
   | `face-id`, notch (14 Plus class) | required when Dynamic Island large is omitted | 1284×2778 | `IPHONE_FACE_ID_LARGE_PROFILE` |
   | `home-button` (SE 3 class) | optional | 750×1334 | `IPHONE_HOME_BUTTON_MEDIUM_PROFILE` |
   | `duo-outer` (iPhone Duo, outer display) | optional now, required from April 2027 for apps built with the iOS 27.1 SDK | 1398×2034 | `IPHONE_DUO_PROFILE` |

   Danis's selected sets are Dynamic Island **medium only**, Face ID large, Home Button medium and Duo outer. Do not maintain a second Dynamic Island large set. Everything else (3.5", 4", Face ID medium, landscape) stays unshot; Apple scales or falls back. `marketing/app-store/screenshots/families.json` lists slugs, devices and sizes.

   **Simulators: maintain the shared MacPro App Store pool.** Keep one persistent simulator per selected set: iPhone 17 Pro, iPhone 14 Plus, iPhone SE (3rd generation), and iPhone Duo. Reuse this pool for other projects' testing too. Read `~/myai/fleet/services/app-store-simulators/README.md`, then discover the current devices before capture. Reuse a matching native model/size; if one is missing, create it on the newest installed compatible runtime and retain it for future use. Do not create per-thread or per-project duplicates. Shut down a task-owned boot when finished; do not delete or erase the simulator or uninstall its runtime during cleanup.
   **Xcode: use the newest installed Xcode and the newest runtime compatible with each model.** Prefer the latest iOS, but inspect runtime support instead of assuming every model works on it. On 2026-10-28, installed iOS 27.1 supports only Duo; the other three pool devices, including SE 3, support 27.0. Do not add an iOS 18 compatibility-test pass for screenshot work. The runner records the actual Xcode and runtime.
3. **Before every capture, check that the Mac is idle** and that no other thread's simulator or Xcode build is running; if it is busy, stop and tell Danis who is using it instead of capturing through the slowdown or killing their work. Then boot the one simulator and set a clean status bar (9:41, full battery and signal).
4. **Capture one family at a time with `scripts/run-local-app-store-screenshots.py`** (see its `--help`; EN and RU run in one command; logs and evidence go outside the repo). It detects Xcode and runtime itself. Confirm both locales passed with no failed tests, and never delete a passing capture before its replacement exists.
5. **iPhone Duo: shoot the outer display only**, with the Duo folded (fold with agent-device's fold helper, then reapply the status bar). Apple accepts the inner display too, but we don't ship it.
6. **Compose the cards** with `scripts/render-app-store-screenshots.py` (standard families) or `scripts/render-duo-app-store-screenshots.py` (Duo), into an empty folder under `marketing/app-store/screenshots/families/`. Change the design in the renderer (copy, layout, backgrounds), not in the app.
7. **Look at every PNG.** Open all cards one by one: correct locale, no clipped text (RU headlines are longer), no cut-off device frame or widgets, any animation shown (e.g. confetti) is real, nothing from another app, correct pixel size, no alpha channel. Fix problems in the renderer or touch up the PNG directly, whichever is quicker; if you edit a PNG, update its hash in `source.json`.
8. **Update the manifest and build the review page** in `docs/` (like `docs/app-store-hardware-preview.html`): every uploaded screenshot, grouped by device and locale, in one file that is quick to browse. Don't wait for Danis.
9. **Upload the groups you re-shot** with `scripts/app-store-families.py` (see `--help`), without waiting for approval. Never print or commit the App Store Connect key, never submit for App Review, and commit the receipt. Then open the review page from step 8 for Danis (it shows exactly what was uploaded, per device and locale), so he can check it without opening App Store Connect.
10. **Deliver.** Commit tooling, manifest, assets, retained native captures and receipt; open the PR through `full-send`. Close task-owned Device panel connections and shut down task-owned simulator boots. Keep the shared pool installed, including devices created to fill a missing capture set. Remove temp keys and DerivedData.

## Rules that save time

- Never run extra "probe" tests, diagnostics or re-captures to check consistency. If a capture passed and no input changed, use it.
- Do not change app code to make a screenshot work; if the app looks wrong on a device, report it.
- One simulator at a time; do not touch simulators you did not start.
- No full-screen or browser screenshots while working; they can expose unrelated content.
- Do not submit for App Review and do not edit other store metadata or delete other devices' screenshots.
