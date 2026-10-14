# CI limits, failures and waiting

## CI limits

- **Runs:** per task, at most one full CI run for the ready PR and one on merged code before TestFlight. The second run is for release, not PR debugging.
- **Count:** keep run links, results and time spent with the task. Include automatic runs, retries, cancellations and diagnostics; one suite counts once. New commits, PRs or threads do not reset the count.
- **Checks:** prefer fast local checks and reuse automatic CI. Avoid unnecessary expensive jobs.
- **Stop:** if a push or retry would exceed either limit, or the same failure repeats, ask the developer before continuing.

## Classify before correcting

- **App bug:** the app behaves or looks wrong.
- **Test bug:** the test does not match expected behavior.
- **CI/OS problem:** CI, the simulator or an OS service failed.
- **Missing evidence / pending review:** required media or review is not ready.

## Waiting

- **Apple:** processing and beta review are normal waiting states.
- **Blocked:** say what is done, what is pending and what can unblock the task. Ask the developer if progress stalls or automatic follow-up is unavailable.
