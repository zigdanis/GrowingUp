#!/bin/bash

set -euo pipefail

# Requires authenticated gh, jq, python3 and an existing PR.
: "${1:?Usage: scripts/pr-evidence.sh PR_NUMBER}"
REPO=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
PR=$(gh api "repos/$REPO/pulls/$1")
NUMBER=$(jq -r .number <<< "$PR")
HEAD_SHA=$(jq -r .head.sha <<< "$PR")
RUN=$(gh run list --repo "$REPO" --workflow ci.yml \
  --commit "$HEAD_SHA" --limit 1 --json databaseId,url | jq -c '.[0] // empty')
test -n "$RUN" || { echo "No PR CI run for $HEAD_SHA yet; retry after GitHub starts CI." >&2; exit 1; }
RUN_ID=$(jq -r .databaseId <<< "$RUN")
echo "PR #$NUMBER at $HEAD_SHA: $(jq -r .url <<< "$RUN")"

CI_STATUS=0
RUN_STATE=$(gh api "repos/$REPO/actions/runs/$RUN_ID")
test "$(jq -r .status <<< "$RUN_STATE")" = completed \
  || { echo 'CI is still running; return after its completion notification to inspect exported evidence.' >&2; exit 2; }
test "$(jq -r .conclusion <<< "$RUN_STATE")" = success || CI_STATUS=1
CURRENT_HEAD=$(gh api "repos/$REPO/pulls/$NUMBER" --jq .head.sha)
test "$CURRENT_HEAD" = "$HEAD_SHA" || { echo 'PR head changed; rerun for the new commit.' >&2; exit 1; }
RUN_ATTEMPT=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq .run_attempt)

EVIDENCE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/growingup-pr-$NUMBER.XXXXXX")
trap 'python3 -c "import shutil, sys; shutil.rmtree(sys.argv[1])" "$EVIDENCE_DIR"' EXIT
echo "Downloading evidence to $EVIDENCE_DIR"
gh run download "$RUN_ID" --repo "$REPO" --pattern "ui-*-attempt-$RUN_ATTEMPT" --dir "$EVIDENCE_DIR"
for DIRECTORY in "$EVIDENCE_DIR"/ui-*; do
  jq -e --arg sha "$HEAD_SHA" --arg run "$RUN_ID" --arg attempt "$RUN_ATTEMPT" \
    '.head_sha == $sha and .run_id == $run and .run_attempt == $attempt' "$DIRECTORY/metadata.json" > /dev/null
  echo "Report: $DIRECTORY/index.html"
done

CURRENT_HEAD=$(gh api "repos/$REPO/pulls/$NUMBER" --jq .head.sha)
test "$CURRENT_HEAD" = "$HEAD_SHA" || { echo 'PR head changed during download; rerun for the new commit.' >&2; exit 1; }
CURRENT_ATTEMPT=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq .run_attempt)
test "$CURRENT_ATTEMPT" = "$RUN_ATTEMPT" || { echo 'CI attempt changed during download; rerun for the new attempt.' >&2; exit 1; }
trap - EXIT
echo "Inspect attachments/*.png, attachments/manifest.json and test-summary.json."
echo "Video is opt-in for motion review; inspect journeys.mp4 only when it was requested."
echo "Remove $EVIDENCE_DIR after review. CI exit status: $CI_STATUS"
exit "$CI_STATUS"
