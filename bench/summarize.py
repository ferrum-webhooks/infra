#!/usr/bin/env python3
"""Print one compact row from a k6 --summary-export JSON, measurement phase only.

usage: summarize.py summary.json [label] [measure_seconds=30]

k6 reports `rate` for tagged sub-metrics over the WHOLE test (warm-up included), which understates throughput.
Throughput here is computed as completed requests / measurement window, which is the honest number.
"""
import json
import sys

d = json.load(open(sys.argv[1]))
m = d["metrics"]
label = sys.argv[2] if len(sys.argv) > 2 else ""
window = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
dur = m.get("http_req_duration{phase:measure}", m.get("http_req_duration"))
cnt = m.get("http_reqs{phase:measure}", m.get("http_reqs"))
fail = m.get("http_req_failed{phase:measure}", m.get("http_req_failed"))
print(f"{label:34s} rps={cnt['count'] / window:7.1f}  n={int(cnt['count']):6d}  err={fail['value'] * 100:5.2f}%  "
      f"avg={dur['avg']:7.1f}  p50={dur['med']:7.1f}  p95={dur['p(95)']:7.1f}  p99={dur['p(99)']:7.1f}  max={dur['max']:7.1f}  (ms)")
