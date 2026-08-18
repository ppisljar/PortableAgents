#!/usr/bin/env bash
# PortableAgents — launch the bundled portable Chrome (Chrome for Testing).
# The profile is kept on the drive so browsing state travels with it.
# Any arguments pass through to Chrome, e.g.:  chrome.sh https://example.com
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              T=linux-x64 ;;
  Darwin-x86_64)             T=darwin-x64 ;;
  Darwin-arm64|Darwin-aarch64) T=darwin-arm64 ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m)"; exit 1 ;;
esac
B="$ROOT/bin/$T"

# bundled Chrome binary (Chrome for Testing layout differs by OS)
case "$T" in
  linux-x64)  CHROME="$B/chrome/chrome" ;;
  darwin-*)   CHROME="$B/chrome/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" ;;
esac
[ -x "$CHROME" ] || { echo "No bundled Chrome for $T — run build.sh."; exit 1; }

exec "$CHROME" --user-data-dir="$ROOT/config/chrome-profile" "$@"
