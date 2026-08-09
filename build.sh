#!/usr/bin/env bash
# PortableClaude builder — assembles a self-contained, cross-platform agent payload.
# Run on macOS or Linux. Downloads Node/Python/Git/Chrome for all targets, installs the
# Claude + Codex CLIs, vendors flow0's .claude, and builds the web app.
#
#   bash build.sh <dist-or-drive-path>          e.g.  bash build.sh ./dist   |   /Volumes/USB
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/versions.env"

OUT="${1:?Usage: bash build.sh <dist-or-drive-path>}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"   # absolutize: subshells `cd` into tool dirs, so derived paths must be absolute
mkdir -p "$OUT"/{bin,tools,config,staging,temp,launchers}
STAGE="$OUT/staging"

# ── helpers ──────────────────────────────────────────────────────────────────
say(){ printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
dl(){ curl -fSL --retry 3 --progress-bar "$1" -o "$2"; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1"; exit 1; }; }
need curl; need tar; need unzip; need python3; need rsync

gh_asset(){  # <owner/repo> <tag|latest> <python-regex over asset name> -> download URL
  local repo="$1" tag="$2" pat="$3" api
  [ "$tag" = latest ] && api="https://api.github.com/repos/$repo/releases/latest" \
                      || api="https://api.github.com/repos/$repo/releases/tags/$tag"
  curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api" \
   | python3 -c 'import json,sys,re;d=json.load(sys.stdin);p=re.compile(sys.argv[1]);print(next(a["browser_download_url"] for a in d.get("assets",[]) if p.search(a["name"])))' "$pat"
}

# platform token maps (target -> per-source token)
node_token(){ echo "$1"; }                              # nodejs uses our tokens verbatim
py_triple(){ case "$1" in
  linux-x64)   echo x86_64-unknown-linux-gnu ;;
  win-x64)     echo x86_64-pc-windows-msvc ;;
  darwin-x64)  echo x86_64-apple-darwin ;;
  darwin-arm64)echo aarch64-apple-darwin ;; esac; }
dugite_token(){ case "$1" in
  linux-x64)   echo ubuntu-x64 ;;
  win-x64)     echo windows-x64 ;;
  darwin-x64)  echo macOS-x64 ;;
  darwin-arm64)echo macOS-arm64 ;; esac; }
cft_platform(){ case "$1" in
  linux-x64) echo linux64 ;; win-x64) echo win64 ;;
  darwin-x64) echo mac-x64 ;; darwin-arm64) echo mac-arm64 ;; esac; }
npm_os(){   case "$1" in linux-x64) echo linux;; win-x64) echo win32;; darwin-*) echo darwin;; esac; }
npm_cpu(){  case "$1" in *-arm64) echo arm64;; *) echo x64;; esac; }

extract(){  # <archive> <dest-dir>  (dest gets the archive's single top dir flattened)
  local a="$1" d="$2"; rm -rf "$d"; mkdir -p "$d.tmp"
  case "$a" in
    *.zip)        unzip -q "$a" -d "$d.tmp" ;;
    *.tar.xz)     tar -xJf "$a" -C "$d.tmp" ;;
    *.tar.gz|*.tgz) tar -xzf "$a" -C "$d.tmp" ;;
    *) echo "unknown archive: $a"; exit 1 ;;
  esac
  # flatten if there's exactly one top-level dir
  local inner; inner="$(find "$d.tmp" -mindepth 1 -maxdepth 1)"
  if [ "$(echo "$inner" | wc -l)" -eq 1 ] && [ -d "$inner" ]; then mv "$inner" "$d"; rmdir "$d.tmp";
  else mv "$d.tmp" "$d"; fi
}

