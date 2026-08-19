#!/usr/bin/env bash
# PortableAgents builder — assembles a self-contained, cross-platform agent payload.
# Run on macOS or Linux. Downloads Node/Python/Git/Chrome for all targets, installs the
# Claude + Codex CLIs, optionally vendors flow0's .claude (set FLOW0_DIR), and builds the web app.
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
  local repo="$1" tag="$2" pat="$3" api cache
  [ "$tag" = latest ] && api="https://api.github.com/repos/$repo/releases/latest" \
                      || api="https://api.github.com/repos/$repo/releases/tags/$tag"
  # cache the release JSON per repo+tag: resolving many assets (one per target) then costs no extra API calls
  cache="$STAGE/ghapi-$(printf '%s' "$repo-$tag" | tr '/ ' '__').json"
  [ -s "$cache" ] || curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api" -o "$cache"
  python3 -c 'import json,sys,re;d=json.load(open(sys.argv[1]));p=re.compile(sys.argv[2]);print(next(a["browser_download_url"] for a in d.get("assets",[]) if p.search(a["name"])))' "$cache" "$pat"
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

# ── launch shims per target ──────────────────────────────────────────────────
# npm's node_modules/.bin shims are generated for the BUILD host only: on a
# cross-build they carry the wrong platform, and on exFAT (no symlinks) they
# degrade to plain-file copies of the "native binary not installed" stub. On top
# of that, claude-code ships bin/claude.exe as a ~500B placeholder that its
# postinstall replaces with the platform-native binary — but postinstall runs on
# the build host, so the target's binary is never placed. Net result on Windows:
# `claude` isn't found, and the placeholder .exe is "not a valid Win32 app".
#
# So we bypass .bin entirely: emit our own correctly-named shims that exec the
# real, already-downloaded native binaries in place. No copies, no symlinks.
#   - claude: a compiled native binary at .../@anthropic-ai/claude-code-<plat>/claude[.exe]
#   - codex:  a node wrapper (bin/codex.js) that resolves its own native binary
say "launch shims (per target — bypass host-only npm .bin)"
claude_native(){ case "$1" in
  win-x64) echo win32-x64 ;;      linux-x64) echo linux-x64 ;;
  darwin-x64) echo darwin-x64 ;;  darwin-arm64) echo darwin-arm64 ;; esac; }
for T in $TARGETS; do
  SH="$OUT/tools/$T/shims"; mkdir -p "$SH"
  NP="$(claude_native "$T")"
  case "$T" in
    win-x64)
      # %~dp0 has a trailing "\"; shims live in tools\<T>\shims\ so ..\ is tools\<T>\
      printf '@echo off\r\n"%%~dp0..\\claude-code\\node_modules\\@anthropic-ai\\claude-code-%s\\claude.exe" %%*\r\n' "$NP" > "$SH/claude.cmd"
      printf '@echo off\r\nnode "%%~dp0..\\codex\\node_modules\\@openai\\codex\\bin\\codex.js" %%*\r\n' > "$SH/codex.cmd"
      ;;
    *)
      cat > "$SH/claude" <<EOF
#!/bin/sh
DIR="\$(CDPATH= cd "\$(dirname "\$0")/.." && pwd)"
exec "\$DIR/claude-code/node_modules/@anthropic-ai/claude-code-$NP/claude" "\$@"
EOF
      cat > "$SH/codex" <<'EOF'
#!/bin/sh
DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
exec node "$DIR/codex/node_modules/@openai/codex/bin/codex.js" "$@"
EOF
      chmod +x "$SH/claude" "$SH/codex"
      ;;
  esac
done

