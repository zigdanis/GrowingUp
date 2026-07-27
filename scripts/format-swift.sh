#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "error: swift-format is unavailable; select an Xcode toolchain that includes it" >&2
  exit 1
fi

exec xcrun swift-format format \
  --configuration .swift-format \
  --in-place \
  --recursive \
  --parallel \
  Core GrowingUp GrowingUpTests Widget
