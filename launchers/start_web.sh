#!/usr/bin/env bash
# PortableClaude — launch the Claude session-viewer web app (.claude/app) with bundled Node.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              T=linux-x64 ;;
  Darwin-x86_64)             T=darwin-x64 ;;
  Darwin-arm64|Darwin-aarch64) T=darwin-arm64 ;;
  *) echo "Unsupported platform"; exit 1 ;;
esac
B="$ROOT/bin/$T"
[ -x "$B/node/bin/node" ] || { echo "No bundled Node for $T — run build.sh."; exit 1; }
export PATH="$B/node/bin:$B/git/bin:$B/python/bin:$PATH"
export TMPDIR="$ROOT/temp"; export NPM_CONFIG_CACHE="$ROOT/temp/npm-cache"
mkdir -p "$ROOT/temp/npm-cache"

APP="$ROOT/config/.claude/app"
[ -f "$APP/package.json" ] || { echo "web app not found at $APP"; exit 1; }
cd "$APP"
if [ ! -d node_modules ]; then
  echo "==> first run: installing web app deps (bundled npm)…"
  npm install --no-audit --no-fund
fi
echo " ======================================"
echo "  Claude session viewer — starting…"
echo "  (Vite will print the local URL below)"
echo " ======================================"
exec npm run dev