# ── extra CLI tools, per target ──────────────────────────────────────────────
# ripgrep/fd/bat/jq/uv/gh/delta/micro/pandoc/ffmpeg — relocatable binaries dropped
# into bin/<T>/extras (the launchers prepend it to PATH). Pulled from each project's
# latest GitHub release, so they track upstream. A few have no build for some targets
# (e.g. no Intel-mac micro or delta) — those are skipped with a note; the build still
# succeeds. Best-effort: a download/extract failure skips that tool, never aborts.
say "extra CLI tools (ripgrep, fd, bat, jq, yq, uv, gh, delta, micro, glow, pandoc, ffmpeg, dust, 7zip, age, sops, gitleaks)"
rust_triple(){ case "$1" in
  win-x64)      echo x86_64-pc-windows-msvc ;;
  linux-x64)    echo x86_64-unknown-linux-musl ;;
  darwin-x64)   echo x86_64-apple-darwin ;;
  darwin-arm64) echo aarch64-apple-darwin ;; esac; }

# install_archive <T> <url> <binname...> : download+extract, copy each named binary into extras/
install_archive(){
  local T="$1" url="$2"; shift 2
  local E="$OUT/bin/$T/extras"; mkdir -p "$E"
  local arc="$STAGE/$(basename "$url")" tmp="$STAGE/x-extract-$T-$$"
  dl "$url" "$arc"; extract "$arc" "$tmp"
  local b f
  for b in "$@"; do
    # prefer the .exe (Windows archives may also ship a same-named text/script file)
    f="$(find "$tmp" -type f -name "$b.exe" | head -1)"
    [ -n "$f" ] || f="$(find "$tmp" -type f -name "$b" | head -1)"
    if [ -n "$f" ]; then cp "$f" "$E/$(basename "$f")"; chmod +x "$E/$(basename "$f")" 2>/dev/null || true
    else echo "    (warn: $b not found in $(basename "$url"))"; fi
  done
  rm -rf "$tmp" "$arc"
}
# install_raw <T> <url> <outname> : download a bare single-file binary into extras/
install_raw(){
  local T="$1" url="$2" out="$3" E="$OUT/bin/$1/extras"; mkdir -p "$E"
  dl "$url" "$E/$out"; chmod +x "$E/$out" 2>/dev/null || true
}

