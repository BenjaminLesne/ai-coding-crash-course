#!/usr/bin/env bash
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/lib.sh"
echo "${1:-unlabeled}	total=$(measure "${2:-}")"
