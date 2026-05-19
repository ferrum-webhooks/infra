# Ferrum — Infrastructure Repository (Phase 8)

## Overview

This repository defines the **runtime orchestration layer** for Ferrum.

It is responsible for running the complete distributed system locally using:

- Docker Compose
- Kubernetes (Minikube)
- GitHub Container Registry (GHCR)
- Prometheus monitoring
- Horizontal Pod Autoscaling (HPA)

This repo does **not** contain application business logic.

Instead, it provides:
- infrastructure orchestration
- service networking
- environment configuration
- deployment definitions
- observability wiring
- local reproducibility

---

# System Architecture

## High-Level Flow

```text
                    ┌────────────────────┐
                    │      Client        │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │      Gateway       │
                    │   FastAPI Service  │
                    └─────────┬──────────┘
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
       ┌───────────────┐             ┌──────────────┐
       │ PostgreSQL DB │             │ Redis Queue  │
       └───────────────┘             └──────┬───────┘
                                            │
                                            ▼
                                  ┌────────────────┐
                                  │     Worker     │
                                  │ Async Consumer │
                                  └────────┬───────┘
                                           │
                                           ▼
                                External Webhook Endpoints
```

---

# What This Repository Manages

This infrastructure layer orchestrates:

| Service | Responsibility |
|---|---|
| Gateway | Public API ingress |
| Worker | Async webhook delivery |
| PostgreSQL | Persistent storage |
| Redis | Cache + queue |
| Prometheus | Metrics scraping |
| Kubernetes | Container orchestration |
| Docker Compose | Local container runtime |

---

# Repository Structure

```text
infra/
│
├── docker-compose.yml
├── prometheus.yml
├── .env
│
├── k8s/
│   ├── namespace.yaml
│   ├── gateway.yaml
│   ├── worker.yaml
│   ├── postgres.yaml
│   ├── redis.yaml
│   ├── gateway-hpa.yaml
│   ├── worker-hpa.yaml
│   ├── postgres-pvc.yaml
│   ├── postgres-secret.yaml
│
├── postgres/
│   └── init.sh
│
└── README.md
```

---

# Core Infrastructure Concepts Demonstrated

This phase introduces several major infrastructure engineering concepts.

---

## 1. Containerization

All services run inside isolated Docker containers.

Benefits:
- reproducibility
- environment consistency
- deployment portability
- dependency isolation

---

## 2. Distributed System Topology

Ferrum is no longer a monolith.

The system is now composed of independently running services:

- gateway
- worker
- postgres
- redis
- prometheus

Each service communicates over an internal network.

---

## 3. Infrastructure as Code

Infrastructure is declared through:
- Docker Compose YAML
- Kubernetes manifests

This means:
- infrastructure is version-controlled
- environments are reproducible
- deployments are deterministic

---

## 4. Kubernetes Orchestration

Phase 7 introduces Kubernetes concepts:

| Concept | Usage |
|---|---|
| Deployment | manages pods |
| Service | internal networking |
| ConfigMap | environment variables |
| Secret | registry authentication |
| Namespace | logical isolation |
| ReplicaSet | pod replication |
| Pod | execution unit |
| HPA | horizontal autoscaling |
| PVC | persistent postgres storage |
| Probes | readiness/liveness health checking |
| Requests/Limits | autoscaling + scheduling |

---

## 5. Registry-Based Deployments

Infrastructure no longer builds local images.

Instead:
- GitHub Actions builds images
- pushes them to GHCR
- Kubernetes pulls them dynamically

This is the foundation of modern CI/CD systems.

---

## 6. Horizontal Pod Autoscaling
Phase 8 introduces autoscaling.

Kubernetes dynamically increases or decreases replicas based on:

- CPU utilisation
- observed workload

This allows the system to:

- absorb traffic spikes
- scale elastically
- reduce idle resource usage
---

# Local Development Modes

Ferrum now supports two runtime modes:

| Mode | Purpose |
|---|---|
| Docker Compose | local development |
| Kubernetes (Minikube) | orchestration simulation |

---

# Running Ferrum with Docker Compose

---

# Prerequisites

Install:

- Docker Desktop
- Docker Compose

Verify:

```bash
docker --version
docker compose version
```

---

# Environment Configuration

Create `.env`:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres

DB_HOST=postgres
DB_PORT=5432
DB_NAME=ferrum_db
DB_USER=ferrum_user
DB_PASSWORD=password

