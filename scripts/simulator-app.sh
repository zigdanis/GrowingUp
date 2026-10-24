#!/bin/bash

set -euo pipefail

# Requires authenticated gh and jq. Downloads the Release simulator app that the Simulator App workflow
# built for a PR head, or for the newest master push without an argument, and prints the GrowingUp.app path.
REPO=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
if [ $# -gt 0 ]; then
  HEAD_SHA=$(gh api "repos/$REPO/pulls/$1" --jq .head.sha)
  TARGET="PR #$1 at $HEAD_SHA"
  FILTER=(--event pull_request --commit "$HEAD_SHA")
else
  TARGET=master
  FILTER=(--event push --branch master)
fi
RUN=$(gh run list --repo "$REPO" --workflow simulator-app.yml --status success "${FILTER[@]}" \
  --limit 1 --json databaseId,headSha | jq -c '.[0] // empty')
test -n "$RUN" || { echo "No successful Simulator App run for $TARGET yet." >&2; exit 1; }
RUN_ID=$(jq -r .databaseId <<< "$RUN")

APP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/growingup-simulator-app.XXXXXX")
gh run download "$RUN_ID" --repo "$REPO" --name simulator-app --dir "$APP_DIR"
tar -xzf "$APP_DIR/GrowingUp-simulator.tar.gz" -C "$APP_DIR"
rm "$APP_DIR/GrowingUp-simulator.tar.gz"
echo "Simulator app for $TARGET from run $RUN_ID ($(jq -r .headSha <<< "$RUN")). Remove $APP_DIR when done." >&2
echo "$APP_DIR/GrowingUp.app"
