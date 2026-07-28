#!/bin/sh

set -eu

patterns='(TELEGRAM_BOT_TOKEN|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|https?://[^[:space:]]+:[^[:space:]@]+@|/Users/[^/[:space:]]+/)'

matches=$(git grep -nIE "$patterns" -- ':!scripts/check-secrets.sh' ':!docs/public-release-checklist.md' || true)

if [ -n "$matches" ]; then
	printf '%s\n' "Potential secret material or machine-specific paths found in tracked files:" >&2
	printf '%s\n' "$matches" >&2
	exit 1
fi

printf '%s\n' "No known secret patterns or machine-specific paths found in tracked files."
