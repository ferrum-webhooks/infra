#!/usr/bin/env python3
"""A webhook receiver for playing with Ferrum: prints every delivery, verifies its signature, can simulate failures.

  WEBHOOK_SECRET=whsec_...  python infra/tests/echo_receiver.py            # listens on :9000
  FAIL_FIRST=2   fail the first 2 requests with 500 (watch the retries arrive 5 s, 10 s later)
  FAIL_EVERY=3   fail every 3rd request          STATUS=200 status to return otherwise     PORT=9000
  DELAY=20       hold requests for 20 s before answering (to kill the worker mid-delivery); the worker gives up after 5 s,
                 so combine with DELAY_FIRST=1 to delay only the first request and let the recovered attempt succeed

Point a webhook at http://127.0.0.1:9000/anything (the worker must be allowed to reach loopback:
ALLOW_PRIVATE_WEBHOOK_TARGETS=true, which the local stack enables).
"""
import base64
import hashlib
import hmac
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.getenv("WEBHOOK_SECRET", "")
PORT = int(os.getenv("PORT", "9000"))
FAIL_FIRST = int(os.getenv("FAIL_FIRST", "0"))
FAIL_EVERY = int(os.getenv("FAIL_EVERY", "0"))
STATUS = int(os.getenv("STATUS", "200"))
DELAY = float(os.getenv("DELAY", "0"))
DELAY_FIRST = int(os.getenv("DELAY_FIRST", "0"))      # only the first N requests are delayed (0 = all)
count = 0
seen_ids = {}


def signature_ok(headers, body):
    if not SECRET:
        return None
    key = base64.b64decode(SECRET.removeprefix("whsec_"))
    signed = f'{headers.get("webhook-id")}.{headers.get("webhook-timestamp")}.'.encode() + body
    want = "v1," + base64.b64encode(hmac.new(key, signed, hashlib.sha256).digest()).decode()
    return any(hmac.compare_digest(want, s) for s in headers.get("webhook-signature", "").split(" "))


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        global count
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        h = {k.lower(): v for k, v in self.headers.items()}
        count += 1
        mid = h.get("webhook-id", "?")
        seen_ids[mid] = seen_ids.get(mid, 0) + 1
        fail = count <= FAIL_FIRST or (FAIL_EVERY and count % FAIL_EVERY == 0)
        code = 500 if fail else STATUS
        ok = signature_ok(h, body)
        sig = "no secret given" if ok is None else ("VALID" if ok else "INVALID")
        age = abs(time.time() - int(h.get("webhook-timestamp", 0)))
        print(f"[{time.strftime('%H:%M:%S')}] #{count} POST {self.path} -> {code}   id={mid} (seen {seen_ids[mid]}x)  "
              f"signature={sig}  ts_age={age:.1f}s", flush=True)
        try:
            print("   body:", json.dumps(json.loads(body)), flush=True)
        except Exception:
            print("   body:", body[:200], flush=True)
        if DELAY and (DELAY_FIRST == 0 or count <= DELAY_FIRST):
            time.sleep(DELAY)
        self.send_response(code); self.send_header("Content-Length", "0"); self.end_headers()


print(f"echo receiver on :{PORT}  secret={'set' if SECRET else 'NOT set (signatures not checked)'}", file=sys.stderr)
ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
