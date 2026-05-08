#!/usr/bin/env bash
# claude-setup uninstaller: removes the status line + settings this repo installed.
# By default does NOT uninstall Claude Code itself — pass --remove-claude to also do that.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
REMOVE_CLAUDE=0
for arg in "$@"; do
  case "$arg" in
    --remove-claude) REMOVE_CLAUDE=1 ;;
    -h|--help)
      echo "Usage: ./uninstall.sh [--remove-claude]"
      echo "  --remove-claude  Also uninstall the Claude Code CLI (npm uninstall -g)"
      exit 0
      ;;
  esac
done

C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'
info() { printf "%s==>%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s!!%s %s\n"  "$C_YELLOW" "$C_RESET" "$*"; }

# 1. Remove the status line script
if [ -f "$CLAUDE_DIR/statusline.sh" ]; then
  info "Removing $CLAUDE_DIR/statusline.sh"
  rm -f "$CLAUDE_DIR/statusline.sh"
else
  warn "No statusline.sh found at $CLAUDE_DIR — skipping"
fi

# 2. Restore the most recent settings backup if one exists, else remove settings.json
latest_bak=$(ls -1t "$CLAUDE_DIR"/settings.json.bak.* 2>/dev/null | head -n1 || true)
if [ -n "$latest_bak" ]; then
  info "Restoring previous settings from $(basename "$latest_bak")"
  mv "$latest_bak" "$CLAUDE_DIR/settings.json"
elif [ -f "$CLAUDE_DIR/settings.json" ]; then
  warn "No backup found — removing $CLAUDE_DIR/settings.json"
  rm -f "$CLAUDE_DIR/settings.json"
fi

# 3. Optionally uninstall Claude Code itself
if [ "$REMOVE_CLAUDE" -eq 1 ]; then
  if command -v npm >/dev/null 2>&1 && command -v claude >/dev/null 2>&1; then
    info "Uninstalling Claude Code (npm uninstall -g @anthropic-ai/claude-code)"
    npm uninstall -g @anthropic-ai/claude-code || warn "npm uninstall failed — remove manually"
  else
    warn "claude or npm not on PATH — skipping Claude Code uninstall"
  fi
fi

info "Done."
