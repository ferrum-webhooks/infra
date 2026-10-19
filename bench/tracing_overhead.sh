#!/usr/bin/env bash
# What does tracing cost? Isolated ingest (no worker), 50 closed-loop clients, interleaved repeats.
#   sampler=0     : tracing code present, nothing recorded
#   no-export     : every request recorded (ratio 1.0) but no exporter configured
#   export-10pct  : ratio 0.1 exported to a real Jaeger (docker)
#   export-100pct : ratio 1.0 exported to a real Jaeger (docker)
#   infra/bench/tracing_overhead.sh [reps=4]        needs docker
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/../local/stack.sh"
REPS="${1:-4}"; export OUT="${OUT:-/tmp/ferrum-bench/trace}"; mkdir -p "$OUT"; export GW_WORKERS=1 NO_RECONCILE=1
docker rm -f ferrum-bench-jaeger >/dev/null 2>&1
docker run -d --rm --name ferrum-bench-jaeger -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:1.62.0 >/dev/null
for _ in $(seq 40); do curl -fs localhost:16686 >/dev/null 2>&1 && break; sleep 1; done
"$S" kill9 worker </dev/null
one() { # name ratio endpoint rep
  OTEL_TRACES_SAMPLER_RATIO="$2" OTEL_EXPORTER_OTLP_ENDPOINT="$3" "$S" restart gateway </dev/null >/dev/null
  "$HERE/run.sh" "$1 VUS=50 rep=$4" -e MODE=closed -e VUS=50 -e USERS=50 -e WARMUP=3s -e DURATION=20s </dev/null >/dev/null
}
for rep in $(seq "$REPS"); do
  one sampler-0     0   ""                      "$rep"
  one no-export     1.0 ""                      "$rep"
  one export-10pct  0.1 "http://127.0.0.1:4318" "$rep"
  one export-100pct 1.0 "http://127.0.0.1:4318" "$rep"
done
docker stop ferrum-bench-jaeger >/dev/null 2>&1
OTEL_TRACES_SAMPLER_RATIO=0.1 OTEL_EXPORTER_OTLP_ENDPOINT="" "$S" restart gateway </dev/null >/dev/null
echo "## done"
