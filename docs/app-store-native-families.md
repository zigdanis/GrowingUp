# Native App Store screenshots — captured 2026-10-13, verified 2026-10-14

Captured locally on MacBook Pro M2 Pro (Mac14,9), Xcode 26.6 / iOS 26.5 (23F77). App source commit: `0d60b645b4bf42d98f5c294079b9e59c10a730ca`.

| Apple group | Native simulator | Native PNG size | Own placements |
| --- | --- | --- | --- |
| Dynamic Island medium — required | iPhone 17 Pro | 1206×2622 | 4 EN + 4 RU, ACTIVE |
| Dynamic Island large | iPhone 17 Pro Max, approved capture reused | 1320×2868 | 4 EN + 4 RU, ACTIVE |
| Face ID large | iPhone 14 Plus | 1284×2778 | 4 EN + 4 RU, ACTIVE |
| Home Button medium | iPhone SE 3 | 750×1334 | 4 EN + 4 RU, ACTIVE |

Danis canceled the Home Button large requirement and authorized SE 3 on iOS 26.5. SE has independent native UI captures and its rectangular LCD, physical Home button and distinct shorter composition. No legacy 8 Plus capture or simulated compatibility was used.

All 32 final cards were inspected: Mia age, Leo birthday confetti/popover, Mango + Teddy, production widget examples. The new sets use native UI from their corresponding devices. The widget card arranges actual production widget element captures in the approved illustrative layout. Native widget crops and hashes are retained; SE crops use scale 2, DI/Face ID scale 3, including up to two pixels of XCTest edge rounding. The renderer's SE addition did not change any of the 16 already uploaded DI medium / Face ID large PNG hashes. Approved DI large assets and their app/photo inputs remain valid.

Six focused screenshot-only UI tests passed (three devices × EN/RU); no videos captured in this task. Uploader checks: 31 tests passed, including included-image pagination/fallback and selected-group preservation. No new cloud CI, push, TestFlight or App Review submission. The handed-off budget remains at least 17 earlier CI attempts and 9 earlier capture runs; this continuation adds six focused local capture tests.

CLI upload/read-back: draft 2.1.0 `4dccceea-13f4-4f10-8153-d1106ec1731c` remains `PREPARE_FOR_SUBMISSION`. All four groups have four ordered, explicit ACTIVE placements per locale. Required DI medium therefore owns its screenshots. The first SE attempt stopped during read-only checks on an Apple API network failure, before transferring any new PNG. Danis authorized one additional CLI attempt. That attempt targeted only SE medium, transferred exactly eight new PNGs, preserved all 24 prior placement/image IDs, and deleted zero placements. Earlier, after explicit resume approval, an interrupted upload reused two already stored PNGs and sent the remaining 14; the original eight DI large assets were preserved.

Files:

- [Review all 32 EN/RU cards](app-store-hardware-preview.html).
- [Group manifest](../marketing/app-store/screenshots/families.json).
- [Fresh Apple CLI inventory](../marketing/app-store/screenshots/apple-verified-inventory.json).
- [Upload receipt](../marketing/app-store/screenshots/apple-upload-receipt.json).
- [Earlier SE network stop, zero PNG transfers](../marketing/app-store/screenshots/apple-se3-network-stop.json).
- New final PNGs and source receipts: `marketing/app-store/screenshots/families/{dynamic-island-medium,face-id-large,home-button-medium}/`.
- Retained native inputs, source metadata and passing summaries: `marketing/app-store/native-captures/{dynamic-island-medium,face-id-large,home-button-medium}/`.
- DerivedData, xcresult, capture logs and previous upload receipts: `~/Library/Logs/GrowingUpScreenshots-20261013/`.

Inheritance limitation: the official placements API exposes explicit placements and has no inherited/scaled-source field or query parameter. Actual fallback sources in smaller groups have not been confirmed. Browser and Computer Use were prohibited, so this report does not claim that every smaller group inherits only its matching hardware family. All four requested primary groups are independently populated. This is the only remaining verification limitation; there is no pending screenshot upload.

Apple references: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [iOS 26 compatible models](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/26/ios/26).

Screenshot simulator ownership (all Shutdown after captures):

- DI medium: `ED72CBAC-470D-460C-98C5-7D65236D2E22`.
- Face ID large: `1358FC89-2E2B-46AB-8C74-741A7E6B33AE`.
- SE 3: `8F1F3EB7-4247-41C9-85AD-9238318F69B0`.

At the SE handback, live `simctl` showed no booted devices and no `xcodebuild`. The video thread was notified before its next DI window. Its Pro Max `DD1B22DD-179E-41FE-813A-91AEAB2B522B` was not used or modified by this task. Screenshot caffeinate processes ended; the SE launchctl entry was removed. The additional bounded CLI-upload caffeinate PID 78622 was stopped when upload/read-back completed. Separate bound worktrees; no video/APP_PREVIEW changes in this task. No further screenshot simulator boots planned.
