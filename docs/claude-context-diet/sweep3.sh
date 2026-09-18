#!/usr/bin/env bash
# Combination sweep: each row is envs \t flags \t settings-patch ("-" = none).
# A control run precedes every candidate.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
CLAUDE=/Users/benjamin/.local/bin/claude
PROJ="$HOME/.claude/projects/-Users-benjamin-pro-learning-ai-coding-crash-course"
SETTINGS="$HOME/.claude/settings.json"
PRISTINE="$D/settings.before.json"
OUT="$D/results3.tsv"

run() { # $1=envs $2=flags
  local b a new i c r
  b=$(mktemp); a=$(mktemp); ls "$PROJ" | sort > "$b"
  if [ -n "$1" ] && [ "$1" != "-" ]; then env $1 "$CLAUDE" $2 -p "hi" >/dev/null 2>&1
  else "$CLAUDE" $2 -p "hi" >/dev/null 2>&1; fi
  ls "$PROJ" | sort > "$a"; new=$(comm -13 "$b" "$a" | head -1); rm -f "$b" "$a"
  [ -z "$new" ] && { echo ERR; return; }
  read -r i c r <<<"$(grep -o '"usage":{"input_tokens":[0-9]*,"cache_creation_input_tokens":[0-9]*,"cache_read_input_tokens":[0-9]*' "$PROJ/$new" | head -1 | grep -o '[0-9]*' | tr '\n' ' ')"
  [ -z "${i:-}" ] && { echo NOUSAGE; return; }
  echo $((i+c+r))
}
restore() { cp "$PRISTINE" "$SETTINGS"; }
patch() { node -e '
const fs=require("fs"),p=process.argv[1];
const o=JSON.parse(fs.readFileSync(p,"utf8"));
for (const [k,v] of Object.entries(JSON.parse(process.argv[2]))) {
  if (v && typeof v==="object" && !Array.isArray(v) && o[k] && typeof o[k]==="object" && !Array.isArray(o[k])) Object.assign(o[k],v);
  else o[k]=v;
}
fs.writeFileSync(p,JSON.stringify(o,null,2));' "$SETTINGS" "$1"; }

trap restore EXIT
printf 'label\tcontrol\ttotal\tdelta\n' > "$OUT"
while IFS=$'\t' read -r label envs flags patchjson; do
  [ -z "${label:-}" ] && continue
  restore; ctl=$(run "-" "")
  restore
  [ "$patchjson" != "-" ] && patch "$patchjson"
  [ "$flags" = "-" ] && flags=""
  t=$(run "$envs" "$flags")
  restore
  if [ "$t" = ERR ] || [ "$t" = NOUSAGE ]; then d=$t; else d=$((t-ctl)); fi
  printf '%s\t%s\t%s\t%s\n' "$label" "$ctl" "$t" "$d" >> "$OUT"
  echo "$label ctl=$ctl t=$t delta=$d"
done < "$D/candidates3.tsv"
restore; echo DONE
