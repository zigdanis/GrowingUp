# App Store rating prompt

The app asks for a rating only through the system sheet (`requestReview`). App Review Guideline 5.6.1
forbids custom review prompts, and asking "Do you like the app?" first to send only happy users to the
App Store is review filtering, so there is no pre-prompt and no "5 stars" wording anywhere. The odds of a
good rating come from the moment instead.

## When the app asks

GrowingUp is used by looking: people are added once, then visited in the viewer, from the mosaic or a widget.
So the moment is the end of a visit: the user closes the viewer, after it showed someone for at least
**3 seconds**, and is back on the mosaic. All of these must hold then:

- the app has been in the foreground on at least **3 distinct calendar days**, the first of them at least
  **7 days** ago (day 1 is the first launch of a build with this feature, also for people who installed earlier);
- the viewer has been visited this way at least **5 times**;
- at least **2 people** are stored, at least one of them with a photo;
- no alert was shown (a failure, or a warning such as a missing name, on the mosaic or in edit mode) and nobody
  was removed since the app last came to the foreground;
- no request was made yet this session or for this app version;
- after an earlier request: at least **120 days** have passed, fewer than 3 requests were made in the last
  365 days, and the app has been used on **3 new days** since.

Only time in the foreground counts toward the 3 seconds. The request comes **2 seconds** after the viewer has
zoomed back into the mosaic. If meanwhile the app stops being active (Control Center, a notification, the app
switcher), the viewer or a new person's page is open
again, the mosaic is being reordered, an alert shows, or the mosaic shows the
[Home Screen widget hint](widget-hint.md), the moment is skipped and a later visit can try again.

The request never lands on the viewer, so it never covers a birthday celebration, and since birthdays play no
part in the rules its timing says nothing about anyone's birthday.

The rules live in `ReviewPromptPolicy` (`GrowingUp/ReviewPrompt/`); `ReviewPrompter` keeps the session and
the state, stored in the app's own `UserDefaults` under `reviewPrompt`. The mosaic's and every edit mode's
alerts, and removals, tell it about setbacks.

## What iOS does with it

iOS shows the sheet at most three times in 365 days per device and decides on its own whether to show it.
It never appears in TestFlight builds and always appears in development builds. The app can't tell whether the
sheet appeared or how the user rated; `review_prompt_requested` in [analytics](analytics.md) counts the
requests, and App Store Connect shows the ratings per version.

## Checking it

Verification launches (`GROWINGUP_` variables, unit tests) never ask, except
`GROWINGUP_REVIEW_PROMPT=force`: it skips the days, counts and limits and stores nothing at all, so in a development
build (run from Xcode or installed on a Simulator) closing the viewer after 3 seconds shows the sheet. Alerts,
removals and the checks after the pause still apply.
