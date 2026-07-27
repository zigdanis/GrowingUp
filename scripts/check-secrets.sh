#!/bin/sh

set -eu

patterns='(TELEGRAM_BOT_TOKEN|CRASHLYTICS_API_TOKEN|CRASHLYTICS_BUILD_SECRET|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|https?://[^[:space:]]+:[^[:space:]@]+@)'

matches=$(git grep -nIE "$patterns" -- ':!scripts/check-secrets.sh' ':!docs/public-release-checklist.md' || true)

if [ -n "$matches" ]; then
	printf '%s\n' "Potential secret material found in tracked files:" >&2
	printf '%s\n' "$matches" >&2
	exit 1
fi

printf '%s\n' "No known secret patterns found in tracked files."
