# PortableAgents

Run **Claude Code + OpenAI Codex** from a portable drive, on **Windows, Linux, and macOS
(Intel + Apple Silicon)**. No install on the host; everything (runtimes, config, cache) lives on the
drive.

**Two build modes:**
- **Lean (default):** the CLIs + portable runtimes (Node/Git/Python/Chrome), the extra CLI tools, and portable VS Code. Nothing else needed — clone and build.
- **Full (opt-in):** set `FLOW0_DIR=/path/to/flow0` to also bundle the **flow0 `.claude`** (skills, agents, commands) and the **Claude session-viewer web app**.

Inspired by [portable-agent-usb](https://github.com/bnovik0v/portable-agent-usb), extended with:
macOS support, **portable Git**, **portable Python**, **standalone Chrome**, the flow0 skill set,
and a bundled web app with a `start_web` launcher.

## What's bundled (per platform)

| Runtime | Source | Why |
|---|---|---|
| **Node.js** | nodejs.org portable builds | Claude/Codex CLIs **and** the web app |
| **Python** | `astral-sh/python-build-standalone` (relocatable CPython) | the **skills** (`secrets_loader.py`, `unifi`, `fritzbox`, `service_provider/*`, `requirements.txt`) |
| **Git** | `desktop/dugite-native` (relocatable git) | version control from the drive (no system git needed) |
| **Chrome** | Google **Chrome for Testing** | browser-automation skills (playwright/patchright, scraping) |
| **Claude Code** | npm `@anthropic-ai/claude-code` | the agent |
| **Codex** | npm `@openai/codex` | the agent |
| **VS Code** | official portable archives (`update.code.visualstudio.com`) | GUI editor, launched via `code.sh/.bat` (portable data on the drive) |
| **Extra CLIs** | latest GitHub releases (see below) | agent/dev conveniences on PATH |

Targets: `linux-x64`, `win-x64`, `darwin-x64`, `darwin-arm64`.

### Extra CLI tools (`bin/<target>/extras`, on PATH)

Relocatable single binaries pulled from each project's **latest** GitHub release and
prepended to PATH by the launchers:

| Tool | Purpose |
|---|---|
| **ripgrep** (`rg`) / **fd** | fast code + file search |
| **bat** | syntax-highlighted `cat` |
| **jq** / **yq** | JSON / YAML-TOML-XML processing in scripts |
| **uv** (+ `uvx`) | fast Python env/dependency manager (pairs with the bundled Python) |
| **gh** | GitHub CLI (PRs, issues, releases) |
| **delta** | side-by-side git diffs |
| **micro** | friendly terminal editor |
| **glow** | render markdown in the terminal |
| **pandoc** | document conversion (backs the docx/pdf/pptx skills) |
| **ffmpeg** / **ffprobe** | media processing |
| **dust** | disk-usage explorer (handy on the drive itself) |
| **7-Zip** (`7zz`, `7z.exe`) | archive create/extract |
| **age** (+ `age-keygen`) / **sops** | file & secrets encryption |
| **gitleaks** | scan for committed secrets |
| **rclone** | cloud + local file sync (cross-platform, rsync-style) |
| **syncthing** | continuous file sync with a local web UI |

A few tools have no build for every target, so they're skipped there (the build still
succeeds): **fd, delta, micro** have no Intel-mac (`darwin-x64`) release, and **dust** has
no Apple-silicon (`darwin-arm64`) release. **7-Zip** ships only an installer on Windows, so
its `7z.exe`/`7z.dll` are extracted from that installer using the host's own `7zz` at build
time. Extras add ~1.5 GB per full build (pandoc ~190 MB and ffmpeg ~80 MB dominate),
plus bundled VS Code at ~130 MB/target (~520 MB across all four).

### Windows-only tools (`bin/win-x64/wintools/`, on PATH via the `.bat` launchers)

Windows ships bare, so — only for the `win-x64` target — the build also bundles native
introspection tooling (Linux/macOS already have rich userlands + trivial installs, so they
skip this). The `.bat` launchers add each `wintools/<tool>/` dir to PATH automatically.

