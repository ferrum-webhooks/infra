# Ferrum — Infrastructure (Docker Compose)

## Overview

This repository defines the **runtime environment** for Ferrum.

It orchestrates:

* Gateway
* Worker
* PostgreSQL
* Redis

using Docker Compose.

---

## Architecture

```text
Client → Gateway ──→ PostgreSQL
              └──→ Redis ──→ Worker → PostgreSQL
```

---

## Project Structure

```text
ferrum-infra/
  docker-compose.yml
  prometheus.yml
  webhook-gateway/
  webhook-worker/
```

---

## Running the System

### 1. Start everything

```bash
docker-compose up --build
```

---

### 2. Access services

* Gateway: http://localhost:8000
* Prometheus: http://localhost:9080
* Worker: http://localhost:8001
* PostgreSQL: localhost:5432
* Redis: localhost:6379

---

## Service Definitions

---

### PostgreSQL

* image: postgres:15
* database: ferrum

---

### Redis

* image: redis:7
* used for:

  * caching
  * queue

---

### Gateway

* FastAPI service
* exposed on port 8000
* exposes `/metrics` for Prometheus

---

### Worker

* background consumer
* exposes metrics on port 8001

---

### Prometheus

* image: prom/prometheus
* scrapes metrics from:
  * gateway:8000
  * worker:8001
* configured via `prometheus.yml`

---

## Observability

### Metrics Collection

Prometheus scrapes:

* Gateway → request metrics
* Worker → processing + delivery metrics

### Example Queries
##### Gateway traffic
```gateway_requests_total```
##### Request latency (rate)
```rate(gateway_request_latency_seconds_sum[1m])```
##### Worker throughput
```worker_events_processed_total```
##### Queue delay (critical)
```worker_queue_delay_seconds_sum / worker_queue_delay_seconds_count```
##### p95 queue delay
```histogram_quantile(0.95, rate(worker_queue_delay_seconds_bucket[1m]))```

## Known Issues

---

### 1. Service startup race condition

Problem:

* Gateway/Worker start before DB is ready

Symptoms:

```text
connection refused
```

Temporary fix:

* restart containers

---

### 2. No health checks yet

Will be added in later phases.

---

### 3. No persistent metrics storage
* Prometheus data is ephemeral
* resets on container restart

## Debugging

---

### View logs

```bash
docker-compose logs -f
```

---

### Restart services

```bash
docker-compose restart
```

---

### Rebuild

```bash
docker-compose up --build
```

---

### Check metrics manually

```bash
curl http://localhost:8000/metrics
curl http://localhost:8001/metrics
```
---


## Status

✅ Phase 5 — Observability
✅ Metrics + Prometheus integrated
✅ Multi-service environment working

---

## What This Enables

* System-wide monitoring
* Performance analysis
* Bottleneck detection
* Debugging using metrics + logs
* Foundation for alerting and dashboards

---

## Next Steps

* Grafana dashboards
* Alerting rules
* Health checks (readiness/liveness)
* Retry system
* CI/CD integration

---

## Summary

Before this:

```text
System ran as containers
```

Now:

```text
System is observable in real time
```


---
