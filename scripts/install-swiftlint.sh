#!/bin/sh

set -eu

# Installs the SwiftLint release that CI uses into DIRECTORY (default ~/.local/bin) on Linux, so agents run the
# same lint before pushing. On macOS use `brew install swiftlint`.
# The dynamic build needs libxml2.so.2 and finds SourceKit through scripts/lint-swift.sh; where libxml2.so.2 is
# missing, the static build is installed instead, which skips the few SourceKit rules (CI still runs them).
# SWIFTLINT_BUILD=dynamic (set by CI, which runs it inside the Swift container) skips that check and always
# installs the SourceKit build.
VERSION=0.65.1
DIRECTORY=${1:-"$HOME/.local/bin"}

test "$(uname -s)" = Linux || { echo "error: use 'brew install swiftlint' on macOS" >&2; exit 1; }
case "$(uname -m)" in
  x86_64) ASSET=swiftlint_linux_amd64.zip SHA256=caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d ;;
  aarch64|arm64) ASSET=swiftlint_linux_arm64.zip SHA256=9ffa52f478e6d8eb485d37d14715ffac90abc81c58f3370d598bf75be05605f8 ;;
  *) echo "error: no SwiftLint Linux build for $(uname -m)" >&2; exit 1 ;;
esac

TEMPORARY=$(mktemp -d)
trap 'rm -rf "$TEMPORARY"' EXIT
curl -fsSL --retry 3 -o "$TEMPORARY/$ASSET" "https://github.com/realm/SwiftLint/releases/download/$VERSION/$ASSET"
echo "$SHA256  $TEMPORARY/$ASSET" | sha256sum -c - >/dev/null
python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TEMPORARY/$ASSET" "$TEMPORARY"
chmod +x "$TEMPORARY/swiftlint" "$TEMPORARY/swiftlint-static"
BINARY=swiftlint
if [ "${SWIFTLINT_BUILD:-auto}" != dynamic ] && ! "$TEMPORARY/swiftlint" version >/dev/null 2>&1; then
  BINARY=swiftlint-static
fi
mkdir -p "$DIRECTORY"
mv "$TEMPORARY/$BINARY" "$DIRECTORY/swiftlint"
echo "Installed SwiftLint $VERSION ($BINARY) at $DIRECTORY/swiftlint"
