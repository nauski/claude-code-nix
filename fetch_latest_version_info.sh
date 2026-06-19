#!/usr/bin/env bash
set -euo pipefail

PACKAGE="@anthropic-ai/claude-code"

echo "Fetching latest version for $PACKAGE..."
LATEST=$(curl -s "https://registry.npmjs.org/${PACKAGE}" | jq -r '.["dist-tags"].latest')
echo "Latest version: $LATEST"
echo

for PLATFORM in linux-x64 linux-arm64 darwin-x64 darwin-arm64; do
  URL="https://registry.npmjs.org/${PACKAGE}-${PLATFORM}/-/claude-code-${PLATFORM}-${LATEST}.tgz"
  TMP=$(mktemp)
  curl -sL "$URL" -o "$TMP"
  SHA256=$(nix hash file --type sha256 --base32 "$TMP")
  rm "$TMP"
  echo "${PLATFORM}: sha256 = \"${SHA256}\";"
done