# ── runtimes, per target ─────────────────────────────────────────────────────
for T in $TARGETS; do
  say "[$T] runtimes"
  B="$OUT/bin/$T"; mkdir -p "$B"

  # Node.js — nodejs.org (win = .zip, others = tarball)
  if [ ! -e "$B/node/README.md" ] && [ ! -e "$B/node/node.exe" ] && [ ! -e "$B/node/bin/node" ]; then
    case "$T" in
      win-x64) NURL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-win-x64.zip" ;;
      linux-x64) NURL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" ;;
      *) NURL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$T.tar.gz" ;;
    esac
    NARC="$STAGE/$(basename "$NURL")"
    echo "  node: $NURL"; dl "$NURL" "$NARC"; extract "$NARC" "$B/node"
  else echo "  node: present"; fi

  # Python — python-build-standalone (install_only, relocatable)
  if [ ! -d "$B/python" ]; then
    PURL="$(gh_asset astral-sh/python-build-standalone "$PYTHON_RELEASE" \
      "cpython-${PYTHON_VERSION}\\+${PYTHON_RELEASE}-$(py_triple "$T").*install_only.*\\.tar\\.gz$")"
    echo "  python: $PURL"; dl "$PURL" "$STAGE/py-$T.tar.gz"; extract "$STAGE/py-$T.tar.gz" "$B/python"
  else echo "  python: present"; fi

  # Git — dugite-native (relocatable)
  if [ ! -d "$B/git" ]; then
    GURL="$(gh_asset desktop/dugite-native "$DUGITE_VERSION" "$(dugite_token "$T").*\\.tar\\.gz$")"
    echo "  git: $GURL"; dl "$GURL" "$STAGE/git-$T.tar.gz"; extract "$STAGE/git-$T.tar.gz" "$B/git"
  else echo "  git: present"; fi

  # Chrome — Chrome for Testing (resolve URL from the CfT JSON)
  if [ ! -d "$B/chrome" ]; then
    CURL="$(curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
      | python3 -c 'import json,sys;d=json.load(sys.stdin);ch=d["channels"][sys.argv[1]]["downloads"]["chrome"];print(next(x["url"] for x in ch if x["platform"]==sys.argv[2]))' "$CHROME_CHANNEL" "$(cft_platform "$T")")"
    echo "  chrome: $CURL"; dl "$CURL" "$STAGE/chrome-$T.zip"; extract "$STAGE/chrome-$T.zip" "$B/chrome"
  else echo "  chrome: present"; fi
done

# ── host node/npm (used to install the npm tools for every target) ───────────
HOST_T="$(uname -s | tr 'A-Z' 'a-z' | sed 's/darwin/darwin/;s/linux/linux/')-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/;s/arm64/arm64/')"
HOST_NPM="$OUT/bin/$HOST_T/node/bin/npm"; HOST_NODE_BIN="$OUT/bin/$HOST_T/node/bin"
[ -x "$HOST_NPM" ] || { echo "host node for '$HOST_T' not found — is your platform in TARGETS?"; exit 1; }
export PATH="$HOST_NODE_BIN:$PATH"

# ── Claude + Codex, cross-installed per target ───────────────────────────────
for T in $TARGETS; do
  say "[$T] agents (claude + codex)"
  for pair in "claude-code:$CLAUDE_PKG" "codex:$CODEX_PKG"; do
    name="${pair%%:*}"; pkg="${pair#*:}"; d="$OUT/tools/$T/$name"
    if [ -d "$d/node_modules" ]; then echo "  $name: present"; continue; fi
    echo "  installing $name ($pkg) for $T ..."; mkdir -p "$d"
    ( cd "$d"
      "$HOST_NPM" init -y >/dev/null
      "$HOST_NPM" install --os="$(npm_os "$T")" --cpu="$(npm_cpu "$T")" --no-audit --no-fund "$pkg" \
        || { echo "  retry $name/$T ..."; "$HOST_NPM" install --os="$(npm_os "$T")" --cpu="$(npm_cpu "$T")" --no-audit --no-fund "$pkg"; }
    ) || { echo "  ERROR: failed to install $name for $T"; exit 1; }
  done
done

# ── vendor flow0 .claude (skills, app, agents, commands) — no secrets/junk ───
say "vendor $FLOW0_DIR/.claude -> config/.claude"
[ -d "$FLOW0_DIR/.claude" ] || { echo "FLOW0_DIR/.claude not found: $FLOW0_DIR"; exit 1; }
rsync -a --delete \
  --exclude '.secrets/' --exclude 'node_modules/' --exclude 'venv/' --exclude '.venv/' \
  --exclude '__pycache__/' --exclude '*.pyc' --exclude 'todos/' --exclude '.browser_data/' \
  --exclude 'app/dist/' --exclude 'app/server-dist/' --exclude 'tmp/' --exclude '.DS_Store' \
  "$FLOW0_DIR/.claude/" "$OUT/config/.claude/"
