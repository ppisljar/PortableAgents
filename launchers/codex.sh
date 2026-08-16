#!/usr/bin/env bash
# PortableAgents — Codex (OpenAI CLI) with default OpenAI API.
# Any arguments pass straight through to `codex`, e.g.:  ./codex.sh "explain this code"
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- platform detection (same as start.sh) ----------------------------------
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)              T=linux-x64 ;;
  Darwin-x86_64)             T=darwin-x64 ;;
  Darwin-arm64|Darwin-aarch64) T=darwin-arm64 ;;
  *) echo "Unsupported platform: $(uname -s)-$(uname -m)"; exit 1 ;;
esac
B="$ROOT/bin/$T"
[ -x "$B/node/bin/node" ] || { echo "No bundled Node for $T — run build.sh."; exit 1; }

# --- PATH + bundled runtimes ------------------------------------------------
case "$T" in
  linux-x64)  CHROME="$B/chrome/chrome" ;;
  darwin-*)   CHROME="$B/chrome/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" ;;
esac

export PATH="$B/node/bin:$B/git/bin:$B/python/bin:$ROOT/tools/$T/shims:$PATH"
[ -d "$B/git/libexec/git-core" ] && export GIT_EXEC_PATH="$B/git/libexec/git-core"
[ -d "$B/git/share/git-core/templates" ] && export GIT_TEMPLATE_DIR="$B/git/share/git-core/templates"
export CHROME_BIN="$CHROME" PUPPETEER_EXECUTABLE_PATH="$CHROME" CHROME_PATH="$CHROME"

# --- config + cache stay on the drive ---------------------------------------
export CLAUDE_CONFIG_DIR="$ROOT/config/.claude"
export XDG_CONFIG_HOME="$ROOT/config"
export TMPDIR="$ROOT/temp"; export NPM_CONFIG_CACHE="$ROOT/temp/npm-cache"
export NODE_COMPILE_CACHE="$ROOT/temp/node-cache"; export PIP_CACHE_DIR="$ROOT/temp/pip-cache"
mkdir -p "$ROOT/temp/npm-cache" "$ROOT/temp/node-cache" "$ROOT/temp/pip-cache"

# --- default env (API keys — set your real keys) -----------------------------
CODEX_ENV="${CODEX_ENV:-$ROOT/config/env.sh}"
if [ -f "$CODEX_ENV" ]; then
  # shellcheck disable=SC1090
  source "$CODEX_ENV"
fi

# --- patch project paths for this mount point (portable across OS/mounts) -------
for f in "$ROOT/config/.claude/projects_list.json" "$ROOT/config/.claude/project_config.yaml"; do
  [ -f "$f" ] && sed "s|__ROOT__|$ROOT|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

cd "$ROOT"
exec codex "$@"
