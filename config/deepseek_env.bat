@REM DeepSeek API — single source of truth for the key + endpoints.
@REM Called by claude-deepseek.bat and codex-deepseek.bat.
@REM Replace the placeholder with your real key (or set DEEPSEEK_API_KEY at runtime).
@REM
@REM Anthropic-compatible endpoint (Claude Code):
set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
if not defined DEEPSEEK_API_KEY set "DEEPSEEK_API_KEY=sk-YOUR_KEY_HERE"
set "ANTHROPIC_AUTH_TOKEN=%DEEPSEEK_API_KEY%"
set "ANTHROPIC_MODEL=deepseek-v4-pro[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro[1m]"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"
set "CLAUDE_CODE_EFFORT_LEVEL=max"

@REM OpenAI-compatible endpoint (Codex):
set "OPENAI_BASE_URL=https://api.deepseek.com/v1"
set "OPENAI_API_KEY=%DEEPSEEK_API_KEY%"
