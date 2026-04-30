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
* PostgreSQL: localhost:5432
* Redis: localhost:6379

---

## Environment Configuration

Services communicate via **service names**:

| Service  | Host     |
| -------- | -------- |
| Postgres | postgres |
| Redis    | redis    |

---

## Example Config

Gateway & Worker use:

```env
DB_HOST=postgres
REDIS_HOST=redis
```

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

---

### Worker

* background consumer
* no exposed ports

---

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

## Status

✅ Phase 4 — Containerized distributed system
✅ Fully reproducible environment

---

## What This Enables

* CI/CD pipelines
* Kubernetes deployment
* horizontal scaling
* environment parity

---

## Next Steps

* observability (metrics + tracing)
* retry system
* health checks
* graceful startup

---

## Summary

Before this:

```text
System ran on your machine
```

Now:

```text
System runs as an environment
```

This is the foundation for all future scalability.
