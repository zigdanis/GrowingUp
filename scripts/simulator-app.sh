#!/bin/bash

set -euo pipefail

# Requires authenticated gh and jq. Downloads the Release simulator app that the Simulator App workflow
# built for a PR head, or for the newest master build without an argument, and prints the GrowingUp.app path.
REPO=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
if [ $# -gt 0 ]; then
  PR=$(gh api "repos/$REPO/pulls/$1")
  HEAD_SHA=$(jq -r .head.sha <<< "$PR")
  BRANCH=$(jq -r .head.ref <<< "$PR")
  TARGET="PR #$1 at $HEAD_SHA"
  FILTER=(--commit "$HEAD_SHA")
else
  BRANCH=master
  TARGET=master
  # Push and manual runs only: a fork PR from its own master branch also reports head branch master.
  FILTER=(--branch master)
fi

# Artifacts expire after 14 days while their runs stay successful, so take the newest run that still has one.
RUN=
while read -r CANDIDATE; do
  test -n "$CANDIDATE" || continue
  ARTIFACT_ID=$(gh api "repos/$REPO/actions/runs/$(jq -r .databaseId <<< "$CANDIDATE")/artifacts" \
    --jq '[.artifacts[] | select(.name == "simulator-app" and (.expired | not))] | first | .id // empty')
  if [ -n "$ARTIFACT_ID" ]; then
    RUN=$CANDIDATE
    break
  fi
done <<< "$(gh run list --repo "$REPO" --workflow simulator-app.yml --status success "${FILTER[@]}" \
  --limit 20 --json databaseId,headSha,event \
  | jq -c --arg target "$TARGET" '.[] | select($target != "master" or .event != "pull_request")')"
test -n "$RUN" || {
  echo "No unexpired simulator app for $TARGET. Build one: gh workflow run simulator-app.yml --repo $REPO --ref $BRANCH" >&2
  exit 1
}
RUN_ID=$(jq -r .databaseId <<< "$RUN")

APP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/growingup-simulator-app.XXXXXX")
gh run download "$RUN_ID" --repo "$REPO" --name simulator-app --dir "$APP_DIR"
tar -xzf "$APP_DIR/GrowingUp-simulator.tar.gz" -C "$APP_DIR"
rm "$APP_DIR/GrowingUp-simulator.tar.gz"
echo "Simulator app for $TARGET from run $RUN_ID ($(jq -r .headSha <<< "$RUN")). Remove $APP_DIR when done." >&2
echo "$APP_DIR/GrowingUp.app"
