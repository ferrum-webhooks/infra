#!/usr/bin/env bash
# End-to-end (ingest -> delivered) latency with the whole system running: event created -> first successful delivery attempt,
# read from the database, at a fixed arrival rate, for 1, 2 and 4 worker processes (2 gateway processes).
#   infra/bench/e2e_latency.sh [rate=300]        ~6 minutes
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/../local/stack.sh"
RATE="${1:-300}"; export OUT="${OUT:-/tmp/ferrum-bench/e2e}"; mkdir -p "$OUT"; export GW_WORKERS=2
for w in 1 2 4; do
  WORKERS=$w "$S" restart worker </dev/null >/dev/null
  "$S" restart gateway </dev/null >/dev/null
  "$HERE/run.sh" "e2e workers=$w rate=$RATE" -e MODE=open -e RATE=$RATE -e USERS=100 -e VUS=200 -e WARMUP=3s -e DURATION=30s </dev/null
done
echo "## done"
