#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup() {
  cd "$SCRIPT_DIR"
  rm -rf ios-xcarchive
}

fail() {
  echo
  echo "==> ERROR: $1" >&2
  echo "==> Process aborted. Cleaning up temporary files..."
  cleanup
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "$1 is not installed or not added to PATH."
  fi
}

echo "==================================================="
echo "               BTCHESS IPA PACKAGER"
echo "==================================================="
echo

cd "$SCRIPT_DIR"

require_command unzip
require_command tar
require_command zip

echo "1. Checking for ios-xcarchive.zip..."
[[ -f ios-xcarchive.zip ]] || fail "ios-xcarchive.zip not found in the current folder."

echo "2. Extracting ios-xcarchive.zip..."
rm -rf ios-xcarchive
unzip -q ios-xcarchive.zip -d ios-xcarchive || fail "Failed to extract ios-xcarchive.zip."

cd ios-xcarchive

echo "3. Checking for Runner.xcarchive.tar.gz..."
[[ -f Runner.xcarchive.tar.gz ]] || fail "Runner.xcarchive.tar.gz not found inside the extracted folder."

echo "4. Extracting Runner.xcarchive.tar.gz..."
rm -rf Runner.xcarchive
mkdir -p Runner.xcarchive
tar -xzf Runner.xcarchive.tar.gz -C Runner.xcarchive || fail "Failed to extract tar.gz archive."

APP_PATH="Runner.xcarchive/Runner.xcarchive/Products/Applications"
[[ -d "$APP_PATH/Runner.app" ]] || fail "Runner.app not found inside the extracted tar.gz archive."

cd "$APP_PATH"

echo "5. Creating Payload folder and copying Runner.app..."
rm -rf Payload Payload.zip btchess.ipa
mkdir -p Payload
cp -R Runner.app Payload/Runner.app

echo "6. Compressing Payload folder (Store method)..."
zip -0 -r Payload.zip Payload >/dev/null || fail "Failed to create Payload.zip."

echo "7. Renaming and moving btchess.ipa..."
mv -f Payload.zip btchess.ipa
mv -f btchess.ipa "$SCRIPT_DIR/btchess.ipa"

echo "8. Cleaning up temporary files..."
cleanup

echo "==> Success! btchess.ipa is ready for deployment."
