#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: SwiftLint is unavailable; install it with 'brew install swiftlint'" >&2
  exit 1
fi

exec swiftlint lint --strict --reporter github-actions-logging
