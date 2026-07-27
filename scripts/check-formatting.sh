#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "error: swift-format is unavailable; select an Xcode toolchain that includes it" >&2
  exit 1
fi

if ! xcrun swift-format lint \
  --configuration .swift-format \
  --strict \
  --recursive \
  --parallel \
  Core GrowingUp GrowingUpTests Widget; then
  echo "error: Swift formatting check failed; run scripts/format-swift.sh" >&2
  exit 1
fi