for T in $TARGETS; do
  echo "  [$T] extras"
  RT="$(rust_triple "$T")"; U=""
  # rust single-binary tools (archive; binary lives inside a flattened dir)
  U="$(gh_asset BurntSushi/ripgrep latest "ripgrep-.*-${RT}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" rg     || echo "    skip ripgrep"
  U="$(gh_asset sharkdp/fd        latest "fd-.*-${RT}\\.(tar\\.gz|zip)$"      2>/dev/null)" && install_archive "$T" "$U" fd     || echo "    skip fd"
  U="$(gh_asset sharkdp/bat       latest "bat-.*-${RT}\\.(tar\\.gz|zip)$"     2>/dev/null)" && install_archive "$T" "$U" bat    || echo "    skip bat"
  U="$(gh_asset astral-sh/uv      latest "uv-${RT}\\.(tar\\.gz|zip)$"         2>/dev/null)" && install_archive "$T" "$U" uv uvx || echo "    skip uv"
  U="$(gh_asset dandavison/delta  latest "delta-.*-${RT}\\.(tar\\.gz|zip)$"   2>/dev/null)" && install_archive "$T" "$U" delta  || echo "    skip delta (no build for $T)"
  # jq — bare per-OS binary
  case "$T" in win-x64) JQ=jq-windows-amd64.exe;; linux-x64) JQ=jq-linux-amd64;; darwin-x64) JQ=jq-macos-amd64;; darwin-arm64) JQ=jq-macos-arm64;; esac
  U="$(gh_asset jqlang/jq latest "^${JQ}$" 2>/dev/null)" && { case "$T" in win-x64) install_raw "$T" "$U" jq.exe;; *) install_raw "$T" "$U" jq;; esac; } || echo "    skip jq"
  # gh — go naming; binary at bin/gh inside the archive
  case "$T" in win-x64) GT=windows_amd64;; linux-x64) GT=linux_amd64;; darwin-x64) GT=macOS_amd64;; darwin-arm64) GT=macOS_arm64;; esac
  U="$(gh_asset cli/cli latest "gh_.*_${GT}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" gh || echo "    skip gh"
  # micro — no Intel-mac build
  case "$T" in win-x64) MT=win64;; linux-x64) MT=linux64-static;; darwin-x64) MT="";; darwin-arm64) MT=macos-arm64;; esac
  { [ -n "$MT" ] && U="$(gh_asset zyedidia/micro latest "micro-.*-${MT}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" micro; } || echo "    skip micro (no build for $T)"
  # pandoc
  case "$T" in win-x64) PT=windows-x86_64;; linux-x64) PT=linux-amd64;; darwin-x64) PT=x86_64-macOS;; darwin-arm64) PT=arm64-macOS;; esac
  U="$(gh_asset jgm/pandoc latest "pandoc-.*-${PT}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" pandoc || echo "    skip pandoc"
  # glow — markdown viewer (Darwin/Linux/Windows + x86_64/arm64)
  case "$T" in win-x64) GL=Windows_x86_64;; linux-x64) GL=Linux_x86_64;; darwin-x64) GL=Darwin_x86_64;; darwin-arm64) GL=Darwin_arm64;; esac
  U="$(gh_asset charmbracelet/glow latest "glow_.*_${GL}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" glow || echo "    skip glow"
  # yq — bare per-OS binary
  case "$T" in win-x64) YQ=yq_windows_amd64.exe;; linux-x64) YQ=yq_linux_amd64;; darwin-x64) YQ=yq_darwin_amd64;; darwin-arm64) YQ=yq_darwin_arm64;; esac
  U="$(gh_asset mikefarah/yq latest "^${YQ}$" 2>/dev/null)" && { case "$T" in win-x64) install_raw "$T" "$U" yq.exe;; *) install_raw "$T" "$U" yq;; esac; } || echo "    skip yq"
  # dust — rust triples; upstream has no Apple-silicon (darwin-arm64) build
  U="$(gh_asset bootandy/dust latest "dust-.*-${RT}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" dust || echo "    skip dust (no build for $T)"
  # age + age-keygen — modern file encryption
  case "$T" in win-x64) AG=windows-amd64;; linux-x64) AG=linux-amd64;; darwin-x64) AG=darwin-amd64;; darwin-arm64) AG=darwin-arm64;; esac
  U="$(gh_asset FiloSottile/age latest "age-.*-${AG}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" age age-keygen || echo "    skip age"
  # sops — bare per-OS binary (secrets encryption, pairs with age)
  case "$T" in win-x64) SO="\\.amd64\\.exe";; linux-x64) SO="\\.linux\\.amd64";; darwin-x64) SO="\\.darwin\\.amd64";; darwin-arm64) SO="\\.darwin\\.arm64";; esac
  U="$(gh_asset getsops/sops latest "sops-.*${SO}$" 2>/dev/null)" && { case "$T" in win-x64) install_raw "$T" "$U" sops.exe;; *) install_raw "$T" "$U" sops;; esac; } || echo "    skip sops"
  # gitleaks — secret scanner
  case "$T" in win-x64) GK=windows_x64;; linux-x64) GK=linux_x64;; darwin-x64) GK=darwin_x64;; darwin-arm64) GK=darwin_arm64;; esac
  U="$(gh_asset gitleaks/gitleaks latest "gitleaks_.*_${GK}\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" gitleaks || echo "    skip gitleaks"
  # rclone — cloud + local file sync (rsync-style, but cross-platform)
  case "$T" in win-x64) RC=windows-amd64;; linux-x64) RC=linux-amd64;; darwin-x64) RC=osx-amd64;; darwin-arm64) RC=osx-arm64;; esac
  U="$(gh_asset rclone/rclone latest "rclone-.*-${RC}\\.zip$" 2>/dev/null)" && install_archive "$T" "$U" rclone || echo "    skip rclone"
  # syncthing — continuous file sync with a local web UI
  case "$T" in win-x64) SY=windows-amd64;; linux-x64) SY=linux-amd64;; darwin-x64) SY=macos-amd64;; darwin-arm64) SY=macos-arm64;; esac
  U="$(gh_asset syncthing/syncthing latest "syncthing-${SY}-v.*\\.(tar\\.gz|zip)$" 2>/dev/null)" && install_archive "$T" "$U" syncthing || echo "    skip syncthing"
  # 7-Zip (7zz) — unix from the .tar.xz; Windows is an installer, handled after the loop
  case "$T" in linux-x64) Z7=linux-x64;; darwin-x64|darwin-arm64) Z7=mac;; *) Z7="";; esac
  { [ -n "$Z7" ] && U="$(gh_asset ip7z/7zip latest "^7z.*-${Z7}\\.tar\\.xz$" 2>/dev/null)" && install_archive "$T" "$U" 7zz; } || echo "    skip 7zip on $T (Windows handled after the loop)"
  # ffmpeg + ffprobe — bare binaries; the Windows asset carries no .exe suffix
  case "$T" in win-x64) FT=win32-x64;; linux-x64) FT=linux-x64;; darwin-x64) FT=darwin-x64;; darwin-arm64) FT=darwin-arm64;; esac
  U="$(gh_asset eugeneware/ffmpeg-static latest "^ffmpeg-${FT}$"  2>/dev/null)" && { case "$T" in win-x64) install_raw "$T" "$U" ffmpeg.exe;;  *) install_raw "$T" "$U" ffmpeg;;  esac; } || echo "    skip ffmpeg"
  U="$(gh_asset eugeneware/ffmpeg-static latest "^ffprobe-${FT}$" 2>/dev/null)" && { case "$T" in win-x64) install_raw "$T" "$U" ffprobe.exe;; *) install_raw "$T" "$U" ffprobe;; esac; } || echo "    skip ffprobe"
