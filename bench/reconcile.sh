#!/usr/bin/env bash
# Correctness + end-to-end latency report for the benchmark stack. Run after a load test (waits for the drain).
#   infra/bench/reconcile.sh [expected_accepted_count]
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SINK="${SINK_URL:-http://127.0.0.1:9000/stats}"
q() { "$HERE/../local/stack.sh" psql -Atqc "$1"; }
start=$(date +%s)
while :; do
  open=$(q "select count(*) from deliveries where status in ('pending','in_flight','retrying')")
  unpub=$(q "select count(*) from outbox where published_at is null")
  [ "$open" = 0 ] && [ "$unpub" = 0 ] && break
  [ $(( $(date +%s) - start )) -gt "${DRAIN_TIMEOUT:-120}" ] && { echo "drain timeout: open=$open unpublished=$unpub"; break; }
  sleep 1
done
echo "drain wait: $(( $(date +%s) - start ))s"
q "select 'events                      '||count(*) from events"
q "select 'deliveries '||rpad(status,20)||count(*) from deliveries group by status order by 1"
q "select 'duplicate (event,webhook)   '||count(*) from (select 1 from deliveries group by event_id, webhook_id having count(*)>1) x"
q "select 'outbox unpublished          '||count(*) from outbox where published_at is null"
q "select 'deliveries with >1 attempt  '||count(*) from deliveries where retries>1"
[ -n "${1:-}" ] && q "select 'expected accepted/actual    $1 / '||count(*) from events"
echo "sink: $(curl -s "$SINK")"
echo "end-to-end latency, event created -> first successful attempt (ms):"
q "select '  p50 '||round((percentile_cont(0.5) within group (order by extract(epoch from a.attempted_at - e.created_at)*1000))::numeric,1)
        ||'  p95 '||round((percentile_cont(0.95) within group (order by extract(epoch from a.attempted_at - e.created_at)*1000))::numeric,1)
        ||'  p99 '||round((percentile_cont(0.99) within group (order by extract(epoch from a.attempted_at - e.created_at)*1000))::numeric,1)
        ||'  max '||round((max(extract(epoch from a.attempted_at - e.created_at)*1000))::numeric,1)
   from delivery_attempts a join deliveries d on d.id=a.delivery_id join events e on e.id=d.event_id
   where a.status='success' and a.attempt=1"