| Tool | Purpose |
|---|---|
| **Sysinternals Suite** | Process Explorer, Procmon, Autoruns, TCPView, Handle, Sigcheck, Strings, PsTools, … |
| **PowerShell 7** (`pwsh`) | modern shell (not the built-in `powershell.exe`) |
| **Nmap + Ncat** | port scanning + netcat (extracted from the Nmap installer; raw-packet scans need Npcap on the host) |
| **PuTTY** (`putty/plink/pscp/psftp`) | SSH/serial client suite |
| **WinSCP** | portable SCP/SFTP GUI |
| **iperf3** | network throughput testing |

Note: the bundled **git-for-windows** already puts a unix userland on Windows (`bash`, `grep`,
`sed`, `awk`, `ssh`, `scp`, `vim`, `less`), and the cross-platform `extras` (`rg fd jq yq curl
7z gh …`) are on PATH too — so this fills the *Windows-native* gap, not unix basics.
(Eric Zimmerman's DFIR tools are intentionally not bundled: they need the .NET runtime
installed on the host, so they aren't self-contained.)

### Is the web app self-contained? Yes — Node only.
`.claude/app` (`claude-session-viewer`) is **fully Node.js** — a Vite/React client + a `tsx`/Node
server (`server/index.ts`). `start_web` uses only the portable Node; **it needs no Python**. Python is
bundled for the *skills*, not the web app.

## Layout

```
PortableAgents/
  build.sh              # builder: downloads runtimes for all targets, installs agents; optionally vendors flow0/.claude + builds the web app (FLOW0_DIR)
  deploy.sh             # deploys built payload onto a drive (exFAT or native filesystem)
  versions.env          # pinned versions (edit + rebuild to bump)
  launchers/            # copied to the drive root by build.sh
    start.sh/.bat         # interactive shell — claude/codex/git/python/node/chrome on PATH
    start_web.sh/.bat     # launch the session-viewer web app
    claude.sh/.bat        # start Claude Code directly (Anthropic API)
    codex.sh/.bat         # start Codex directly (OpenAI API)
    chrome.sh/.bat        # launch the bundled Chrome (drive-local profile)
    code.sh/.bat          # launch the bundled VS Code (portable data on the drive)
    claude-deepseek.sh/.bat  # start Claude Code via DeepSeek's Anthropic-compatible endpoint
    codex-deepseek.sh/.bat   # start Codex via DeepSeek's OpenAI-compatible endpoint
  config/
    projects_list.json   # project template with __ROOT__ placeholder (launchers patch it at runtime)
    project_config.yaml  # project config template with __ROOT__ placeholder
    env.sh / env.bat     # API key placeholders for Anthropic + OpenAI (edit with your keys)
    deepseek_env.sh/.bat # DeepSeek API key + endpoint config (edit with your key)
    CLAUDE.md            # portable-run guidance for the agent
  dist/ bin/ tools/     # build outputs (gitignored): the actual portable payload
                        #   bin/<target>/extras/ = rg fd bat jq yq uv gh delta micro glow pandoc ffmpeg dust 7zz age sops gitleaks rclone syncthing
                        #   bin/<target>/{chrome,vscode}/ = bundled GUI apps (launched via chrome.* / code.*)
                        #   bin/win-x64/wintools/ = Windows-only tools (sysinternals, pwsh, nmap+ncat, putty, winscp, iperf3)
```

The **repo** holds scripts + config templates; the heavy binaries are downloaded into `dist/` at build
time (or straight onto your USB), so they're never committed. `config/.claude/` (vendored from flow0
when `FLOW0_DIR` is set) is gitignored, as are any `.secrets/` and `skills/` folders.

## How to build

### Prerequisites
- macOS or Linux (the build host)
- `curl`, `tar`, `unzip`, `python3`, `rsync`
- **Optional (full mode only):** a `flow0` checkout — set `FLOW0_DIR=/path/to/flow0` to bundle its `.claude` skills/agents/app. Omit it for a lean CLIs-only drive.
- ~9 GB free disk space (all 4 platforms, incl. extra CLIs + VS Code)