done

# Windows 7-Zip: its release ships only an installer .exe (no plain binary), so extract
# 7z.exe + 7z.dll from it using the host's own 7zz (installed for the build platform above).
if echo " $TARGETS " | grep -q " win-x64 "; then
  H7="$OUT/bin/$HOST_T/extras/7zz"
  if [ -x "$H7" ] && ZU="$(gh_asset ip7z/7zip latest "^7z.*-x64\\.exe$" 2>/dev/null)"; then
    EW="$OUT/bin/win-x64/extras"; mkdir -p "$EW"
    zi="$STAGE/7zwin.exe"; zt="$STAGE/7zwin"; rm -rf "$zt"; mkdir -p "$zt"
    dl "$ZU" "$zi"
    "$H7" x -y -o"$zt" "$zi" >/dev/null 2>&1 || true
    for b in 7z.exe 7z.dll; do f="$(find "$zt" -name "$b" | head -1)"; [ -n "$f" ] && cp "$f" "$EW/$b"; done
    rm -rf "$zt" "$zi"
    [ -f "$EW/7z.exe" ] && echo "  [win-x64] 7-Zip: 7z.exe + 7z.dll" || echo "  [win-x64] 7-Zip: extraction failed — skipped"
  else
    echo "  [win-x64] 7-Zip skipped (host 7zz unavailable)"
  fi
fi

# ── VS Code (portable), per target ───────────────────────────────────────────
# GUI editor from the official update.code.visualstudio.com archives, into
# bin/<T>/vscode and launched via code.sh/.bat. Portable mode keeps all user data
# on the drive: a "data" dir inside the app folder (win/linux), or a sibling
# "code-portable-data" next to the .app (macOS).
say "VS Code (portable, per target)"
vscode_slug(){ case "$1" in
  win-x64)      echo win32-x64-archive ;;
  linux-x64)    echo linux-x64 ;;
  darwin-x64)   echo darwin ;;
  darwin-arm64) echo darwin-arm64 ;; esac; }
