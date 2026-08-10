#!/usr/bin/env bash
# PortableAgents — launch the Claude session-viewer web app (.claude/app) with bundled Node.
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

# --- patch project paths for this mount point (portable across OS/mounts) -------
for f in "$ROOT/config/.claude/projects_list.json" "$ROOT/config/.claude/project_config.yaml"; do
  [ -f "$f" ] && sed "s|__ROOT__|$ROOT|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

APP="$ROOT/config/.claude/app"
[ -f "$APP/package.json" ] || { echo "web app not found at $APP"; exit 1; }
cd "$APP"

# Preferred: the prebuilt, pruned production app — pure Node, works offline on every platform.
if [ -f server-dist/index.js ] && [ -f dist/index.html ]; then
  echo " ======================================"
  echo "  Claude session viewer (built) — starting…"
  echo "  (the server prints its URL below)"
  echo " ======================================"
  exec node server-dist/index.js
fi

# Fallback (unbuilt / first run without a prior build): dev mode.
[ -d node_modules ] || { echo "==> first run: installing web app deps…"; npm install --no-audit --no-fund; }
echo "  (no prebuilt app found — starting dev mode; Vite prints the URL below)"
exec npm run dev
