#!/usr/bin/env bash
# Private, disposable Ferrum stack on localhost for benchmarks and experiments.
# Isolated from anything else on the machine: own Postgres (:5544), own Redis (:6390), own ports.
#
#   infra/bench/stack.sh up            # postgres + redis + migrate + gateway + worker + sink
#   infra/bench/stack.sh status
#   infra/bench/stack.sh restart gateway|worker|sink
#   infra/bench/stack.sh psql [-c "sql"]
#   infra/bench/stack.sh clean         # truncate data between runs (schema kept)
#   infra/bench/stack.sh down          # stop processes (data kept)   |   reset: delete all data
#
# Knobs (environment, read at `up`/`restart`):
#   GW_WORKERS=1  WORKERS=1  WORKER_CONCURRENCY=8  OTEL_TRACES_SAMPLER_RATIO=0.1  OTEL_EXPORTER_OTLP_ENDPOINT=
#   GATEWAY_DIR=/path/to/gateway-copy    (run a modified copy, see infra/bench/make_variant.py)
#   SINK_FAIL_RATE=0..1  SINK_LATENCY_MS=0   (behaviour of the counting sink on :9000)
#   RATE_LIMIT_CAPACITY / RATE_LIMIT_REFILL_PER_SEC / AUTH_RATE_LIMIT_*   (any app/worker setting is passed through)
# Layout assumption: infra/ sits next to ferrum-webhook-gateway/ and ferrum-webhook-worker/ (each with a .venv).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # workspace root: infra/local/stack.sh -> ../..
D="${BENCH_DIR:-/tmp/ferrum-bench}"
PG_PORT="${PG_PORT:-5544}" REDIS_PORT="${REDIS_PORT:-6390}"
GW_PORT="${GW_PORT:-8100}" HEALTH_PORT_BASE="${HEALTH_PORT_BASE:-8101}" SINK_PORT="${SINK_PORT:-9000}"
GW_PY="$ROOT/ferrum-webhook-gateway/.venv/bin/python"
WK_PY="$ROOT/ferrum-webhook-worker/.venv/bin/python"
mkdir -p "$D/run" "$D/log" "$D/sock"

export DB_HOST=localhost DB_PORT="$PG_PORT" DB_USER=ferrum_user DB_PASSWORD=bench DB_NAME=ferrum_bench
export REDIS_HOST=localhost REDIS_PORT="$REDIS_PORT"
export JWT_SECRET="${JWT_SECRET:-bench-secret-bench-secret-bench-secret-0123456789}"
export ALLOW_PRIVATE_WEBHOOK_TARGETS="${ALLOW_PRIVATE_WEBHOOK_TARGETS:-true}"   # sink is on 127.0.0.1
export RATE_LIMIT_ENABLED="${RATE_LIMIT_ENABLED:-true}"
export RATE_LIMIT_CAPACITY="${RATE_LIMIT_CAPACITY:-1000000}" RATE_LIMIT_REFILL_PER_SEC="${RATE_LIMIT_REFILL_PER_SEC:-1000000}"   # limiter stays ON (its cost is part of ingest) but never throttles a benchmark
export AUTH_RATE_LIMIT_CAPACITY="${AUTH_RATE_LIMIT_CAPACITY:-100000}" AUTH_RATE_LIMIT_REFILL_PER_SEC="${AUTH_RATE_LIMIT_REFILL_PER_SEC:-100000}"

# spawn NAME DIR CMD...: run detached, log to $D/log/NAME.log, record the REAL pid (exec replaces the subshell)
spawn() { local name=$1 dir=$2; shift 2; ( cd "$dir" && exec "$@" ) >"$D/log/$name.log" 2>&1 </dev/null & echo $! > "$(pidf "$name")"; }
# fail loudly if the port is held by someone else (an orphan from an earlier run would otherwise answer our health check)
owns_port() { local pid=$1 port=$2; lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -qx "$pid"; }
pidf() { echo "$D/run/$1.pid"; }
alive() { [ -f "$(pidf "$1")" ] && kill -0 "$(cat "$(pidf "$1")")" 2>/dev/null; }
stop_one() { if alive "$1"; then kill "$(cat "$(pidf "$1")")" 2>/dev/null || true; for _ in $(seq 50); do alive "$1" || break; sleep 0.1; done; alive "$1" && kill -9 "$(cat "$(pidf "$1")")" 2>/dev/null || true; fi; rm -f "$(pidf "$1")"; }

# Untracked Ferrum processes (orphans from an earlier run) silently join the Redis consumer group or hold ports and
# corrupt experiments. `up` refuses to start while any exist; `doctor --kill` removes them.
strays() {
  local tracked pid ppid cmd
  tracked=" $(cat "$D"/run/*.pid 2>/dev/null | tr '\n' ' ') "
  ps -eo pid=,ppid=,command= | grep -E "worker\.main|uvicorn app\.main:app|tests/receiver\.py|multiprocessing" | grep -v grep | grep -vE "(zsh|bash|sh) -c" \
  | while read -r pid ppid cmd; do
      case "$tracked" in *" $pid "*|*" $ppid "*) continue;; esac
      echo "$pid $cmd" | cut -c1-120
    done || true      # grep exits 1 when nothing matches; "no strays" is the success case
}

