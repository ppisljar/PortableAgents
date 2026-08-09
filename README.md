# PortableClaude

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
PortableClaude/
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

## Build

```bash
# on macOS or Linux, with flow0 at ~/_code/_flow0 (or set FLOW0_DIR)
bash build.sh /Volumes/MY_USB          # build directly onto a drive
bash build.sh ./dist                   # or stage locally first
```
Downloads Node/Python/Git/Chrome for all four targets, installs Claude+Codex, `pip install`s the
skills' requirements into the portable Python, vendors `flow0/.claude` (excluding secrets), and
builds the web app. Re-running is incremental (skips what's already present).

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
v1 scaffold. The launchers + layout are complete; a full `build.sh` run (which downloads the
runtimes for all four platforms) is the validation step — see inline notes in `build.sh` for the
per-platform asset resolution.
