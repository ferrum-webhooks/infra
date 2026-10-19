#!/usr/bin/env bash
# One benchmark run: clean data -> k6 -> wait for drain -> reconcile. Appends a row to $OUT/results.txt.
#   infra/bench/run.sh LABEL [k6 -e options...]      e.g.  run.sh "closed-50" -e MODE=closed -e VUS=50 -e DURATION=30s
# Stack settings (GW_WORKERS, WORKERS, OTEL_*...) must be exported BEFORE `stack.sh up/restart`.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-/tmp/ferrum-bench/out}"; mkdir -p "$OUT"
label="$1"; shift
slug="$(echo "$label" | tr -c 'A-Za-z0-9._-\n' '_')"
"$HERE/../local/stack.sh" clean </dev/null >/dev/null 2>&1
k6 run -q "$@" --summary-export "$OUT/$slug.json" "$HERE/ingest.js" >"$OUT/$slug.k6.txt" 2>&1
dur="30"; for a in "$@"; do case "$a" in DURATION=*) dur="${a#DURATION=}"; dur="${dur%s}";; esac; done
python3 "$HERE/summarize.py" "$OUT/$slug.json" "$label" "$dur" | tee -a "$OUT/results.txt"
if [ -z "${NO_RECONCILE:-}" ]; then "$HERE/reconcile.sh" >"$OUT/$slug.reconcile.txt" 2>&1; fi
[ -n "${NO_RECONCILE:-}" ] && exit 0
grep -E "deliveries success|duplicate|unpublished|>1 attempt|p50|events  " "$OUT/$slug.reconcile.txt" | sed 's/^/    /'
