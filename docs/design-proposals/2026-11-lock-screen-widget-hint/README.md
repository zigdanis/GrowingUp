# Lock Screen widget hint, November 2026

Mockups only, no app code yet. Open [index.html](index.html) in a browser; the demo photos are embedded, so the page works on its own.

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

Shown only when at least one person has "Widget" on, from the second day of use, never when a GrowingUp Lock Screen widget is already installed (`WidgetCenter.getCurrentConfigurations`), never together with the rating prompt, an alert, reordering or a birthday celebration, and never again after a tap or ×. Open question: whether one person is enough (Astra) or two are needed (Fable).

## Next step

Danis picks a variant; the implementation then lands in this PR.
