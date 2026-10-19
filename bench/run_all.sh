#!/usr/bin/env bash
# The complete local experiment suite, sequentially, on an otherwise idle machine. About 45 minutes.
#   caffeinate -dims infra/bench/run_all.sh [output_dir=/tmp/ferrum-results]      (SKIP="ablation" to leave a stage out)
# Each stage is independent; outputs land in <output_dir>/<stage>/ . Every table in docs/engineering comes from one of them.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; S="$HERE/../local/stack.sh"
R="${1:-/tmp/ferrum-results}"; mkdir -p "$R"
GWPY="$ROOT/ferrum-webhook-gateway/.venv/bin/python"
SKIP="${SKIP:-}"   # e.g. SKIP="ablation tracing" to leave stages out
skipped() { case " $SKIP " in *" $1 "*) echo "--- skipping $1"; return 0;; esac; return 1; }
stage() { echo "=== $(date +%T) $1"; }

"$S" doctor </dev/null || { echo "stray processes: run $S doctor --kill"; exit 1; }
"$S" up </dev/null >/dev/null

skipped ablation  || { stage "ablation (ingest, isolated, interleaved repeats)"; OUT="$R/ablation" "$HERE/ablation.sh" 5 > "$R/ablation.log" 2>&1; }
stage "scaling";           OUT="$R/scaling"  "$HERE/scaling.sh" 3 > "$R/scaling.log" 2>&1
stage "tracing overhead";  OUT="$R/tracing"  "$HERE/tracing_overhead.sh" 4 > "$R/tracing.log" 2>&1
stage "end-to-end latency"; OUT="$R/e2e" "$HERE/e2e_latency.sh" 300 > "$R/e2e.log" 2>&1
stage "delivery capacity"; mkdir -p "$R/drain"
for cfg in "0 1 8" "0 1 32" "0 4 8" "50 1 8" "50 1 32" "50 4 8"; do "$HERE/drain_rate.sh" $cfg 2>&1 | tail -2 | tee -a "$R/drain/drain.txt"; done
stage "SQL round trips";   "$GWPY" "$HERE/count_statements.py" > "$R/count_statements.txt" 2>&1
stage "signing cost";      (cd "$ROOT/ferrum-webhook-worker" && .venv/bin/python scripts/sign_bench.py) > "$R/sign_bench.txt" 2>&1
echo "=== $(date +%T) done"
