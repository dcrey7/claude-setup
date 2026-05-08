#!/usr/bin/env bash
# claude-setup installer: installs Claude Code (if missing) and applies my config + status line.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
info() { printf "%s==>%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s!!%s %s\n"  "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf "%sxx%s %s\n"  "$C_RED" "$C_RESET" "$*" >&2; }

# 1. Install Claude Code if not already installed
if command -v claude >/dev/null 2>&1; then
  info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'present')"
else
  info "Installing Claude Code…"
  if command -v npm >/dev/null 2>&1; then
    npm install -g @anthropic-ai/claude-code
  else
    err "npm not found. Install Node.js (https://nodejs.org) and re-run this script,"
    err "or install Claude Code manually: https://docs.claude.com/en/docs/claude-code/setup"
    exit 1
  fi
fi

# 2. Make sure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# 3. Back up existing settings.json if present and different
if [ -f "$CLAUDE_DIR/settings.json" ] && ! cmp -s "$CLAUDE_DIR/settings.json" "$REPO_DIR/settings.json"; then
  ts=$(date +%Y%m%d-%H%M%S)
  warn "Existing settings.json found — backing up to settings.json.bak.$ts"
  cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak.$ts"
fi

# 4. Install settings + status line
info "Installing settings.json -> $CLAUDE_DIR/settings.json"
cp "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"

info "Installing statusline.sh -> $CLAUDE_DIR/statusline.sh"
cp "$REPO_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"

# 5. Heads-up if jq/bc are missing — the status line uses them
missing=()
for bin in jq bc; do
  command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ "${#missing[@]}" -gt 0 ]; then
  warn "Status line needs: ${missing[*]} — install with: brew install ${missing[*]}"
fi

info "Done. Run ${C_DIM}claude${C_RESET} to start."