# secret-provider template so the layout is discoverable (real secrets provided on the drive)
mkdir -p "$OUT/config/.claude/.secrets"
[ -f "$OUT/config/.claude/.secrets/service-provider.json" ] || \
  echo '{ "network": { "unifi": {}, "fritzbox": {} } }' > "$OUT/config/.claude/.secrets/service-provider.json.example"

# ── python deps for the skills — installed for ALL targets (offline wheels) ──
say "python deps for the skills (all platforms, offline wheels)"
HOST_PY="$OUT/bin/$HOST_T/python/bin/python3"
PYMM="$(echo "$PYTHON_VERSION" | cut -d. -f1-2)"
pip_platform(){ case "$1" in
  linux-x64)    echo manylinux2014_x86_64 ;;
  win-x64)      echo win_amd64 ;;
  darwin-x64)   echo macosx_11_0_x86_64 ;;   # 11_0 matches 10.9..11 wheels; 10_12 excluded newer-only ones
  darwin-arm64) echo macosx_11_0_arm64 ;; esac; }
py_site(){ case "$1" in
  win-x64) echo "$OUT/bin/$1/python/Lib/site-packages" ;;
  *)       echo "$OUT/bin/$1/python/lib/python$PYMM/site-packages" ;; esac; }
pip_target(){ "$HOST_PY" -m pip install --disable-pip-version-check --no-input -q \
  --target "$1" --platform "$2" --python-version "$PYMM" --only-binary=:all: "${@:3}"; }
if [ -f "$FLOW0_DIR/requirements.txt" ] && [ -x "$HOST_PY" ]; then
  "$HOST_PY" -m pip install --upgrade pip --quiet || true
  for T in $TARGETS; do
    SITE="$(py_site "$T")"; PLAT="$(pip_platform "$T")"; mkdir -p "$SITE"
    echo "  [$T] pip wheels ($PLAT) -> site-packages"
    if ! pip_target "$SITE" "$PLAT" -r "$FLOW0_DIR/requirements.txt" 2>/dev/null; then
      echo "  [$T] bulk install failed (bad pin / missing wheel) — installing per-package…"
      grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$FLOW0_DIR/requirements.txt" | while IFS= read -r req; do
        pip_target "$SITE" "$PLAT" "$req" 2>/dev/null || echo "    skip: $req"
      done
    fi
  done
fi

# ── web app — build client + compile server + prune to prod deps (Node-only, all platforms) ──
say "web app: build client + compile server + prune to prod deps"
APP="$OUT/config/.claude/app"
if [ -f "$APP/server-dist/index.js" ] && [ -f "$APP/dist/index.html" ]; then
  echo "  web app: already built"
elif [ -f "$APP/package.json" ]; then
  ( cd "$APP"
    "$HOST_NPM" install --no-audit --no-fund
    "$HOST_NPM" exec -- vite build                                    # client -> dist/ (static)
    # compile server to server-dist/ (sibling of dist/) so its `../dist` points at the client build
    "$HOST_NPM" exec -- tsc -p tsconfig.server.json --outDir server-dist || true
    "$HOST_NPM" prune --omit=dev                                      # drop dev deps -> node_modules pure-JS
  ) || echo "  (web app build issue — start_web will finish on first run)"
fi

# ── launchers + config ───────────────────────────────────────────────────────
say "launchers + config"
cp "$HERE/launchers/"* "$OUT/" 2>/dev/null || true
chmod +x "$OUT"/start.sh "$OUT"/start_web.sh 2>/dev/null || true
[ -f "$OUT/config/CLAUDE.md" ] || cp "$HERE/config/CLAUDE.md" "$OUT/config/CLAUDE.md" 2>/dev/null || true
[ -f "$OUT/config/env.sh" ] || cat > "$OUT/config/env.sh" <<'E'
# Optional API keys (leave as-is to use OAuth login instead).
export ANTHROPIC_API_KEY="YOUR_KEY_HERE"
export OPENAI_API_KEY="YOUR_KEY_HERE"
E
[ -f "$OUT/config/env.bat" ] || cat > "$OUT/config/env.bat" <<'E'
set "ANTHROPIC_API_KEY=YOUR_KEY_HERE"
set "OPENAI_API_KEY=YOUR_KEY_HERE"
E

rm -rf "$STAGE"
say "Done. Payload at: $OUT"
echo "  Run:  bash \"$OUT/start.sh\"   |   web: bash \"$OUT/start_web.sh\""
