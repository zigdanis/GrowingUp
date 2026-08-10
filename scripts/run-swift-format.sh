#!/bin/sh

set -eu

if command -v xcrun >/dev/null 2>&1 && xcrun --find swift-format >/dev/null 2>&1; then
  exec xcrun swift-format "$@"
fi

if command -v swift-format >/dev/null 2>&1; then
  exec swift-format "$@"
fi

echo "error: swift-format is unavailable; install a Swift toolchain or select one in Xcode" >&2
exit 1
