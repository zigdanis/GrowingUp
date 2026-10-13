## Standing Rules

- On Linux, validate iOS changes through the PR's macOS CI and `scripts/pr-evidence.sh PR_NUMBER`. Inspect relevant exported screenshots and recording frames for the latest head, fix concrete failures on the same PR, and remove downloaded evidence after review.
- Keep PR media compact and readable; publish reviewed CI screenshots through `scripts/pr-visual-evidence.py` and inspect their display in the PR.
- For user-visible changes, attach inspected screenshots or a short feature demo to the PR description for the current head. For non-UI changes, report functional checks instead.

## Code Style

- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Declare only one type per Swift file; direct extensions of that file's primary type are the only exception.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
