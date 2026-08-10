# DeepSeek API — single source of truth for the key + endpoints.
# Sourced by claude-deepseek.sh and codex-deepseek.sh.
# Replace the placeholder with your real key (or set DEEPSEEK_API_KEY at runtime).
#
# Anthropic-compatible endpoint (Claude Code):
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY:-sk-YOUR_KEY_HERE}"
export ANTHROPIC_MODEL="deepseek-v4-pro[1m]"
export ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro[1m]"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export CLAUDE_CODE_EFFORT_LEVEL="max"

# OpenAI-compatible endpoint (Codex):
export OPENAI_BASE_URL="https://api.deepseek.com/v1"
export OPENAI_API_KEY="${DEEPSEEK_API_KEY:-sk-YOUR_KEY_HERE}"
