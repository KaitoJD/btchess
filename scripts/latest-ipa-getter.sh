#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="KaitoJD/btchess"
WORKFLOW_FILE="build_master.yml"

cleanup() {
  cd "$SCRIPT_DIR"
  rm -rf Runner.xcarchive
}

fail() {
  echo
  echo "==> ERROR: $1" >&2
  echo "==> Process aborted. Cleaning up temporary folders..."
  cleanup
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "$1 is not installed or not added to PATH."
  fi
}

echo "==================================================="
echo "       BTCHESS IPA PACKAGER (AUTO-DOWNLOAD)"
echo "==================================================="
echo

cd "$SCRIPT_DIR"

require_command gh
require_command tar
require_command zip

echo "1. Detecting default branch and latest SUCCESSFUL run ID..."
DEFAULT_BRANCH="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')" \
  || fail "Failed to get default branch. Make sure you are logged in (run: gh auth login)."
[[ -n "${DEFAULT_BRANCH//[[:space:]]/}" ]] \
  || fail "Failed to get default branch. Make sure you are logged in (run: gh auth login)."

echo "   -> Default branch: $DEFAULT_BRANCH"
echo "   -> Target workflow: $WORKFLOW_FILE"

RUN_ID="$(gh run list --repo "$REPO" --branch "$DEFAULT_BRANCH" --workflow "$WORKFLOW_FILE" --status success --limit 1 --json databaseId --jq '.[0].databaseId')" \
  || fail "Failed to get the latest successful workflow run."
[[ -n "${RUN_ID//[[:space:]]/}" && "$RUN_ID" != "null" ]] \
  || fail "No successful workflow runs found for $WORKFLOW_FILE on branch: $DEFAULT_BRANCH"

echo "   -> Latest Successful Run ID: $RUN_ID"

echo "2. Downloading artifact from GitHub Actions..."
rm -rf Runner.xcarchive Runner.xcarchive.tar.gz
gh run download "$RUN_ID" --name ios-xcarchive --repo "$REPO" --dir . \
  || fail "Failed to download artifact."

echo "3. Checking for Runner.xcarchive.tar.gz..."
[[ -f Runner.xcarchive.tar.gz ]] || fail "Runner.xcarchive.tar.gz not found after download."

echo "4. Extracting Runner.xcarchive.tar.gz..."
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

echo "8. Cleaning up temporary files and source archives..."
cd "$SCRIPT_DIR"
rm -rf Runner.xcarchive
rm -f Runner.xcarchive.tar.gz

echo "==> Success! btchess.ipa is downloaded and ready for deployment."
