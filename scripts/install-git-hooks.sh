#!/bin/sh

set -eu

REPOSITORY_ROOT=$(git rev-parse --show-toplevel)
cd "$REPOSITORY_ROOT"

git config core.hooksPath .githooks
echo "Installed GrowingUp Git hooks from .githooks"
