#!/usr/bin/env bash
# Ingest scaling, isolated (no worker): (1) throughput vs number of gateway processes (closed model, 100 clients);
# (2) latency vs offered load (open model, constant arrival rate) with 4 gateway processes: finds the knee.
#   infra/bench/scaling.sh [reps=3]        ~12 minutes
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/../local/stack.sh"
REPS="${1:-3}"; export OUT="${OUT:-/tmp/ferrum-bench/scale}"; mkdir -p "$OUT"; export NO_RECONCILE=1
"$S" kill9 worker </dev/null
for rep in $(seq "$REPS"); do
  for w in 1 2 4 8; do
    GW_WORKERS=$w "$S" restart gateway </dev/null >/dev/null
    "$HERE/run.sh" "gw$w VUS=100 rep=$rep" -e MODE=closed -e VUS=100 -e USERS=100 -e WARMUP=3s -e DURATION=20s </dev/null >/dev/null
  done
done
GW_WORKERS=4 "$S" restart gateway </dev/null >/dev/null
for rate in 300 600 900 1200 1500; do
  "$HERE/run.sh" "open-gw4 VUS=$rate rep=1" -e MODE=open -e RATE=$rate -e USERS=100 -e VUS=300 -e WARMUP=3s -e DURATION=20s </dev/null >/dev/null
done
echo "## done"