REDIS_HOST=redis
REDIS_PORT=6379

GITHUB_ORG=ferrum-webhooks
GATEWAY_REPO=ferrum-webhook-gateway
WORKER_REPO=ferrum-webhook-worker
IMAGE_TAG=latest
```

---

# Start Infrastructure

```bash
docker compose up
```

Or rebuild:

```bash
docker compose up --build
```

---

# Verify Running Containers

```bash
docker ps
```

Expected:
- gateway
- worker
- postgres
- redis
- prometheus

---

# Access Services

| Service | URL |
|---|---|
| Gateway | http://localhost:8000 |
| Prometheus | http://localhost:9090 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

---

# Prometheus Metrics

Gateway metrics:
```text
http://localhost:8000/metrics
```

Worker metrics:
```text
http://localhost:8001/metrics
```

---

# Running Ferrum on Kubernetes (Phase 7)

---

# Prerequisites

Install:

- Docker Desktop
- kubectl
- Minikube

Verify:

```bash
kubectl version --client
minikube version
```

---

# Step 1 — Start Kubernetes Cluster

```bash
minikube start
```

Verify:

```bash
kubectl get nodes
```

Expected:
```text
STATUS = Ready
```

---

# Step 2 — Create Namespace

Ferrum runs in an isolated namespace.

```bash
kubectl apply -f k8s/namespace.yaml
```

Verify:

```bash
kubectl get namespaces
```

Expected:
```text
ferrum
```

---

# Step 3 — Create ConfigMaps

Environment variables are injected using ConfigMaps.

```bash
kubectl create configmap ferrum-config \
  --from-env-file=.env \
  -n ferrum
```

Verify:

```bash
kubectl get configmap ferrum-config -n ferrum
```

Then create the postgres initialisation for postgres to pick up from:

```bash
kubectl create configmap postgres-init \
  --from-file=postgres/init.sh \
  -n ferrum                          
```

Verify:

```bash
kubectl get configmap postgres-init -n ferrum
```

Create Postgres secret:
```bash
kubectl apply -f k8s/postgres-secret.yaml
```

---

# Step 4 — Create GHCR Pull Secret

Required for pulling private images from GitHub Container Registry.

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  -n ferrum
```

Verify:

```bash
kubectl get secrets -n ferrum
```

---

# Step 5 - Create Persistent Volume Claim

```bash
kubectl apply -f k8s/postgres-pvc.yaml
```

Verify:
```bash
kubectl get pvc -n ferrum
```

---

# Step 6 — Deploy Infrastructure

```bash
export $(cat .env | xargs)
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/redis.yaml
envsubst < k8s/gateway.yaml | kubectl apply -f -
envsubst < k8s/worker.yaml | kubectl apply -f -


kubectl apply -f k8s/gateway-hpa.yaml
kubectl apply -f k8s/worker-hpa.yaml
```

This creates:
This creates:
- deployments
- services
- pods
- autoscalers
- networking
- persistent storage
---

# Step 7 - Load Test

Create a load test configmap:
```bash
kubectl create configmap k6-test \
  --from-file=tests/load-test.js \
  -n ferrum
```
Run it:
```bash
kubectl run k6 \
  --rm -i --tty \
  --image=grafana/k6 \
  --restart=Never \
  -n ferrum \
  --overrides='
{
  "spec": {
    "containers": [
      {
        "name": "k6",
        "image": "grafana/k6",
        "command": ["k6", "run", "/scripts/load-test.js"],
        "volumeMounts": [
          {
            "name": "scripts",
            "mountPath": "/scripts"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "scripts",
        "configMap": {
          "name": "k6-test"
        }
      }
    ]
  }
}'
```

Expected result would look something like:
```bash
  █ TOTAL RESULTS 

    HTTP
    http_req_duration..............: avg=368.2ms  min=39.5ms  med=318.97ms max=2.21s p(90)=603.9ms  p(95)=704.65ms
      { expected_response:true }...: avg=368.2ms  min=39.5ms  med=318.97ms max=2.21s p(90)=603.9ms  p(95)=704.65ms
    http_req_failed................: 0.00%  0 out of 8179
    http_reqs......................: 8179   135.360515/s

    EXECUTION
    iteration_duration.............: avg=368.25ms min=39.55ms med=319.04ms max=2.21s p(90)=603.92ms p(95)=704.72ms
    iterations.....................: 8179   135.360515/s
    vus............................: 50     min=50        max=50
    vus_max........................: 50     min=50        max=50

    NETWORK
    data_received..................: 1.9 MB 31 kB/s
    data_sent......................: 1.7 MB 28 kB/s
```

