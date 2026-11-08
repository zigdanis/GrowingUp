#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: SwiftLint is unavailable; install it with 'brew install swiftlint' on macOS or scripts/install-swiftlint.sh on Linux" >&2
  exit 1
fi

# On Linux, SwiftLint's SourceKit rules load the library from the active Swift toolchain.
if [ "$(uname -s)" = Linux ] && [ -z "${LINUX_SOURCEKIT_LIB_PATH:-}" ] && command -v swift >/dev/null 2>&1; then
  LINUX_SOURCEKIT_LIB_PATH=$(swift -print-target-info \
    | python3 -c 'import json, os, sys; print(os.path.dirname(json.load(sys.stdin)["paths"]["runtimeResourcePath"]))')
  export LINUX_SOURCEKIT_LIB_PATH
fi

exec swiftlint lint --strict --reporter github-actions-logging
