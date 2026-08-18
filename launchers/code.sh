#!/usr/bin/env bash
# PortableAgents — launch the bundled portable VS Code.
# User data (settings, extensions) is kept on the drive via VS Code's portable mode.
# With no argument it opens the drive root; otherwise args pass through, e.g.:  code.sh myproject
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              T=linux-x64 ;;
  Darwin-x86_64)             T=darwin-x64 ;;
  Darwin-arm64|Darwin-aarch64) T=darwin-arm64 ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m)"; exit 1 ;;
esac
VD="$ROOT/bin/$T/vscode"

case "$T" in
  darwin-*) CODE="$VD/Visual Studio Code.app/Contents/Resources/app/bin/code" ;;
  *)        CODE="$VD/bin/code" ;;
esac
[ -x "$CODE" ] || { echo "No bundled VS Code for $T — run build.sh."; exit 1; }

exec "$CODE" "${@:-$ROOT}"
