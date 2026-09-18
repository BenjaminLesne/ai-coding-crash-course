#!/usr/bin/env bash
# Print the initial context of the most recently STARTED session in this repo.
# total = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# of the first assistant turn. Run it right after quitting the session you measured.
PROJ="$HOME/.claude/projects/-Users-benjamin-pro-learning-ai-coding-crash-course"
n=${1:-3}
for f in $(ls -t "$PROJ"/*.jsonl | head -"$n"); do
  read -r i c r <<<"$(grep -o '"usage":{"input_tokens":[0-9]*,"cache_creation_input_tokens":[0-9]*,"cache_read_input_tokens":[0-9]*' "$f" | head -1 | grep -o '[0-9]*' | tr '\n' ' ')"
  if [ -n "${i:-}" ]; then
    printf '%7d  %s  %s\n' $((i+c+r)) "$(date -r "$f" '+%H:%M:%S')" "$(basename "$f")"
  else
    printf '%7s  %s  %s\n' NOUSAGE "$(date -r "$f" '+%H:%M:%S')" "$(basename "$f")"
  fi
done
