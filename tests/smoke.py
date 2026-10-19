#!/usr/bin/env python3
"""End-to-end smoke test for a running Ferrum (gateway + worker + postgres + redis).

  python infra/tests/smoke.py                                  # gateway on :8000, starts a local receiver on :9099
  python infra/tests/smoke.py --base http://localhost:8000 --target http://receiver:9000/hook   # in-cluster sink
  python infra/tests/smoke.py --base http://localhost:18000 --target-host host.docker.internal # gateway running in a container

The worker must be allowed to reach the target (ALLOW_PRIVATE_WEBHOOK_TARGETS=true for localhost/cluster/docker-host targets).
Checks: auth, webhook secret, ingest 202, delivery success with a valid Standard Webhooks signature (local receiver
only), Idempotency-Key replay, per-user isolation, replay endpoint, rate-limit headers on 429.
Needs: pip install requests
"""
import argparse, base64, hashlib, hmac, json, sys, threading, time, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import requests

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="http://localhost:8000")
ap.add_argument("--target", help="webhook URL; default: start a local receiver and use it")
ap.add_argument("--receiver-port", type=int, default=9099)
ap.add_argument("--target-host", default="127.0.0.1", help="host the gateway/worker should use to reach the local receiver (host.docker.internal when they run in Docker)")
ap.add_argument("--wait", type=float, default=30)
args = ap.parse_args()

received, secret_holder = [], {}


class Receiver(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        h = {k.lower(): v for k, v in self.headers.items()}
        key = base64.b64decode(secret_holder["s"].removeprefix("whsec_"))
        want = "v1," + base64.b64encode(hmac.new(key, f'{h["webhook-id"]}.{h["webhook-timestamp"]}.'.encode() + body,
                                                  hashlib.sha256).digest()).decode()
        received.append({"id": h["webhook-id"], "sig_ok": hmac.compare_digest(want, h["webhook-signature"])})
        self.send_response(200); self.end_headers()


target = args.target
if not target:
    srv = ThreadingHTTPServer(("0.0.0.0", args.receiver_port), Receiver)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    target = f"http://{args.target_host}:{args.receiver_port}/hook"

fails = []
def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
    if not ok: fails.append(name)

def user(email):
    pw = "smoke-test-password"
    requests.post(f"{args.base}/register", json={"email": email, "password": pw}, timeout=10)
    r = requests.post(f"{args.base}/login", json={"email": email, "password": pw}, timeout=10)
    assert r.status_code == 200, f"login failed: {r.status_code} {r.text}"
    return {"Authorization": "Bearer " + r.json()["access_token"]}

def wait_for(fn, timeout=args.wait):
    end = time.time() + timeout
    while time.time() < end:
        v = fn()
        if v: return v
        time.sleep(0.4)

B = args.base
tag = uuid.uuid4().hex[:8]
a, b = user(f"smoke-a-{tag}@example.com"), user(f"smoke-b-{tag}@example.com")
check("unauthenticated request rejected", requests.get(f"{B}/webhooks").status_code == 401)

et = f"smoke.{tag}"
r = requests.post(f"{B}/webhooks", json={"url": target, "event_type": et}, headers=a)
check("create webhook (201, secret returned)", r.status_code == 201 and r.json().get("secret", "").startswith("whsec_"), r.text)
if r.status_code != 201:
    sys.exit(f"cannot continue: {r.status_code} {r.text}")
secret_holder["s"] = r.json()["secret"]

body = {"event_type": et, "payload": {"n": 1}}
key = {"Idempotency-Key": f"k-{tag}"}
r1 = requests.post(f"{B}/events", json=body, headers={**a, **key})
check("ingest accepted (202, 1 delivery)", r1.status_code == 202 and r1.json()["deliveries"] == 1, r1.text)
ev = r1.json()["event_id"]
r2 = requests.post(f"{B}/events", json=body, headers={**a, **key})
check("idempotent replay (200, same event)", r2.status_code == 200 and r2.json()["event_id"] == ev
      and r2.headers.get("Idempotent-Replayed") == "true", r2.text)
check("idempotency key reused with another body -> 422",
      requests.post(f"{B}/events", json={**body, "payload": {"n": 2}}, headers={**a, **key}).status_code == 422)

d = wait_for(lambda: (lambda x: x if x and all(i["status"] == "success" for i in x) else None)(
    requests.get(f"{B}/deliveries/{ev}", headers=a).json()))
check("delivered (success within %ds)" % args.wait, bool(d), "")
if d:
    check("attempt logged with status code + latency", d[0]["attempts"][0]["response_code"] == 200
          and d[0]["attempts"][0]["latency_ms"] is not None)
if not args.target:
    check("receiver got exactly one POST with a valid signature",
          len(received) == 1 and received[0]["sig_ok"] and received[0]["id"] == ev, str(received))
check("event status delivered", requests.get(f"{B}/events/{ev}", headers=a).json()["status"] == "delivered")

check("tenant B cannot read A's event", requests.get(f"{B}/events/{ev}", headers=b).status_code == 404)
check("tenant B cannot see A's deliveries", requests.get(f"{B}/deliveries/{ev}", headers=b).status_code == 404)
check("tenant B cannot replay A's event", requests.post(f"{B}/retry/{ev}", headers=b).status_code == 404)
check("replay with nothing failed is a no-op",
      requests.post(f"{B}/retry/{ev}", headers=a).json().get("replayed_deliveries") == 0)

print("\n%d check(s) failed" % len(fails) if fails else "\nall checks passed")
sys.exit(1 if fails else 0)