for T in $TARGETS; do
  VD="$OUT/bin/$T/vscode"
  if [ -e "$VD/bin/code" ] || [ -e "$VD/Code.exe" ] || [ -e "$VD/Visual Studio Code.app" ]; then
    echo "  [$T] vscode: present"; continue
  fi
  url="https://update.code.visualstudio.com/latest/$(vscode_slug "$T")/stable"
  case "$T" in win-x64|darwin*) arc="$STAGE/vscode-$T.zip";; *) arc="$STAGE/vscode-$T.tar.gz";; esac
  echo "  [$T] vscode: $url"
  if dl "$url" "$arc"; then
    rm -rf "$VD"; mkdir -p "$VD"
    case "$T" in
      darwin*) unzip -q "$arc" -d "$VD" ;;   # keep the "Visual Studio Code.app" bundle intact
      *)       extract "$arc" "$VD" ;;        # win: files at root; linux: flatten the top dir
    esac
    case "$T" in
      darwin*) mkdir -p "$VD/code-portable-data" ;;   # sibling of the .app -> portable mode
      *)       mkdir -p "$VD/data" ;;                  # data dir inside app folder -> portable mode
    esac
    rm -f "$arc"
  else echo "    (vscode download failed for $T — skipped)"; fi
done

# ── Windows-only tools (bin/win-x64/wintools/<tool>/, on PATH via the .bat launchers) ──
# Windows ships bare; these give native introspection. Linux/macOS already have rich
# userlands + trivial installs, so this is win-x64 only. Best-effort per tool.
if echo " $TARGETS " | grep -q " win-x64 "; then
  say "Windows tools (sysinternals, pwsh, nmap+ncat, putty, winscp, iperf3)"
  WT="$OUT/bin/win-x64/wintools"; mkdir -p "$WT"
  wt_zip(){ # <name> <url> : download a .zip and extract into wintools/<name>/
    local n="$1" url="$2" d="$WT/$1"
    [ -d "$d" ] && { echo "  $n: present"; return 0; }
    echo "  $n: ${url##*/}"; local a="$STAGE/wt-$n.zip"
    if dl "$url" "$a"; then extract "$a" "$d" || echo "    (extract failed: $n)"; rm -f "$a"
    else echo "    (download failed: $n)"; fi
  }
  wt_zip sysinternals "https://download.sysinternals.com/files/SysinternalsSuite.zip"
  wt_zip putty        "https://the.earth.li/~sgtatham/putty/latest/w64/putty.zip"
  U="$(gh_asset PowerShell/PowerShell   latest 'PowerShell-.*-win-x64\.zip$' 2>/dev/null)" && wt_zip pwsh   "$U" || echo "  skip pwsh"
  U="$(gh_asset ar51an/iperf3-win-builds latest 'iperf-.*-win64\.zip$'       2>/dev/null)" && wt_zip iperf3 "$U" || echo "  skip iperf3"
  # WinSCP portable — resolve the latest version, then fetch its portable zip
  WSV="$(curl -fsSL https://sourceforge.net/projects/winscp/best_release.json 2>/dev/null | python3 -c 'import json,sys,re;d=json.load(sys.stdin);m=re.search(r"WinSCP/([0-9.]+)/",d["release"]["filename"]);print(m.group(1) if m else "")' 2>/dev/null)" || true
  [ -n "$WSV" ] && wt_zip winscp "https://winscp.net/download/WinSCP-$WSV-Portable.zip" || echo "  skip winscp (version unresolved)"
  # Nmap + Ncat — distributed only as an NSIS installer now; extract it with the host 7zz
  H7="$OUT/bin/$HOST_T/extras/7zz"
  # resolve from the (small, fast) download page — the dist/ archive listing is huge/slow to scrape
  NMEXE="$(curl -fsSL --max-time 60 https://nmap.org/download.html 2>/dev/null | grep -oE 'nmap-[0-9.]+-setup\.exe' | head -1)" || true
  NMEXE="${NMEXE:-nmap-7.991-setup.exe}"   # pinned fallback if the page can't be fetched
  if [ -d "$WT/nmap" ]; then echo "  nmap: present"
  elif [ -x "$H7" ] && [ -n "$NMEXE" ]; then
    echo "  nmap: $NMEXE (extract via 7zz)"; ni="$STAGE/nmap-setup.exe"
    if dl "https://nmap.org/dist/$NMEXE" "$ni"; then
      mkdir -p "$WT/nmap"; "$H7" x -y -o"$WT/nmap" "$ni" >/dev/null 2>&1 || true; rm -f "$ni"
      [ -f "$WT/nmap/ncat.exe" ] && echo "    ncat.exe + nmap.exe ready" || echo "    (nmap extract incomplete)"
    fi
  else echo "  skip nmap (host 7zz or version unavailable)"; fi
