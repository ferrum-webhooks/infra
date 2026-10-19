#!/usr/bin/env bash
# Delivery capacity: how fast do workers drain a backlog? Builds the backlog with NO worker running (events accumulate
# in the outbox), then starts workers and times the drain.
#   infra/bench/drain_rate.sh <sink_latency_ms> <worker_processes> <worker_concurrency> [backlog_seconds=15]
# Throughput ~ processes x concurrency / (sink_latency + per-delivery overhead), until a CPU or the database saturates.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/../local/stack.sh"
LAT="${1:?sink latency ms}"; PROCS="${2:?worker processes}"; CONC="${3:?worker concurrency}"; SECS="${4:-15}"
q() { "$S" psql -Atqc "$1"; }
"$S" clean </dev/null >/dev/null 2>&1
"$S" kill9 worker </dev/null
SINK_LATENCY_MS="$LAT" "$S" restart sink </dev/null >/dev/null
k6 run -q -e MODE=closed -e VUS=50 -e USERS=50 -e WARMUP=1s -e DURATION="${SECS}s" "$HERE/ingest.js" >/dev/null 2>&1
N=$(q "select count(*) from events")
echo "backlog: $N events accepted with no worker running (outbox unpublished: $(q "select count(*) from outbox where published_at is null"))"
t0=$(python3 -c 'import time;print(time.time())')
WORKERS="$PROCS" WORKER_CONCURRENCY="$CONC" "$S" restart worker </dev/null >/dev/null
while [ "$(q "select count(*) from deliveries where status not in ('success','dead_letter')")" != 0 ]; do sleep 0.5; done
t1=$(python3 -c 'import time;print(time.time())')
python3 - "$N" "$t0" "$t1" "$LAT" "$PROCS" "$CONC" <<'PY'
import sys
n, t0, t1, lat, procs, conc = int(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3]), sys.argv[4], sys.argv[5], sys.argv[6]
print(f"sink={lat:>3}ms  workers={procs} x concurrency={conc:>2}  drained {n} deliveries in {t1-t0:6.1f}s  =>  {n/(t1-t0):7.0f} deliveries/s")
PY
"$S" restart sink </dev/null >/dev/null
