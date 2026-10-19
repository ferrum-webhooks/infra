#!/usr/bin/env bash
# Ingest benchmark matrix. Usage: infra/bench/matrix.sh TAG     (TAG labels the code version, e.g. base / opt1)
# Needs: `caffeinate` (macOS) or equivalent so the machine does not sleep mid-run. ~12 minutes.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; TAG="${1:?tag}"
export OUT="${OUT:-/tmp/ferrum-bench/out}"; mkdir -p "$OUT"
S="$HERE/../local/stack.sh"
restart() { "$S" restart gateway </dev/null >/dev/null; "$S" restart worker </dev/null >/dev/null; }

echo "## $TAG: 1 gateway process, 1 worker process"
export GW_WORKERS=1 WORKERS=1; restart
for v in 10 50 200; do "$HERE/run.sh" "$TAG gw1 closed VUS=$v" -e MODE=closed -e VUS=$v -e USERS=50 -e DURATION=30s </dev/null; done

echo "## $TAG: 4 gateway processes, 4 worker processes"
export GW_WORKERS=4 WORKERS=4; restart
for v in 50 200; do "$HERE/run.sh" "$TAG gw4 closed VUS=$v" -e MODE=closed -e VUS=$v -e USERS=50 -e DURATION=30s </dev/null; done
for r in 500 1000 1500; do "$HERE/run.sh" "$TAG gw4 open rate=$r/s" -e MODE=open -e RATE=$r -e USERS=100 -e VUS=300 -e DURATION=30s </dev/null; done
echo "## done"