### Build & deploy

Build to a normal filesystem first (the build needs symlinks), then deploy onto your drive:

```bash
# 1. Build the payload (~9 GB, downloads runtimes + extra CLIs + VS Code + installs agents)
bash build.sh ./dist

# 2. Deploy to drive
bash deploy.sh ./dist /Volumes/USB --exfat  # exFAT USB: flatten symlinks (portable, larger)
bash deploy.sh ./dist /mnt/ext              # APFS/ext4/NTFS: keep links (compact)
```

`build.sh` downloads Node/Python/Git/Chrome for all four targets and cross-installs Claude+Codex.
**If `FLOW0_DIR` is set** to a flow0 checkout, it also vendors `flow0/.claude` (excluding secrets),
installs the skills' Python deps as **per-platform wheels** (offline on every OS), and builds the web
app (static client + compiled Node server). **If `FLOW0_DIR` is unset**, all of that is skipped and
you get a lean drive with just the CLIs + runtimes. Re-running is incremental (skips what's already built).

### What the build copies

| Source | Destination on drive | Notes |
|--------|---------------------|-------|
| `launchers/*` | drive root | All .sh/.bat launchers |
| `config/projects_list.json` | `config/.claude/` | With `__ROOT__` placeholder → patched at runtime |
| `config/project_config.yaml` | `config/.claude/` | With `__ROOT__` placeholder → patched at runtime |
| `config/CLAUDE.md` | `config/` | Agent run-context instructions |
| Flow0 `.claude/` *(only if `FLOW0_DIR` set)* | `config/.claude/` | Skills, agents, app, commands (secrets excluded) |
| Generated `env.sh/.bat` | `config/` | API key placeholders (only if not already present) |
| `config/deepseek_env.sh/.bat` | `config/` | DeepSeek config (only if not already present) |

## How to set secrets

The drive ships with **placeholder keys only** — you must add your own. There are three ways:

### 1. API key env files (simplest)

Edit these files on the drive after build:

**`config/env.sh`** / **`config/env.bat`** — for default Anthropic + OpenAI:
```bash
# config/env.sh — edit with your real keys:
export ANTHROPIC_API_KEY="sk-ant-api03-your-real-key"
export OPENAI_API_KEY="sk-your-real-openai-key"
```

**`config/deepseek_env.sh`** / **`config/deepseek_env.bat`** — for DeepSeek:
```bash
# config/deepseek_env.sh — edit with your real key:
# Either set DEEPSEEK_API_KEY before running, or replace the placeholder below:
export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-sk-YOUR_KEY_HERE}"  # ← replace
```

On Windows, the `.bat` equivalents use `set "KEY=value"` syntax.

### 2. Environment variable (no file edit)

Set `DEEPSEEK_API_KEY` before launching, e.g.:
```bash
DEEPSEEK_API_KEY="sk-your-key" bash claude-deepseek.sh -p "hello"
```
The deepseek env files check this variable first, so the file's placeholder is ignored.

### 3. OAuth login (Claude only, no key needed)

If no API key is set in `config/env.sh`, Claude Code will prompt a browser-based OAuth login on
first use. The token is stored on the drive (in `config/.claude/`) and reused across sessions.

### 4. Service provider secrets (for skills)

The skills (UniFi, FRITZ!Box, Eclipso email, etc.) read credentials from
`config/.claude/.secrets/service-provider.json`. This file is **never committed** and excluded from
the build. Create it on your drive manually:

```json
{
  "network": {
    "unifi": { "url": "https://192.168.1.1", "username": "admin", "password": "..." },
    "fritzbox": { "url": "http://192.168.178.1", "password": "..." }
  },
  "email": {
    "eclipso": { "email": "you@eclipso.eu", "password": "...", "imap": "...", "smtp": "..." }
  }
}
```

A minimal template is at `config/.claude/.secrets/service-provider.json.example` on the drive.

### Security notes

- **Never commit real keys.** The repo templates all use `YOUR_KEY_HERE` placeholders.
- The drive's `.gitignore` excludes `config/.claude/` (which contains the OAuth token and secrets).
- `build.sh` explicitly excludes `.secrets/` when vendoring flow0's `.claude`.
- On a shared machine, treat the drive like a password manager — anyone with physical access can read the files.

## How to use

### Quick reference

| Launcher | API backend | Auth | When to use |
|----------|------------|------|-------------|
| `start.sh` / `start.bat` | Interactive shell | OAuth or env keys | General dev work, exploring |
| `start_web.sh` / `start_web.bat` | N/A | N/A | View conversations, diagrams |
| `claude.sh` / `claude.bat` | Anthropic | OAuth or env key | Direct Claude Code sessions |
| `codex.sh` / `codex.bat` | OpenAI | Env key | Direct Codex sessions |
| `chrome.sh` / `chrome.bat` | N/A | N/A | Launch bundled Chrome (portable profile) |
| `code.sh` / `code.bat` | N/A | N/A | Launch bundled VS Code (portable data) |
| `claude-deepseek.sh` / `.bat` | DeepSeek (Anthropic-compatible) | DeepSeek key | Claude via DeepSeek |
| `codex-deepseek.sh` / `.bat` | DeepSeek (OpenAI-compatible) | DeepSeek key | Codex via DeepSeek |

### Agent shell
```bash
bash start.sh                          # macOS/Linux: interactive shell
# Inside the shell: claude, codex, git, python, node, chrome all on PATH

# Or pass a prompt directly:
bash claude.sh -p "explain this code"
bash codex.sh "refactor this function"
bash claude-deepseek.sh -p "review this PR"
```

On Windows, double-click `start.bat` or run `claude.bat`, `codex.bat`, etc. from Command Prompt.

### Web app
```bash
bash start_web.sh                      # macOS/Linux
# → http://localhost:3001 (or the URL printed in the terminal)
```
On Windows, double-click `start_web.bat`.

### Switching API providers on the fly

The `claude.sh` and `codex.sh` launchers use whatever API keys are in `config/env.sh`.
To temporarily use DeepSeek, use the `*-deepseek.sh` launchers instead — they source
`config/deepseek_env.sh` which points at DeepSeek's endpoints.

You can also override the env file path:
```bash
CLAUDE_ENV="$PWD/config/deepseek_env.sh" bash claude.sh -p "hello"   # Claude via DeepSeek
CODEX_ENV="$PWD/config/custom.sh" bash codex.sh "explain"            # Codex via custom endpoint
```

### How project paths stay portable

The drive can be mounted anywhere — `/Volumes/KINGSTON` on macOS, `/media/usb` on Linux, `E:\`
on Windows. All launchers detect the mount point at startup and patch `projects_list.json`
and `project_config.yaml` by replacing the `__ROOT__` placeholder with the actual path. No
manual config editing needed when moving between machines.

## Status
**Built and validated on macOS** (full `build.sh` run, payload ≈ 6 GB). Confirmed working:
- Node/Python/Git/Chrome downloaded for all 4 targets; Claude Code + Codex installed for all 4.
- Bundled CLIs run on the host: Claude Code 2.1.226, Codex 0.147.0, git 2.47.1 (dugite), node
  v22.14.0, python 3.12.9.
- Python skill deps installed as per-platform wheels on all 4 targets.
- Web app builds and serves (`/` → 200, `/api/health` → 200) from the compiled Node server.
- 22 skills vendored; `.secrets` excluded.

Notes:
- Running the CLIs on the *other* three platforms is only fully verifiable on those OSes, but the
  payloads are assembled cross-platform the same proven way as the reference project.
- flow0's `requirements.txt` pins `pyyaml==6.0.3`, which doesn't exist on PyPI — the build skips it
  gracefully (pyyaml still lands transitively). Worth fixing the pin in flow0.
