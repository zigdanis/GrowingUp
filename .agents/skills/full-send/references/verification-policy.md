# Efficient verification, failures and waiting

## Batch before CI

- **Prepare:** collect known fixes and review findings, fetch the latest base branch, integrate it and run relevant local checks before pushing. Recheck the remote base immediately before the push so CI validates the combined result.
- **Reuse:** use the automatic run from that push. Do not start duplicate runs or rerun successful checks for an unchanged commit.
- **Repeat only when needed:** meaningful changes, base synchronization or a diagnosed failure can require another run. Within an authorized delivery, proceed without asking for separate permission for each necessary run; respect any explicit user budget.
- **Track:** keep run links, results and time spent with the task, including retries and cancellations. Prefer fast local checks and avoid unnecessary expensive jobs; cancel superseded runs when they no longer provide useful evidence.
- **Diagnose:** if the same failure repeats, investigate before another attempt. Stop retrying blindly; explain the blocker and ask for input when no concrete correction is available or continuing would materially expand cost or scope.

## Classify before correcting

- **App bug:** the app behaves or looks wrong.
- **Test bug:** the test does not match expected behavior.
- **CI/OS problem:** CI, the simulator or an OS service failed.
- **Missing evidence / pending review:** required media or review is not ready.

## Waiting

- **Apple:** processing and beta review are normal waiting states.
- **Blocked:** say what is done, what is pending and what can unblock the task. Ask the developer if progress stalls or automatic follow-up is unavailable.
