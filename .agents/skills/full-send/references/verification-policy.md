# Checks, bot reviews and waiting

## What CI runs

- **Every PR:** Secret Patterns, Release Tools, Swift Format, SwiftLint and Build & Test (unit tests). These five are the required checks. They finish in about 12 minutes, or about a minute when only docs, agent skills or tooling changed.
- **Duo UI journeys:** manual opt-in only, with `run_duo_ui_tests=true` on `workflow_dispatch`. Automatic PR and master runs never start them, including when app or UI-test files change. A manual run without the opt-in also skips them.
- **Captures:** App Store Screenshots remains manual. Run UI tests/captures only when the developer explicitly requests them; do not launch extra Duo journeys to satisfy ordinary PR delivery. iOS 18 is not tested in CI.
- **Evidence:** XCTest screenshots are the default. Enable `record_ui_video` for a manual CI run only when the change requires motion review. Routine checks must not depend on a video recorder starting or finalizing.
- **To request Duo UI tests:** `gh workflow run ci.yml --ref BRANCH -f run_duo_ui_tests=true`. Enable video separately only when needed.

## Merge gate

- The five required checks pass.
- Explicitly requested UI verification must pass and its screenshots must be inspected. Use reviewed native captures when they are the requested task's evidence. Routine PRs do not wait for Duo UI tests or CI screenshot publication.
- Bot findings classified as correctness issues are fixed. Everything else has a one-line reply.
- An out-of-date branch is fine (branch protection doesn't require it). Master CI checks the merged result, and a red master is fixed first.
- Unresolved bot threads no longer block merging, but each one still gets a reply.

## Bot reviews

- **One round:** CodeRabbit and the Codex connector review the PR once. Collect their comments and fix them in a single push.
- **Classify:** fix bugs, data loss, crashes and wrong user-visible behavior. For style, naming, speculative hardening and "consider" suggestions, reply once with the reason they're skipped. Don't change code for them.
- **Resolve:** reply, then resolve the thread. Comments on later pushes get the same treatment, but don't request new reviews.

## CI budget

- **Batch:** run local checks and integrate known fixes before pushing. Never rerun a green check for an unchanged commit.
- **Classify failures:** app bug, test bug, or CI/simulator problem. A timeout-shaped UI failure in a journey the PR didn't touch is usually the simulator. Rerun only that job once with `gh run rerun RUN_ID --failed`.
- **No blind retry loops:** after the same failure twice, change the diagnosis/implementation or reproduce it in isolation; do not launch another unchanged run. Concrete fixes and their required CI remain authorized within the task; a run count alone is not a reason to stop for permission. Record the failure classification and next action in the PR status line.

## Waiting

- Use the runtime's supported PR watch while the PR is open. Do not use sleep/poll loops or assume a PR watch follows merged-master or TestFlight runs.
- After a release-authorized merge, dispatch TestFlight immediately. Its Actions source-CI gate performs the durable wait without an agent turn or a macOS signing runner. The release CLI prints the live URL and saves the run identity; `progress RUN_ID` reads current jobs and the existing receipt.
- Apple processing and beta review are normal waiting states.
- When blocked, say what's done, what's pending and what would unblock it.
