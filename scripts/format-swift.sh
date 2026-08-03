#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

exec scripts/run-swift-format.sh format \
  --configuration .swift-format \
  --in-place \
  --recursive \
  --parallel \
  Core GrowingUp GrowingUpTests Widget
