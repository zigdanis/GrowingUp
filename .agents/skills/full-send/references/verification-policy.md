# Checks, bot reviews and waiting

## What CI runs

- **Every PR:** Secret Patterns, Swift Format, SwiftLint and Build & Test (unit tests). These four are the required checks. They finish in about 12 minutes.
- **PRs that touch app or UI-test code:** UI Tests — Glass also runs, starting with the unit tests. It produces the PR screenshots. `scripts/ci-scope.py` decides when it runs.
- **Master pushes and manual runs only:** UI Tests — iOS 18. Manual only: App Store Screenshots. Neither gates a PR.
- **To run everything on a branch:** `gh workflow run ci.yml --ref BRANCH`.

## Merge gate

- The four required checks pass.
- Glass UI journeys pass if they ran. For a UI change, screenshots are published and inspected.
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
- **Limit:** three CI runs per PR. After that, or after the same failure twice, stop. Put the diagnosis in the PR status line and ask the developer.

## Waiting

- Wait for checks with `gh pr checks PR --watch --required` (run it in the background when the harness re-invokes on exit). It can return early right after a push, so confirm nothing is still `pending` before acting. T3 `watch_pull_request` hasn't reliably woken threads, so don't depend on it alone.
- Apple processing and beta review are normal waiting states.
- When blocked, say what's done, what's pending and what would unblock it.
