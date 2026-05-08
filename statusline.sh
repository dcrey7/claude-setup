#!/usr/bin/env bash
# Claude Code status line — colorized, accurate token counts from transcript
# Output: <model>  |  <used>/<window> [bar] <pct>%  |  $<cost>

input=$(cat)

# ANSI colors
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_CYAN=$'\033[38;5;51m'
C_BLUE=$'\033[38;5;39m'
C_GREEN=$'\033[38;5;42m'
C_YELLOW=$'\033[38;5;220m'
C_RED=$'\033[38;5;203m'
C_MAGENTA=$'\033[38;5;213m'
C_GREY=$'\033[38;5;245m'

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_id=$(echo "$input" | jq -r '.model.id // ""')

# --- context window size: prefer payload, infer 1M from "[1m]" model ids, else 200k ---
win_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -z "$win_size" ] || [ "$win_size" = "0" ]; then
  if echo "$model_id" | grep -qi '\[1m\]\|-1m\b\|1m$'; then
    win_size=1000000
  else
    win_size=200000
  fi
fi

# --- token usage: prefer transcript (most accurate), fall back to payload ---
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
in_t=0; out_t=0; total_used=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  # Latest assistant message with usage — pull each field separately
  read -r in_t out_t <<<"$(tac "$transcript" 2>/dev/null | \
    jq -r 'select(.message.usage) | .message.usage
           | "\((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)) \(.output_tokens // 0)"' \
    2>/dev/null | head -n1)"
  [ -z "$in_t"  ] && in_t=0
  [ -z "$out_t" ] && out_t=0
fi

if [ "$in_t" = "0" ] && [ "$out_t" = "0" ]; then
  in_t=$(echo "$input"  | jq -r '.context_window.total_input_tokens  // 0')
  out_t=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
fi
total_used=$(( in_t + out_t ))

# Percentage
if [ "$win_size" -gt 0 ]; then
  used_pct=$(echo "scale=2; $total_used * 100 / $win_size" | bc)
else
  used_pct=0
fi

# Human-readable token formatting
fmt_tokens() {
  local n=$1
  if   [ "$n" -ge 1000000 ]; then printf "%.2fM" "$(echo "scale=2; $n / 1000000" | bc)"
  elif [ "$n" -ge 1000    ]; then printf "%.1fk" "$(echo "scale=1; $n / 1000"    | bc)"
  else printf "%d" "$n"
  fi
}
used_fmt=$(fmt_tokens "$total_used")
win_fmt=$(fmt_tokens "$win_size")
in_fmt=$(fmt_tokens "$in_t")
out_fmt=$(fmt_tokens "$out_t")

# Progress bar (20 chars) with color tiers
filled=$(printf "%.0f" "$(echo "scale=2; $used_pct / 5" | bc)")
[ "$filled" -lt 0  ] && filled=0
[ "$filled" -gt 20 ] && filled=20
empty=$(( 20 - filled ))

pct_int=$(printf "%.0f" "$used_pct")
if   [ "$pct_int" -ge 85 ]; then bar_color=$C_RED
elif [ "$pct_int" -ge 60 ]; then bar_color=$C_YELLOW
else                              bar_color=$C_GREEN
fi

bar=""
for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
empty_bar=""
for (( i=0; i<empty;  i++ )); do empty_bar="${empty_bar}░"; done

pct_str=$(printf "%.1f%%" "$used_pct")

# --- cost ---
cost_raw=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_str=$(printf '$%.4f' "$cost_raw")

# --- assemble ---
sep="${C_GREY}│${C_RESET}"
printf "%s  %s  %b↑%s %b↓%s%b  %s  %b%s%b%b/%b%b%s%b %b(%s)%b  %s  %b%s%b\n" \
  "$model" \
  "$sep" \
  "$C_BLUE" "$in_fmt" "$C_CYAN" "$out_fmt" "$C_RESET" \
  "$sep" \
  "$bar_color" "$used_fmt" "$C_RESET" \
  "$C_DIM" "$C_RESET" "$C_GREY" "$win_fmt" "$C_RESET" \
  "$bar_color" "$pct_str" "$C_RESET" \
  "$sep" \
  "$C_MAGENTA" "$cost_str" "$C_RESET"
