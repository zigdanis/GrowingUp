#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

if ! scripts/run-swift-format.sh lint \
  --configuration .swift-format \
  --strict \
  --recursive \
  --parallel \
  Core GrowingUp GrowingUpTests Widget; then
  echo "error: Swift formatting check failed; run scripts/format-swift.sh" >&2
  exit 1
fi
