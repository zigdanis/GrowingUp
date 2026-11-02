# Native App Store screenshots — 2026-10-28

Captured on MacPro with Xcode 27.1. Production app source matches master `217843fc9ce0ff5f0590afcdd7560460c52201c3` (PR105 merged); no app code changed for capture.

| Screenshot set | Persistent simulator | Runtime | Native PNG size | Final placements |
|---|---|---|---|---|
| Dynamic Island medium | iPhone 17 Pro | iOS 27.0 | 1206 × 2622 | 6 EN + 6 RU |
| Face ID large | iPhone 14 Plus | iOS 27.0 | 1284 × 2778 | 6 EN + 6 RU |
| Home Button medium | iPhone SE (3rd generation) | iOS 27.0 | 750 × 1334 | 6 EN + 6 RU |
| Duo outer, folded | iPhone Duo | iOS 27.1 | 1398 × 2034 | 6 EN + 6 RU |

Apple requires Dynamic Island medium. When Dynamic Island large is omitted, Face ID large is also required. Home Button medium and Duo outer are the additional sets requested by Danis. [Apple screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

The installed iOS 27.1 runtime supports only Duo. All three other models, including SE 3, use their newest compatible installed runtime, iOS 27.0. No iOS 18 tests or captures were run. The four simulators remain installed and are the shared pool for all projects. The screenshot skill and Fleet instructions now allow creating a missing required pool device and keeping it.

Each locale has six cards: mosaic, child age, birthday fireworks, in-place editor, pets and Home Screen widgets. Every native app screen came from its corresponding simulator through the real UI. The widget card arranges genuine production widget element captures on an illustrative Home Screen. All 48 final PNGs were visually inspected; all are RGB at the family's native output size.

The capture navigates to production celebration number 3 (fireworks), captures six candidates 1.5–2.5 seconds after the return swipe, and records actual timing. The selected frame is 1700 ms in both locales for all four families, showing separate, widely spread bursts. Retained native frames and timing JSON accompany the card hashes.

Eight localized capture runs passed. Duo Russian initially failed because the photo picker did not open; one focused Russian-only retry using the identical compiled app passed. Passing English evidence was preserved. MacPro had spare CPU capacity at the failure, so there was no evidence of resource pressure. The first Dynamic Island Russian run passed but Xcode stalled collecting diagnostics; its completed passing result was exported without recapture. The runner now disables diagnostic collection.

App Store Connect draft **2.2.2** (`411ee0b0-bd37-4c01-95f3-1e231c972ec9`) has 48 ordered, explicit ACTIVE screenshots: six per set per locale. All six preview placements were removed. No redundant Dynamic Island large screenshots remain: four English placements were already absent at cleanup preflight; cleanup removed the four remaining Russian placements. Underlying library assets, archived repository media, and unrelated creative placements were preserved. No App Review submission, TestFlight build or version creation was performed.

Apple processing exceeded the original five-minute deadline on newly uploaded images. The timeout is now ten minutes; resumed uploads reused existing asset IDs. Apple HTTP 500 responses interrupted Home Button finalization after its replacements were ACTIVE; fresh read-back confirmed the draft and existing placements before resuming removal of the old cards. The interrupted receipt is retained.

- [Browse all current EN/RU cards](app-store-hardware-preview.html).
- [Current manifest](../marketing/app-store/screenshots/families.json).
- [Combined upload receipt](../marketing/app-store/screenshots/apple-upload-receipt-20261028.json).
- [Preview removal receipt](../marketing/app-store/screenshots/apple-preview-removal-receipt-20261028.json).
- [Redundant set removal and final read-back](../marketing/app-store/screenshots/apple-cleanup-receipt-20261028.json).
- [Fresh Apple inventory](../marketing/app-store/screenshots/apple-verified-inventory-20261028.json).

Rebuild instructions are in `.agents/skills/app-store-screenshots/SKILL.md`. Retained inputs and passing summaries live under `marketing/app-store/native-captures/*-20261028/`; final PNGs and source hashes live under `marketing/app-store/screenshots/families/*-20261028/`. Previous undated assets and receipts are historical, not the current manifest.

Local verification: independent Codex review found no issues; 48 focused screenshot-tool tests passed, along with strict SwiftLint, swift-format and Swift parsing of the capture test. The full local script suite had 137 passes and one existing FFmpeg video-duration failure (0.0667 s difference), unrelated to screenshot changes; PR CI supplies the Linux result. No extra capture or iOS compatibility tests were added.

## 13-inch iPad — 2026-11-01

GrowingUp runs on iPad since PR #112, so App Store Connect needs the 13-inch iPad set (`IPAD_13_PROFILE`, 2064 × 2752 portrait); Apple scales it for 11-inch iPads. It was captured on MacPro with Xcode 27.1 on the pool's GU iPad Pro 13 (M5), iOS 27.0, from the same capture test through the real iPad UI: the date popovers, the Photos sheet and the circle crop. Both locales passed.

| Screenshot set | Persistent simulator | Runtime | Native PNG size | Placements |
|---|---|---|---|---|
| 13-inch iPad | GU iPad Pro 13 (M5) | iOS 27.0 | 2064 × 2752 | 6 EN + 6 RU uploaded to 3.1.0 |

The cards keep the iPhone story and copy, drawn by `scripts/render-ipad-app-store-screenshots.py`: whole iPad frames under the headline, and a Home Screen card with iPad's extra large widget above the large, medium and small ones ("Four sizes" instead of "Three sizes"). A full iPad screenshot takes 0.35–0.5 s (six frames overran the 4 s burst on the first try), so the capture shoots fireworks at 1500, 1900 and 2300 ms (measured 1.50, 1.91 and 2.31 s after the return swipe) and the cards use 1500 ms, the brightest burst. On iPad the fireworks are small against the large photo, because the celebration's particles keep their iPhone size; the app was not changed for the capture.

Uploaded on 2026-11-02 to draft 3.1.0 with `scripts/app-store-families.py --group IPAD_13_PROFILE --upload`: six EN and six RU placements ACTIVE, other groups preserved ([receipt](../marketing/app-store/screenshots/upload-receipts-20261102/ipad-13-upload.json)). The rating prompt and Russian strings had changed capture inputs since the capture without changing any captured screen, so the upload ran from #116's merge commit `9736b91`, where every capture input hash matches.

Retained inputs and passing summaries live under `marketing/app-store/native-captures/ipad-13-20261101/`; the cards and source hashes under `marketing/app-store/screenshots/families/ipad-13-20261101/`.
