# PortableClaude — run context

You are running from a **portable drive** (Claude Code + Codex, with bundled Node, Python, Git and
Chrome) on a host machine that is not yours.

- **Leave no trace on the host.** All config, cache and temp live on the drive (already redirected by
  the launcher). Don't write outside the drive or the current project unless asked.
- **Use the bundled runtimes** already on PATH: `node`, `npm`, `python`/`python3`, `git`, and Chrome
  at `$CHROME_BIN` (browser-automation skills should use this executable).
- **Skills** come from this drive's `.claude/skills`. Credentials load from the secret provider
  (`.claude/.secrets/service-provider.json`) — provided per-drive, never committed.
- Be careful with destructive commands on the host system; confirm before touching anything outside
  the working directory.
