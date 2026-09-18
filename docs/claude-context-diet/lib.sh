#!/usr/bin/env bash
# Shared measurement helper.
#   measure "<ENV=val or empty>" "<extra claude args or empty>"
# Detects the new transcript by FILENAME, not mtime: the calling session's own
# transcript is rewritten continuously and would always look newest.
CLAUDE=/Users/benjamin/.local/bin/claude
PROJ="$HOME/.claude/projects/-Users-benjamin-pro-learning-ai-coding-crash-course"

measure() {
  local envassign="${1:-}" extra="${2:-}" b a new i c r
  b=$(mktemp); a=$(mktemp)
  ls "$PROJ" | sort > "$b"
  if [ -n "$envassign" ]; then
    env "$envassign" "$CLAUDE" ${extra} -p "hi" >/dev/null 2>&1
  else
    "$CLAUDE" ${extra} -p "hi" >/dev/null 2>&1
  fi
  ls "$PROJ" | sort > "$a"
  new=$(comm -13 "$b" "$a" | head -1)
  rm -f "$b" "$a"
  [ -z "$new" ] && { echo ERR; return; }
  read -r i c r <<<"$(grep -o '"usage":{"input_tokens":[0-9]*,"cache_creation_input_tokens":[0-9]*,"cache_read_input_tokens":[0-9]*' "$PROJ/$new" | head -1 | grep -o '[0-9]*' | tr '\n' ' ')"
  [ -z "${i:-}" ] && { echo NOUSAGE; return; }
  echo $((i+c+r))
}