start_postgres() {
  if [ ! -d "$D/pg" ]; then initdb -D "$D/pg" -U ferrum_user --auth=trust >/dev/null; fi
  pg_ctl -D "$D/pg" status >/dev/null 2>&1 || pg_ctl -D "$D/pg" -o "-p $PG_PORT -k $D/sock -c fsync=on -c max_connections=300 -c shared_buffers=256MB" -l "$D/log/postgres.log" -w start >/dev/null
  psql -h localhost -p "$PG_PORT" -U ferrum_user -d postgres -Atc "select 1 from pg_database where datname='$DB_NAME'" | grep -q 1 \
    || createdb -h localhost -p "$PG_PORT" -U ferrum_user "$DB_NAME"
}
start_redis() {
  alive redis || spawn redis "$D" redis-server --port "$REDIS_PORT" --save "" --appendonly no --bind 127.0.0.1
  for _ in $(seq 50); do redis-cli -p "$REDIS_PORT" ping >/dev/null 2>&1 && break; sleep 0.1; done
}
migrate() { (cd "$ROOT/ferrum-webhook-gateway" && "$GW_PY" -m alembic upgrade head >"$D/log/migrate.log" 2>&1); }
start_gateway() {
  alive gateway && return
  spawn gateway "${GATEWAY_DIR:-$ROOT/ferrum-webhook-gateway}" "$GW_PY" -m uvicorn app.main:app --host 127.0.0.1 --port "$GW_PORT" \
     --workers "${GW_WORKERS:-1}" --timeout-graceful-shutdown 20
  for _ in $(seq 100); do
    if curl -fs "http://127.0.0.1:$GW_PORT/readyz" >/dev/null 2>&1; then
      owns_port "$(cat "$(pidf gateway)")" "$GW_PORT" || { echo "port $GW_PORT is held by another process (pid $(lsof -tiTCP:$GW_PORT -sTCP:LISTEN | head -1)); not ours" >&2; exit 1; }
      return
    fi
    sleep 0.2
  done; echo "gateway failed to start (see $D/log/gateway.log)" >&2; exit 1
}
start_worker() {
  local n="${WORKERS:-1}" i
  for i in $(seq 1 "$n"); do
    alive "worker$i" && continue
    spawn "worker$i" "$ROOT/ferrum-webhook-worker" env HEALTH_PORT=$((HEALTH_PORT_BASE + i - 1)) "$WK_PY" -m worker.main
  done
  for _ in $(seq 100); do curl -fs "http://127.0.0.1:$HEALTH_PORT_BASE/readyz" >/dev/null 2>&1 && return; sleep 0.2; done; echo "worker failed to start" >&2; exit 1
}
start_sink() { alive sink || { spawn sink "$ROOT/infra" env PORT="$SINK_PORT" FAIL_RATE="${SINK_FAIL_RATE:-0}" LATENCY_MS="${SINK_LATENCY_MS:-0}" python3 tests/receiver.py; sleep 0.5; }; }

case "${1:-}" in
  doctor)  out="$(strays)"; if [ -z "$out" ]; then echo "no stray processes"; else echo "$out"
             [ "${2:-}" = "--kill" ] && { echo "$out" | awk '{print $1}' | xargs kill 2>/dev/null; sleep 1; echo "$out" | awk '{print $1}' | xargs kill -9 2>/dev/null || true; echo "killed"; } || exit 1; fi ;;
  up)      out="$(strays)"; [ -n "$out" ] && { echo "stray Ferrum processes (orphans of an earlier run) would interfere:" >&2; echo "$out" >&2; echo "run: $0 doctor --kill" >&2; exit 1; }
           start_postgres; start_redis; migrate; start_sink; start_gateway; start_worker; "$0" status ;;
  restart) case "${2:-}" in
             gateway) stop_one gateway; start_gateway ;;
             worker)  for p in "$D"/run/worker*.pid; do [ -e "$p" ] && stop_one "$(basename "$p" .pid)"; done; start_worker ;;
             sink)    stop_one sink; start_sink ;;
             redis)   stop_one redis; start_redis ;;
             *) echo "restart gateway|worker|sink|redis"; exit 2 ;; esac ;;
  kill9)   # kill -9 a component without restarting it (fault injection)
           for p in "$D"/run/${2:?name}*.pid; do [ -e "$p" ] && { kill -9 "$(cat "$p")" 2>/dev/null || true; rm -f "$p"; }; done ;;
  status)  for n in redis sink gateway worker1; do printf "%-8s %s\n" "$n" "$(alive $n && echo "up (pid $(cat "$(pidf $n)"))" || echo down)"; done
           pg_ctl -D "$D/pg" status >/dev/null 2>&1 && echo "postgres up (:$PG_PORT)" || echo "postgres down"
           echo "gateway http://127.0.0.1:$GW_PORT   sink http://127.0.0.1:$SINK_PORT/stats   logs $D/log" ;;
  psql)    shift; psql -h localhost -p "$PG_PORT" -U ferrum_user "$DB_NAME" "$@" ;;
  env)     env | grep -E '^(DB_|REDIS_|JWT_SECRET|ALLOW_PRIVATE)' | sed 's/^/export /' ;;
  clean)   # wipe application data in the PRIVATE postgres/redis only (keeps schema), reset sink counters
           "$0" psql -qc "truncate outbox, delivery_attempts, deliveries, events, webhooks, users restart identity cascade" >/dev/null
           redis-cli -p "$REDIS_PORT" flushall >/dev/null
           if alive worker1; then "$0" restart worker; fi    # leave a deliberately stopped worker stopped
           "$0" restart sink ;;
  down)    for p in "$D"/run/*.pid; do [ -e "$p" ] && stop_one "$(basename "$p" .pid)"; done; pg_ctl -D "$D/pg" -m fast stop >/dev/null 2>&1 || true ;;
  reset)   "$0" down; rm -rf "$D" ;;
  *) sed -n 2,14p "$0"; exit 2 ;;
esac
