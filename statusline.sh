#!/usr/bin/env bash
#
# Claude Code custom statusLine — powerline style.
# Segments (left -> right): Model | Directory | Git branch/status | Usage bar
# Colors and rounded separators are matched to the user's ~/.p10k.zsh prompt.

input=$(cat)

model_name=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // ""')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0')
input_tokens=$(printf '%s' "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(printf '%s' "$input" | jq -r '.context_window.total_output_tokens // 0')
q5_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
q5_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
q7_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
q7_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Directory: last 2 path components ---
if [ -n "$cwd" ]; then
  dir_display=$(printf '%s' "$cwd" | awk -F/ '{ if (NF>=2) print $(NF-1)"/"$NF; else print $NF }')
else
  dir_display=""
fi

# --- Git branch/status (omit segment entirely if not a git repo) ---
git_bg=""
git_text=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    # trim to 30 chars, ellipsis included
    [ "${#branch}" -gt 30 ] && branch="${branch:0:29}…"
    if [ -z "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
      git_bg=2   # clean
    else
      git_bg=3   # dirty
    fi
    git_text=$'\xee\x82\xa0'" $branch"
  fi
fi

# --- Usage bar (10 blocks) + percentage + cost ---
used_int=$(printf '%.0f' "$used_pct")
[ "$used_int" -lt 0 ] && used_int=0
filled=$(( used_int / 10 ))
[ "$filled" -lt 0 ] && filled=0
[ "$filled" -gt 10 ] && filled=10
empty=$(( 10 - filled ))

bar=""
for ((i = 0; i < filled; i++)); do bar="${bar}▓"; done
for ((i = 0; i < empty; i++)); do bar="${bar}░"; done

cost_fmt=$(printf '%.2f' "$cost")

total_tokens=$(( ${input_tokens%.*} + ${output_tokens%.*} ))
tokens_fmt=$(awk -v n="$total_tokens" 'BEGIN {
  if (n >= 1000000) printf "%.1f M", n / 1000000;
  else if (n >= 1000) printf "%.1f K", n / 1000;
  else printf "%d", n;
}')

if [ "$used_int" -lt 50 ]; then
  usage_bg=2   # green
  usage_fg=0
elif [ "$used_int" -le 80 ]; then
  usage_bg=3   # yellow
  usage_fg=0
else
  usage_bg=1   # red
  usage_fg=7   # white reads better on red
fi

usage_text="${bar} ${used_int}% ${tokens_fmt} Token \$${cost_fmt}"

# --- Account quota (omit segment entirely if rate_limits is absent) ---
# fmt_reset EPOCH — time until reset: >=1d "3d", >=1h "2h:13m", >=1m "13m", else "<1m"
fmt_reset() {
  local secs=$(( ${1%.*} - $(date +%s) ))
  if [ "$secs" -ge 86400 ]; then
    printf '%dd' $(( secs / 86400 ))
  elif [ "$secs" -ge 3600 ]; then
    printf '%dh:%dm' $(( secs / 3600 )) $(( secs % 3600 / 60 ))
  elif [ "$secs" -ge 60 ]; then
    printf '%dm' $(( secs / 60 ))
  else
    printf '<1m'
  fi
}

quota_text=""
quota_max=0
for win in 5 7; do
  pct_var="q${win}_pct"; reset_var="q${win}_reset"
  pct="${!pct_var}"; reset="${!reset_var}"
  [ -z "$pct" ] && continue
  pct_int=$(printf '%.0f' "$pct")
  [ "$pct_int" -gt "$quota_max" ] && quota_max=$pct_int
  if [ "$win" = 5 ]; then icon=$'\xef\x80\x97'; else icon=$'\xef\x81\xb3'; fi
  part="${icon} ${pct_int}%"
  [ -n "$reset" ] && part="${part} ↻$(fmt_reset "$reset")"
  quota_text="${quota_text:+${quota_text} · }${part}"
done

if [ "$quota_max" -lt 50 ]; then
  quota_bg=2; quota_fg=0
elif [ "$quota_max" -le 80 ]; then
  quota_bg=3; quota_fg=0
else
  quota_bg=1; quota_fg=7
fi

# Rounded separators, matching this user's actual ~/.p10k.zsh:
#   POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''               (between segments, and as the end cap)
#   POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL='' (before the first segment)
SEP=$'\xee\x82\xb4'
CAP_START=$'\xee\x82\xb6'

# seg BG FG TEXT — prints a padded powerline block
seg() {
  printf '\033[48;5;%sm\033[38;5;%sm %s ' "$1" "$2" "$3"
}

# arrow LEFT_BG RIGHT_BG — rounded separator between two segments.
# If RIGHT_BG is empty, this is the final cap: reset background, keep fg = LEFT_BG.
arrow() {
  if [ -n "$2" ]; then
    printf '\033[48;5;%sm\033[38;5;%sm%s' "$2" "$1" "$SEP"
  else
    printf '\033[0m\033[38;5;%sm%s' "$1" "$SEP"
  fi
}

# 1) Model
printf '\033[0m\033[38;5;5m%s' "$CAP_START"
seg 5 0 "$model_name"

# 2) Directory
next_bg=4
arrow 5 4
seg 4 254 "$dir_display"

# 3) Git (optional)
if [ -n "$git_bg" ]; then
  arrow 4 "$git_bg"
  seg "$git_bg" 0 "$git_text"
  next_bg="$git_bg"
fi

# 4) Usage
arrow "$next_bg" "$usage_bg"
seg "$usage_bg" "$usage_fg" "$usage_text"

last_bg="$usage_bg"

# 5) Quota (optional)
if [ -n "$quota_text" ]; then
  arrow "$usage_bg" "$quota_bg"
  seg "$quota_bg" "$quota_fg" "$quota_text"
  last_bg="$quota_bg"
fi

# final cap, reset to terminal default background
arrow "$last_bg" ""

printf '\033[0m\n'