fi

# ── vendor flow0 .claude (skills, app, agents, commands) — OPTIONAL ──────────
# Set FLOW0_DIR=/path/to/flow0 to bundle the flow app + skills. If it is unset or
# missing, the build still succeeds and produces a lean drive with just the CLIs
# + runtimes (no flow app / skills).
FLOW0_DIR="${FLOW0_DIR:-}"
mkdir -p "$OUT/config/.claude"
if [ -n "$FLOW0_DIR" ] && [ -d "$FLOW0_DIR/.claude" ]; then
  say "vendor $FLOW0_DIR/.claude -> config/.claude"
  rsync -a --delete \
    --exclude '.secrets/' --exclude 'node_modules/' --exclude 'venv/' --exclude '.venv/' \
    --exclude '__pycache__/' --exclude '*.pyc' --exclude 'todos/' --exclude '.browser_data/' \
    --exclude 'app/dist/' --exclude 'app/server-dist/' --exclude 'tmp/' --exclude '.DS_Store' \
    "$FLOW0_DIR/.claude/" "$OUT/config/.claude/"
elif [ -n "$FLOW0_DIR" ]; then
  echo "  WARNING: FLOW0_DIR=$FLOW0_DIR set but $FLOW0_DIR/.claude not found — skipping flow app + skills"
else
  say "no FLOW0_DIR — building without flow app + skills (CLIs + runtimes only)"
fi
# secret-provider template so the layout is discoverable (real secrets provided on the drive)
mkdir -p "$OUT/config/.claude/.secrets"
# self-guarding .gitignore: never commit anything in the secrets folder (except this rule)
printf '%s\n' '# Never commit secrets. Ignore everything in this folder except this file.' '*' '!.gitignore' \
  > "$OUT/config/.claude/.secrets/.gitignore"
[ -f "$OUT/config/.claude/.secrets/service-provider.json" ] || \
  echo '{ "network": { "unifi": {}, "fritzbox": {} } }' > "$OUT/config/.claude/.secrets/service-provider.json.example"

# Replace host-specific project paths with the portable __ROOT__ placeholder
# (launcher scripts replace __ROOT__ with the actual mount point at runtime)
if [ -f "$HERE/config/projects_list.json" ]; then
  cp "$HERE/config/projects_list.json" "$OUT/config/.claude/projects_list.json"
fi
if [ -f "$HERE/config/project_config.yaml" ]; then
  cp "$HERE/config/project_config.yaml" "$OUT/config/.claude/project_config.yaml"
fi

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
if [ -n "$FLOW0_DIR" ] && [ -f "$FLOW0_DIR/requirements.txt" ] && [ -x "$HOST_PY" ]; then
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

# ── web app — build client + compile server + prune to prod deps (only if flow app present) ──
APP="$OUT/config/.claude/app"
if [ -f "$APP/server-dist/index.js" ] && [ -f "$APP/dist/index.html" ]; then
  say "web app: already built"
elif [ -f "$APP/package.json" ]; then
  say "web app: build client + compile server + prune to prod deps"
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
chmod +x "$OUT"/*.sh 2>/dev/null || true
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

# DeepSeek env templates (API key placeholder — set DEEPSEEK_API_KEY to override)
[ -f "$OUT/config/deepseek_env.sh" ] || cp "$HERE/config/deepseek_env.sh" "$OUT/config/deepseek_env.sh" 2>/dev/null || true
[ -f "$OUT/config/deepseek_env.bat" ] || cp "$HERE/config/deepseek_env.bat" "$OUT/config/deepseek_env.bat" 2>/dev/null || true


rm -rf "$STAGE"
say "Done. Payload at: $OUT"
echo "  Run:  bash \"$OUT/start.sh\"   |   web: bash \"$OUT/start_web.sh\""
