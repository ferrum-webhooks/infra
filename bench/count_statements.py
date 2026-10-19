#!/usr/bin/env python3
"""SQL round trips per ingest: current implementation vs the previous one (kept below for comparison).

    infra/local/stack.sh up
    ferrum-webhook-gateway/.venv/bin/python infra/bench/count_statements.py
Counts cursor executions on a real Postgres plus the COMMIT.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "ferrum-webhook-gateway"))
os.environ.update(DB_HOST="localhost", DB_PORT=os.environ.get("PG_PORT", "5544"), DB_USER="ferrum_user",
                  DB_PASSWORD="x", DB_NAME="ferrum_bench", JWT_SECRET="x" * 40)

from sqlalchemy import create_engine, event as sa_event
from sqlalchemy.orm import sessionmaker

from app import models
from app.crud import event as crud_event
from app.security import new_event_public_id

engine = create_engine("postgresql://ferrum_user@localhost:%s/ferrum_bench" % os.environ["DB_PORT"])
counter = {"n": 0, "sql": []}


@sa_event.listens_for(engine, "before_cursor_execute")
def _count(conn, cursor, statement, params, context, executemany):
    counter["n"] += 1
    counter["sql"].append(statement.split("\n")[0][:70].strip())


def old_create_event(db, user_id, payload, event_type, request_id=None):
    """The implementation before the optimisation: flush per delivery, then a refresh SELECT after commit."""
    ev = models.Event(public_id=new_event_public_id(), user_id=user_id, payload=payload, status="pending", event_type=event_type)
    db.add(ev); db.flush()
    webhooks = db.query(models.Webhook).filter(models.Webhook.user_id == user_id, models.Webhook.event_type == event_type,
                                               models.Webhook.deleted_at.is_(None)).all()
    for w in webhooks:
        d = models.Delivery(event_id=ev.id, webhook_id=w.id, status="pending", retries=0)
        db.add(d); db.flush()
        db.add(models.Outbox(delivery_id=d.id, request_id=request_id))
    db.commit()
    db.refresh(ev)
    return ev, len(webhooks)


def measure(fn, factory, user_id, event_type):
    counter["n"] = 0; counter["sql"].clear()
    db = factory()
    fn(db, user_id, {"a": 1}, event_type)
    db.close()
    return counter["n"] + 1, list(counter["sql"])        # + COMMIT


setup = sessionmaker(bind=engine)()
u = models.User(email=f"count-{os.getpid()}@example.com", password_hash="x"); setup.add(u); setup.commit()
print(f"{'webhooks':>8} {'before':>8} {'after':>7}")
for n in (1, 5, 20):
    et = f"count.{n}"
    for _ in range(n):
        setup.add(models.Webhook(user_id=u.id, url="https://example.com/h", event_type=et, secret="whsec_x"))
    setup.commit()
    old, _ = measure(old_create_event, sessionmaker(bind=engine, autoflush=False), u.id, et)
    new, sql = measure(crud_event.create_event, sessionmaker(bind=engine, autoflush=False, expire_on_commit=False), u.id, et)
    print(f"{n:>8} {old:>8} {new:>7}")
    if n == 1:
        sql1 = sql
print("\nafter, statement list (1 webhook):", *sql1, "COMMIT", sep="\n  ")
