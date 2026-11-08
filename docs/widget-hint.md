# Home Screen widget hint

Many people never find out that GrowingUp has a Home Screen widget, and iOS has no API to add one for
them. So the app tells them once, quietly, and shows how: a glass strip at the end of the mosaic
("On your Home Screen too"), and a "GrowingUp widgets" sheet that acts out the steps. The design and
its rounds are in [design-proposals/2026-11-lock-screen-widget-hint](design-proposals/2026-11-lock-screen-widget-hint/README.md).
The hint is about the Home Screen and Today View widgets only; the Lock Screen widget gets no hint.

## When the strip shows

All of these must hold:

- at least **one person has "Widget" on**, so the widget would show someone (the strip's little Home
  Screen draws the real widget with those people);
- the app has been in the foreground on at least **2 distinct calendar days** and the viewer has been
  **visited at least once** (shown someone for 3 seconds), so it is not part of the first look around.
  Both counts are the rating prompt's (`ReviewPromptState`, see [rating prompt](rating-prompt.md)), kept
  since the first launch of the build that added it;
- **no GrowingUp Home Screen widget is installed**: `WidgetCenter.getCurrentConfigurations` lists no widget
  of kind `pro.ziganshin.GrowingUp.Widget` in any system size. Today View widgets report the same kind and
  sizes, so they count too. The app asks every time it comes to the foreground; a failed lookup hides the
  strip, and a found widget ends the hint for good;
- no alert was shown and nobody was removed since the app last came to the foreground;
- nobody whose birthday the app celebrates has it today: that day belongs to them;
- no rating request in the last **24 hours**.

The strip is hidden while the mosaic is reordered. It keeps its place meanwhile, so no tile moves as
a long press lifts one.

## When it ends

For good, after any of:

- a tap on the strip (it opens the "GrowingUp widgets" sheet);
- ×, which fades it out;
- a GrowingUp Home Screen or Today View widget found on a later foreground;
- **10 launches** it was shown on without a tap. A launch is one stay in the foreground, from the app
  coming up until it goes to the background, and it counts only when the strip took its place in it.
  The strip leaves, unseen, when the app goes to the background; on the next launch it comes back only
  after that launch's widget lookup found no widget, as the people load or under the viewer.

The state lives in the app's own `UserDefaults` under `widgetHint` and survives updates. A value the app
can't read counts as ended, so a damaged value never brings the hint back.

## Never in the way

- **Never animated in.** The strip takes its place only while the mosaic is off screen: as the people
  first load (the widget lookup starts with the app, so its answer is usually in by then), or 0.6 s after
  the viewer opened over the mosaic, once its cover has grown over it. So it is already there whenever
  the mosaic shows, and the user never sees it arrive.
- **Never with the rating request.** While the strip has its place, the rating prompt does not ask
  (`takeReviewRequest`); a tap on the strip drops a request still waiting for its pause, so the rating sheet
  never lands on the guide; and the strip stays away for 24 hours after a request.
- **Never during a birthday celebration, an alert, or reordering**, as above.

## Where it sits

The strip is part of the scrolling content after the last tile (`MosaicGridLayout.withWidgetHint`):

- The hint counts as one more tile: the grid is laid out for the people plus one. If that leaves the slot
  after the last person in a row of its own people, the hint is a **tile-sized card** in that slot. One
  person on an iPhone thus stands beside the card instead of alone in the middle, and three fill their
  last row with it. On iPad, which fits a few people to the window, the card is sized and centred as a
  tile among tiles.
- If the people fill their last row (2, 4, 6… on a two-column iPhone), the hint is a **row as wide as the
  grid** after it, and the grid is exactly the one without the hint, so no tile changes size or place.

The card uses the shorter Russian subtitle «Виджет с фото и возрастом близких». At the largest text
sizes the card drops its picture and the row stacks its picture above the words. VoiceOver reads the
strip as one button ("On your Home Screen too, A widget with your people's photos and ages, See how")
with a separate "Close" action; it is not part of reordering, dragging or the tiles' VoiceOver actions.

## The "GrowingUp widgets" sheet

`.medium` and `.large` detents, opening at large; × and "Done" close it. A segmented control switches
between **Home Screen** and **Today View**. The picture on top is SwiftUI (no bitmaps of iOS) with
placeholder icons, and its widget is the app's real widget view (`AgeWidgetContentView`) with the user's
pinned people:

| Step | Home Screen | Today View |
|------|-------------|------------|
| 1 | Touch and hold an empty spot on your Home Screen | On your first Home Screen page, swipe right |
| 2 | Tap Edit, then Add Widget | Touch and hold an empty spot, tap Edit, then Add Widget |
| 3 | Find GrowingUp | Find GrowingUp |
| 4 | Pick a size and tap Add Widget | Pick a size and tap Add Widget |
| Result | The medium widget on the Home Screen | The large widget in the Today View |

"Edit", "Add Widget" and "Customize" are the system's own titles (in Russian «Изменить», «Добавить
виджет», «Настроить»), so the user finds the same buttons. The steps light up one after another every
3 s and the result follows step 4 (`WidgetGuidePlayback`); a tap on a step plays from there. With Reduce
Motion nothing moves: each step shows its own still picture when tapped.

## Why a custom store and not TipKit

TipKit (iOS 17+) has rules, parameters, events, `MaxDisplayCount` and invalidation, but these rules fit
it poorly:

- Days of use, viewer visits and the last rating request are already counted by the rating prompt.
  TipKit would need its own donations of the same events, and "distinct calendar days" is not something
  its event rules count.
- `MaxDisplayCount` counts appearances of a tip view, not launches, and the strip scrolls in and out of
  view many times per launch.
- The strip and its layout are custom, so TipKit's views would go unused; only its state would remain.
- TipKit keeps its state in a global datastore configured once per process, which unit tests can't
  isolate per test and Linux can't run; the policy here is a pure struct (`WidgetHintPolicy`) with plain
  tests, like `ReviewPromptPolicy`.

So the hint follows the rating prompt's pattern in `GrowingUp/WidgetHint/`: `WidgetHintPolicy` (the
rules), `WidgetHintState` and `WidgetHintStore` (what is remembered), and `WidgetHinter` (the session,
the widget lookup and analytics). The sheet and its pictures are in `GrowingUp/WidgetGuide/`.

## Analytics

`widget_hint_shown` once per launch the strip is shown on, `widget_hint_opened` on a tap and
`widget_hint_dismissed` on ×, each with `shown_launches` (1–10); see [analytics](analytics.md).

## Checking it

Verification launches (`GROWINGUP_` variables, unit tests) never show the hint, except
`GROWINGUP_WIDGET_HINT=force`: the strip shows as the people load, whatever the days, visits, launches,
installed widgets and rating requests, and nothing is stored, so screenshots can be taken on demand.
Someone must still be on the widget, and reordering, a birthday, a tap or × still hide it. It works in
a plain development launch and together with the UI-test seeds (the demo seeds pin people to the
widget).