---

# Step 8 — Observe Pods and verify autoscaling

```bash
kubectl get pods -n ferrum -w
kubectl get hpa -n ferrum -w
```

---

# Step 9 — Access Gateway

Get service info:

```bash
kubectl get svc -n ferrum
```
OR, to open directly:
```bash
minikube service gateway -n ferrum
```

---

# Step 10 — Test End-to-End Flow

## Create webhook

```bash
curl -X POST http://<url:port>/webhooks \
-H "Content-Type: application/json" \
-d '{
  "url":"https://webhook.site/your-id",
  "event_type":"test"
}'
```

---

## Send event

```bash
curl -X POST http://<url:port>/events \
-H "Content-Type: application/json" \
-d '{
  "payload":{"hello":"world"},
  "event_type":"test"
}'
```

---

# Observability

---

# Prometheus

Prometheus scrapes:
- gateway metrics
- worker metrics

Configured in:

```text
prometheus.yml
```

---

# Important Metrics

---

## Gateway Metrics

### Request throughput

```promql
gateway_requests_total
```

---

### Request latency

```promql
rate(gateway_request_latency_seconds_sum[1m])
```

---

## Worker Metrics

### Events processed

```promql
worker_events_processed_total
```

---

### Queue delay

```promql
worker_queue_delay_seconds_sum / worker_queue_delay_seconds_count
```

---

### p95 queue latency

```promql
histogram_quantile(
  0.95,
  rate(worker_queue_delay_seconds_bucket[1m])
)
```

---

# Reliability Improvements
---
## Readiness Probes
Gateway:
```yaml
readinessProbe:
  httpGet:
    path: /
    port: 8000
```
Worker:
```yaml
readinessProbe:
  httpGet:
    path: /metrics
    port: 8001
```
---
## Liveness Probe
Containers are automatically restarted if unhealthy.
---
## Resource Requests and Limits

Every service now declares:

- minimum CPU
- minimum memory
- maximum CPU
- maximum memory

Required for:

- predictable scheduling
- autoscaling
- cluster stability
---
## Persistent PostgreSQL Storage

Postgres now uses a PersistentVolumeClaim.

Without this:

- pod restart = total data loss
---
## Image Pull Policy

Containers use:
```yaml
imagePullPolicy: Always
```
Ensures Kubernetes always pulls the newest image.

---

# CI/CD Pipeline Integration

Phase 6 introduced automated image pipelines.

Flow:

```text
Git Push
   ↓
GitHub Actions
   ↓
Tests
   ↓
Docker Build
   ↓
Push to GHCR
   ↓
Kubernetes Pulls Image
```

---

# Useful Debugging Commands

---

## View pod logs

```bash
kubectl logs <pod> -n ferrum
```

---

## Previous crash logs

```bash
kubectl logs <pod> -n ferrum --previous
```

---

## Describe pod

```bash
kubectl describe pod <pod> -n ferrum
```

---

## Restart deployment

```bash
kubectl rollout restart deployment gateway -n ferrum
```

---

## Delete namespace

```bash
kubectl delete namespace ferrum
```

---

# Current System Status

## Completed

✅ Distributed architecture
✅ Dockerized services
✅ Redis queue system
✅ PostgreSQL persistence
✅ Metrics instrumentation
✅ Prometheus monitoring
✅ GitHub Actions CI/CD
✅ GHCR registry deployments
✅ Kubernetes orchestration
✅ Namespace isolation
✅ Readiness/liveness probes
✅ Persistent storage
✅ Horizontal Pod Autoscaling
✅ Load testing with k6

---

# Deliberate Gaps (Future Phases)

These are intentionally deferred:

- JWT authentication
- retry system
- dead letter queue
- rate limiting
- horizontal autoscaling
- readiness probes
- liveness probes
- Grafana dashboards
- tracing
- async SQLAlchemy
- Kafka/RabbitMQ migration
- Helm charts
- Terraform infrastructure
- service mesh
- distributed tracing

---

# Summary

Before infrastructure phases:

```text
App runs on your laptop
```

Now:

```text
System deploys as a distributed platform
```

This is the transition from:
- backend coding
to:
- platform engineering
- DevOps
- distributed systems
- cloud-native architecture