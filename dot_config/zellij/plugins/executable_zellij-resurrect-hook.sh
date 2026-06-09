#!/usr/bin/env bash

# zellij-resurrect-hook.sh
# Transform resurrected Claude commands for per-pane session recovery.
# Called by Zellij via post_command_discovery_hook with $RESURRECT_COMMAND env var.
#
# Core logic: --session-id <uuid> → --resume <uuid> (per-pane recovery)
# Fallback: bare claude without --session-id → claude --continue

cmd="$RESURRECT_COMMAND"

is_claude_cmd() {
  case "$1" in
    *claude.exe\ *|*claude\ *|claude.exe|claude) return 0 ;;
    *) return 1 ;;
  esac
}

if ! is_claude_cmd "$cmd"; then
  echo "$cmd"
  exit 0
fi

binary="${cmd%% *}"
args_part="${cmd#"$binary"}"
args_part="${args_part# }"

if [ -z "$args_part" ]; then
  echo "$binary --continue"
  exit 0
fi

# Parse args: transform --session-id <uuid> into --resume <uuid>
read -ra words <<< "$args_part"
found_session_id=false
uuid=""
rest=()
skip_next=false

for ((i = 0; i < ${#words[@]}; i++)); do
  if $skip_next; then
    skip_next=false
    continue
  fi
  if [[ "${words[i]}" == "--session-id" && $((i + 1)) -lt ${#words[@]} ]]; then
    uuid="${words[i + 1]}"
    found_session_id=true
    skip_next=true
  else
    rest+=("${words[i]}")
  fi
done

if $found_session_id && [ -n "$uuid" ]; then
  if [ ${#rest[@]} -gt 0 ]; then
    echo "$binary --resume $uuid ${rest[*]}"
  else
    echo "$binary --resume $uuid"
  fi
  exit 0
fi

# Already resumable → leave unchanged (avoids duplicating --continue each serialization)
for word in "${words[@]}"; do
  if [[ "$word" == "--continue" || "$word" == "--resume" ]]; then
    echo "$cmd"
    exit 0
  fi
done

# No --session-id found → add --continue
echo "$binary --continue $args_part"
