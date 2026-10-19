#!/usr/bin/env python3
"""Build a copy of the gateway with selected ingest/concurrency changes REVERTED, for ablation benchmarks.

    python infra/bench/make_variant.py OUTDIR [--revert refresh,batch,route,asyncdep,pool | all]
    GATEWAY_DIR=OUTDIR infra/local/stack.sh restart gateway

Reverts (each is one of the changes that make up the optimisation, see docs/engineering/06 and 05):
  refresh   sessions expire on commit, so reading event.public_id after commit costs a SELECT (+ db.refresh)
  batch     one flush (round trip) per delivery instead of one batched INSERT
  route     do not release the DB connection inside the handler (SessionReleasingRoute)
  asyncdep  sync generator `get_db` dependency (teardown needs a worker thread)
  pool      old pool settings: 5 + 10 connections, 30 s timeout
The copy shares the original's virtualenv (run it with that interpreter; stack.sh does).
"""
import argparse
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "ferrum-webhook-gateway")
ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--revert", default="all")
args = ap.parse_args()
parts = {"refresh", "batch", "route", "asyncdep", "pool"} if args.revert == "all" else set(args.revert.split(","))
unknown = parts - {"refresh", "batch", "route", "asyncdep", "pool"}
if unknown:
    sys.exit(f"unknown: {unknown}")

if os.path.exists(args.out):
    shutil.rmtree(args.out)
shutil.copytree(SRC, args.out, ignore=shutil.ignore_patterns(".venv", ".git", "__pycache__", ".pytest_cache", "tests"))


def edit(rel, old, new):
    p = os.path.join(args.out, rel)
    s = open(p).read()
    if old not in s:
        sys.exit(f"cannot revert in {rel}: expected text not found:\n{old[:80]}")
    open(p, "w").write(s.replace(old, new, 1))


if "refresh" in parts:
    edit("app/db.py", "autoflush=False, expire_on_commit=False, bind=get_engine()", "autoflush=False, bind=get_engine()")
    edit("app/crud/event.py", "    db.commit()                       # session has expire_on_commit=False: no refresh query needed\n    return event, len(webhooks)",
         "    db.commit()\n    db.refresh(event)\n    return event, len(webhooks)")
if "batch" in parts:
    edit("app/crud/event.py", """    db.add_all(deliveries)
    db.flush()                        # one batched INSERT ... RETURNING for all deliveries
    db.add_all([models.Outbox(delivery_id=d.id, request_id=request_id, traceparent=tp) for d in deliveries])
""", """    for d in deliveries:
        db.add(d)
        db.flush()
        db.add(models.Outbox(delivery_id=d.id, request_id=request_id, traceparent=tp))
""")
if "route" in parts:
    edit("app/main.py", "app.router.route_class = SessionReleasingRoute", "")
if "asyncdep" in parts:
    edit("app/deps.py", "async def get_db():", "def get_db():")
if "pool" in parts:
    edit("app/db.py", 'pool_size=int(os.getenv("DB_POOL_SIZE", 10))', "pool_size=5")
    edit("app/db.py", 'max_overflow=int(os.getenv("DB_MAX_OVERFLOW", 10))', "max_overflow=10")
    edit("app/db.py", 'pool_timeout=float(os.getenv("DB_POOL_TIMEOUT", 5)),', "")
print(f"variant written to {args.out} (reverted: {', '.join(sorted(parts))})")
