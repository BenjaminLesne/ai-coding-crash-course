#!/usr/bin/env bash
# Sweep with an interleaved CONTROL before every candidate, so harness drift is
# visible in the results rather than silently poisoning the deltas.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/lib.sh"
SETTINGS="$HOME/.claude/settings.json"
PRISTINE="$D/settings.before.json"
OUT="$D/results2.tsv"
CAND="$D/candidates2.tsv"

restore() { cp "$PRISTINE" "$SETTINGS"; }
patch() { node -e '
const fs=require("fs"),p=process.argv[1];
const o=JSON.parse(fs.readFileSync(p,"utf8"));
const patch=JSON.parse(process.argv[2]);
for (const [k,v] of Object.entries(patch)) {
  if (v && typeof v==="object" && !Array.isArray(v) && o[k] && typeof o[k]==="object" && !Array.isArray(o[k]))
    Object.assign(o[k], v);
  else o[k]=v;
}
fs.writeFileSync(p,JSON.stringify(o,null,2));' "$SETTINGS" "$1"; }

trap restore EXIT
restore
printf 'label\tkind\tcontrol\ttotal\tdelta\n' > "$OUT"

while IFS=$'\t' read -r label kind payload; do
  [ -z "${label:-}" ] && continue
  restore
  ctl=$(measure "" "")
  restore
  case "$kind" in
    env)     t=$(measure "$payload" "") ;;
    flag)    t=$(measure "" "$payload") ;;
    setting) patch "$payload"; t=$(measure "" ""); restore ;;
  esac
  if [ "$t" = "ERR" ] || [ "$t" = "NOUSAGE" ] || [ "$ctl" = "ERR" ]; then d="$t"; else d=$((t-ctl)); fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$kind" "$ctl" "$t" "$d" >> "$OUT"
  echo "$label ctl=$ctl t=$t delta=$d"
done < "$CAND"
restore
echo DONE
