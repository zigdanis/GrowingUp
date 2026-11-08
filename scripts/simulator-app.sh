#!/bin/bash

set -euo pipefail

# Requires authenticated gh and jq. Prints the path of a Release simulator GrowingUp.app built by the Simulator App
# workflow for a PR head, or for the current master head without an argument. The workflow runs only on request:
# when no unexpired build of that exact commit exists, this script dispatches one (about 5 minutes) and waits for it.
REPO=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
if [ $# -gt 0 ]; then
  PR=$(gh api "repos/$REPO/pulls/$1")
  HEAD_SHA=$(jq -r .head.sha <<< "$PR")
  BRANCH=$(jq -r .head.ref <<< "$PR")
  test "$(jq -r .head.repo.full_name <<< "$PR")" = "$REPO" || {
    echo "PR #$1 comes from a fork; the Simulator App workflow can only build branches of $REPO" >&2
    exit 1
  }
  TARGET="PR #$1 at $HEAD_SHA"
else
  BRANCH=master
  HEAD_SHA=$(gh api "repos/$REPO/commits/master" --jq .sha)
  TARGET="master at $HEAD_SHA"
fi

runs() {
  gh run list --repo "$REPO" --workflow simulator-app.yml --commit "$HEAD_SHA" --limit 20 \
    --json databaseId,status "$@"
}

# Artifacts expire after 14 days while their runs stay successful, so take the newest run that still has one.
find_build() {
  local candidate artifact
  for candidate in $(runs --status success | jq -r '.[].databaseId'); do
    artifact=$(gh api "repos/$REPO/actions/runs/$candidate/artifacts" \
      --jq '[.artifacts[] | select(.name == "simulator-app" and (.expired | not))] | first | .id // empty')
    if [ -n "$artifact" ]; then
      echo "$candidate"
      return
    fi
  done
}

RUN_ID=$(find_build)
if [ -z "$RUN_ID" ]; then
  # Reuse a build that is already queued or running for this commit instead of starting another.
  PENDING=$(runs | jq -r '[.[] | select(.status != "completed")] | first | .databaseId // empty')
  if [ -z "$PENDING" ]; then
    KNOWN=$(runs | jq -c '[.[].databaseId]')
    echo "No simulator app for $TARGET; dispatching the Simulator App workflow on $BRANCH" >&2
    gh workflow run simulator-app.yml --repo "$REPO" --ref "$BRANCH" >&2
    for _ in $(seq 1 30); do
      PENDING=$(runs | jq -r --argjson known "$KNOWN" \
        '[.[] | select(.databaseId as $id | $known | index($id) | not)] | first | .databaseId // empty')
      test -z "$PENDING" || break
      sleep 5
    done
    test -n "$PENDING" || {
      echo "The dispatched run for $TARGET did not appear; $BRANCH may have moved past $HEAD_SHA" >&2
      exit 1
    }
  fi
  echo "Waiting for Simulator App run $PENDING: https://github.com/$REPO/actions/runs/$PENDING" >&2
  gh run watch "$PENDING" --repo "$REPO" --interval 30 --exit-status > /dev/null
  RUN_ID=$(find_build)
  test -n "$RUN_ID" || { echo "Run $PENDING finished without a simulator app" >&2; exit 1; }
fi

APP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/growingup-simulator-app.XXXXXX")
gh run download "$RUN_ID" --repo "$REPO" --name simulator-app --dir "$APP_DIR"
tar -xzf "$APP_DIR/GrowingUp-simulator.tar.gz" -C "$APP_DIR"
rm "$APP_DIR/GrowingUp-simulator.tar.gz"
echo "Simulator app for $TARGET from run $RUN_ID. Remove $APP_DIR when done." >&2
echo "$APP_DIR/GrowingUp.app"
