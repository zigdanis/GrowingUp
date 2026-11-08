# Lock Screen widget hint, November 2026

Mockups only, no app code yet. Open [index.html](index.html) (round 2, current) in a browser; [round-1.html](round-1.html) holds the first four variants. Demo photos are embedded, so each page works on its own.

## Problem

Many people never find out that GrowingUp has a Lock Screen widget. iOS has no API to add one for them, so the app can only tell them once, quietly, and show how. Danis asked for something that does not jump into the middle of the screen.

## Variants

Fable and Astra (Codex) proposed concepts independently. Both rejected a pop-up over the mosaic or the viewer.

- **A · Strip at the end of the mosaic** (Fable's pick): a glass row after the last tile with a live preview of the Lock Screen widget for the first pinned person. Stays until tapped or dismissed.
- **B · Quiet line above "Add"** (Astra's pick): a neutral 60 pt glass line between the mosaic and the floating button, shown for one session.
- **C · Popover on the "Widget" switch**: a TipKit popover in edit mode. Good as a later, permanent second entry point.
- **D · Note after saving a person** (closest to the original idea): a small card rises above "Add" for 8 s after the 2nd or 3rd person is saved.

All four open the same "How to add" sheet: a SwiftUI Lock Screen illustration with the user's own person, three steps, and a note on which person the widget shows.

## Shared rules

Shown only when at least one person has "Widget" on, from the second day of use, never when a GrowingUp Home Screen or Today widget is already installed (`WidgetCenter.getCurrentConfigurations`), never together with the rating prompt, an alert, reordering or a birthday celebration, and never again after a tap or ×. One person with "Widget" on is enough.

## Round 2: Danis's decisions (8 November 2026)

- The hint is variant A, the strip under the mosaic with × and "How to add".
- It is about the large widgets on the Home Screen and in the Today View, not the Lock Screen.
- The "How to add" sheet has a Home Screen tab and a Today View tab: an illustration that acts out each step (long press, Edit → Add Widget, search GrowingUp, pick a size) and four numbered steps using the system's own button names.
- The Lock Screen widget keeps only the rectangular family, now with a round photo; the ring and the inline family go. That change ships in its own PR, without any hint or instructions.

## Status

Danis approved round 2 on 8 November 2026. The implementation lands in this PR; [docs/widget-hint.md](../../widget-hint.md) describes how it works.
