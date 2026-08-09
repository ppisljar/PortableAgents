# PortableAgents

Run **Claude Code + OpenAI Codex** — plus the full **flow0 `.claude`** (skills, agents, commands)
and the **Claude session-viewer web app** — from a portable drive, on **Windows, Linux, and macOS
(Intel + Apple Silicon)**. No install on the host; everything (runtimes, config, cache) lives on the
drive.

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

Targets: `linux-x64`, `win-x64`, `darwin-x64`, `darwin-arm64`.

### Is the web app self-contained? Yes — Node only.
`.claude/app` (`claude-session-viewer`) is **fully Node.js** — a Vite/React client + a `tsx`/Node
server (`server/index.ts`). `start_web` uses only the portable Node; **it needs no Python**. Python is
bundled for the *skills*, not the web app.

## Layout

```
PortableAgents/
  build.sh            # builder: downloads runtimes for all targets, installs agents, vendors flow0/.claude, builds the web app
  versions.env        # pinned versions (edit + rebuild to bump)
  launchers/          # copied to the drive root by build.sh
    start.sh/.bat       # agent shell — `claude` / `codex` on PATH, config on the drive
    start_web.sh/.bat   # launch the session-viewer web app
  config/
    .claude/          # vendored from flow0 (skills, app, agents, commands) — built, gitignored
    CLAUDE.md         # portable-run guidance for the agent
  dist/ bin/ tools/   # build outputs (gitignored): the actual portable payload
```

The **repo** holds scripts + config; the heavy binaries are downloaded into `dist/` at build time
(or straight onto your USB), so they're never committed.

## Build & deploy

Build to a normal filesystem first (the build needs symlinks), then deploy onto your drive:

```bash
# on macOS or Linux, with flow0 at ~/_code/_flow0 (or set FLOW0_DIR)
bash build.sh ./dist                        # download + assemble everything (~6 GB, offline-ready)

# then put it on a drive:
bash deploy.sh ./dist /Volumes/USB --exfat  # exFAT USB: flatten symlinks/hardlinks (portable, larger)
bash deploy.sh ./dist /mnt/ext              # APFS/ext4/NTFS: keep links (compact)
```
`build.sh` downloads Node/Python/Git/Chrome for all four targets, cross-installs Claude+Codex,
installs the skills' Python deps as **per-platform wheels** (offline on every OS), vendors
`flow0/.claude` (excluding secrets), and builds the web app (static client + a compiled Node server).
Re-running is incremental (skips what's already built).

## Run

- **Agent shell** — `bash start.sh` (Linux/macOS) or double-click `start.bat` (Windows) → a shell
  with `claude`, `codex`, `git`, `python`, and `chrome` all on PATH, config + cache on the drive.
- **Web app** — `bash start_web.sh` (or `start_web.bat`) → serves the session viewer (opens the
  browser at the printed URL).

Auth: OAuth (log in via browser on first `claude`/`codex` use — token stored on the drive) or API
keys in `config/env.sh` / `config/env.bat`.

## Secrets
`flow0/.claude/.secrets` is **not** vendored (it's excluded from the copy). Provide credentials on the
drive via the secret provider (`config/.claude/.secrets/service-provider.json`) or env files — never
committed.

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
