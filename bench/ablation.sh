#!/usr/bin/env bash
# Which change bought what? Isolated ingest benchmark (NO worker running, so delivery backlog cannot interfere),
# 1 gateway process, closed model. Variants are interleaved (A B A B ...) and repeated to cancel machine drift;
# aggregate.py reports mean +/- sd. ~25 minutes.
#   infra/bench/ablation.sh [reps=5]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/../local/stack.sh"
REPS="${1:-5}"; export OUT="${OUT:-/tmp/ferrum-bench/abl}"; mkdir -p "$OUT"; export GW_WORKERS=1 NO_RECONCILE=1
mk() { python3 "$HERE/make_variant.py" "/tmp/ferrum-variants/$1" --revert "$2" >/dev/null; }
mk original all; mk no-refresh refresh; mk no-route route; mk no-async asyncdep; mk old-pool pool
use() { # variant ("" = current code)
  if [ "$1" = final ]; then unset GATEWAY_DIR; else export GATEWAY_DIR="/tmp/ferrum-variants/$1"; fi
  "$S" restart gateway </dev/null >/dev/null
}
one() { # variant vus rep
  use "$1"; "$HERE/run.sh" "$1 VUS=$2 rep=$3" -e MODE=closed -e VUS=$2 -e USERS=50 -e WARMUP=3s -e DURATION=20s </dev/null >/dev/null
}
"$S" kill9 worker </dev/null
for rep in $(seq "$REPS"); do                       # main comparison, interleaved
  for vus in 10 50; do for v in final original; do one "$v" "$vus" "$rep"; done; done
done
for rep in 1 2 3; do                                # attribution: each single revert at 50 clients
  for v in final no-refresh no-route no-async old-pool; do one "$v" 50 "a$rep"; done
done
for v in final original no-route no-async old-pool; do one "$v" 200 1; done      # behaviour past the pool size
unset GATEWAY_DIR; "$S" restart gateway </dev/null >/dev/null
echo "## done"
