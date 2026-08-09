#!/usr/bin/env bash
# PortableAgents launcher (Linux/macOS) — a shell with claude/codex/git/python/chrome on PATH,
# all config + cache on the drive. Nothing is installed on the host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              T=linux-x64 ;;
  Darwin-x86_64)             T=darwin-x64 ;;
  Darwin-arm64|Darwin-aarch64) T=darwin-arm64 ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m)"; exit 1 ;;
esac
B="$ROOT/bin/$T"
[ -x "$B/node/bin/node" ] || { echo "No bundled Node for $T — run build.sh."; exit 1; }

# bundled Chrome binary (Chrome for Testing layout differs by OS)
case "$T" in
  linux-x64)  CHROME="$B/chrome/chrome" ;;
  darwin-*)   CHROME="$B/chrome/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" ;;
esac

export PATH="$B/node/bin:$B/git/bin:$B/python/bin:$ROOT/tools/$T/claude-code/node_modules/.bin:$ROOT/tools/$T/codex/node_modules/.bin:$PATH"
[ -d "$B/git/libexec/git-core" ] && export GIT_EXEC_PATH="$B/git/libexec/git-core"
[ -d "$B/git/share/git-core/templates" ] && export GIT_TEMPLATE_DIR="$B/git/share/git-core/templates"
export CHROME_BIN="$CHROME" PUPPETEER_EXECUTABLE_PATH="$CHROME" CHROME_PATH="$CHROME"

# config + cache stay on the drive
export CLAUDE_CONFIG_DIR="$ROOT/config/.claude"
export XDG_CONFIG_HOME="$ROOT/config"
export TMPDIR="$ROOT/temp"; export NPM_CONFIG_CACHE="$ROOT/temp/npm-cache"
export NODE_COMPILE_CACHE="$ROOT/temp/node-cache"; export PIP_CACHE_DIR="$ROOT/temp/pip-cache"
mkdir -p "$ROOT/temp/npm-cache" "$ROOT/temp/node-cache" "$ROOT/temp/pip-cache"
[ -f "$ROOT/config/env.sh" ] && source "$ROOT/config/env.sh"

echo " ======================================"
echo "  PortableAgents ($T)"
echo "  claude | codex | git | python | node"
echo "  chrome at: \$CHROME_BIN"
echo "  web app:   bash start_web.sh"
echo " ======================================"
[ "${ANTHROPIC_API_KEY:-YOUR_KEY_HERE}" = "YOUR_KEY_HERE" ] && \
  echo "  (no API key set — 'claude' will prompt OAuth login)"
cd "${HOME:-$ROOT}"
exec bash --norc --noprofile
