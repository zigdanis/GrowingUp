# Checks, bot reviews and waiting

## What CI runs

- **Every PR:** Secret Patterns, Release Tools, Swift Format, SwiftLint and Build & Test (unit tests) are the required checks. Only Build & Test needs a macOS runner; Swift Format and SwiftLint run on Linux with the same Swift 6.4 and SwiftLint versions as `scripts/check-formatting.sh` and `scripts/install-swiftlint.sh`. Release Tools runs on macOS only when release inputs change (fastlane, Gemfile, project, plists, entitlements, workflows) and is skipped otherwise, which still satisfies the check. Docs, skills, tooling and store-media changes skip the iOS checks and finish in about a minute.
- **Master pushes** run all five, including Release Tools, because TestFlight requires a green master CI.
- **Duo UI journeys:** manual opt-in only, with `run_duo_ui_tests=true` on `workflow_dispatch`. Automatic PR and master runs never start them, including when app or UI-test files change. A manual run without the opt-in also skips them.
- **Simulator App:** built only on request. `scripts/simulator-app.sh [PR_NUMBER]` reuses a build of that exact commit or dispatches one and waits.
- **App Store screenshots:** never on CI. They are captured on MacPro (`app-store-screenshots` skill) and committed; `app-store-metadata.yml` validates or places them. iOS 18 is not tested in CI.
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

- **Batch:** run local checks (AGENTS.md, CI and pushing) and integrate known fixes before pushing; one push per batch. Never rerun a green check for an unchanged commit.
- **Classify failures:** app bug, test bug, or CI/simulator problem. A timeout-shaped UI failure in a journey the PR didn't touch is usually the simulator. Rerun only that job once with `gh run rerun RUN_ID --failed`.
- **No blind retry loops:** after the same failure twice, change the diagnosis/implementation or reproduce it in isolation; do not launch another unchanged run. Concrete fixes and their required CI remain authorized within the task; a run count alone is not a reason to stop for permission. Record the failure classification and next action in the PR status line.

## Waiting

- Use the runtime's supported PR watch while the PR is open. Do not use sleep/poll loops or assume a PR watch follows merged-master or TestFlight runs.
- After a release-authorized merge, dispatch TestFlight immediately. Its Actions source-CI gate performs the durable wait without an agent turn or a macOS signing runner. The release CLI prints the live URL and saves the run identity; `progress RUN_ID` reads current jobs and the existing receipt.
- Apple processing and beta review are normal waiting states.
- When blocked, say what's done, what's pending and what would unblock it.
