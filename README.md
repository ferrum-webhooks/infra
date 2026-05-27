# Ferrum — Infrastructure Repository 

## Overview

This repository defines the **runtime orchestration layer** for Ferrum.
This repository is responsible for:

* distributed runtime orchestration
* container networking
* Kubernetes deployment management
* observability infrastructure
* autoscaling configuration
* failure injection testing
* production readiness configuration
* persistent infrastructure configuration
* service discovery
* local cloud simulation
* CI/CD deployment integration

This repository does not contain application business logic.

Instead, it manages the operational environment required for the gateway and worker services to function as a distributed platform.

The infrastructure evolved from a simple Docker Compose runtime into a Kubernetes-orchestrated distributed system with:

* autoscaling
* observability
* failure recovery
* retry handling
* dead letter queues
* rolling deployments
* persistent volumes
* readiness/liveness probes
* Prometheus metrics
* structured logging
* production-safe deployment pattern
---


# Final System Architecture

```text
                               ┌────────────────────┐
                               │       Client       │
                               └─────────┬──────────┘
                                         │
                                         ▼
                           ┌──────────────────────────┐
                           │        Gateway           │
                           │     FastAPI Service      │
                           │  Horizontal Autoscaling  │
                           └─────────┬────────────────┘
                                     │
                   ┌─────────────────┴──────────────────┐
                   ▼                                    ▼
         ┌──────────────────┐               ┌──────────────────┐
         │    PostgreSQL    │               │      Redis       │
         │ Persistent State │               │ Queue + Cache    │
         └──────────────────┘               └────────┬─────────┘
                                                      │
                                                      ▼
                                         ┌────────────────────┐
                                         │       Worker       │
                                         │ Async Consumer Pool│
                                         │ Horizontal Scaling │
                                         └─────────┬──────────┘
                                                   │
                          ┌────────────────────────┴────────────────────┐
                          ▼                                             ▼
               ┌──────────────────────┐                    ┌────────────────────┐
               │ Retry Queue Handling │                    │ Dead Letter Queue  │
               └──────────────────────┘                    └────────────────────┘
                                                   
                                                   ▼
                                    External Webhook Endpoints


                ┌────────────────────────────────────────────┐
                │                Observability               │
                └────────────────────────────────────────────┘

                        Prometheus → Metrics Collection
                        Grafana → Dashboards
                        Kubernetes → Health Monitoring
                        Structured Logs → Failure Analysis
```

---

# Repository Responsibilities

| Component      | Responsibility              |
| -------------- | --------------------------- |
| Docker Compose | Local orchestration         |
| Kubernetes     | Container orchestration     |
| Minikube       | Local Kubernetes cluster    |
| PostgreSQL     | Persistent database         |
| Redis          | Queue + cache layer         |
| Prometheus     | Metrics scraping            |
| Grafana        | Visualization dashboards    |
| HPA            | Horizontal pod autoscaling  |
| PVC            | Persistent database storage |
| ConfigMaps     | Environment configuration   |
| Secrets        | Credential management       |
| Deployments    | Replica orchestration       |
| Services       | Internal networking         |
| Probes         | Health verification         |

---

# Repository Structure

```text
infra/
├── README.md
├── docker-compose.yml
├── k8s
│   ├── config
│   │   ├── ferrum-config.yaml
│   │   ├── grafana-datasource-config.yaml
│   │   ├── postgres-init.yaml
│   │   └── prometheus-config.yaml
│   ├── hpa
│   │   ├── gateway-hpa.yaml
│   │   └── worker-hpa.yaml
│   ├── namespace
│   │   └── namespace.yaml
│   ├── pdb
│   │   ├── gateway-pdb.yaml
│   │   └── worker-pdb.yaml
│   ├── pvc
│   │   └── postgres-pvc.yaml
│   ├── secret
│   │   └── postgres-secret.yaml
│   └── services
│       ├── gateway.yaml
│       ├── grafana.yaml
│       ├── postgres.yaml
│       ├── prometheus.yaml
│       ├── redis.yaml
│       └── worker.yaml
├── new.md
├── postgres
│   └── init.sh
├── prometheus.yml
└── tests
    ├── k6-chaos.js
    └── load-test.js
```

---

# Core Infrastructure Concepts Demonstrated

The infrastructure repository progressively introduced production-grade platform engineering concepts.

---

## 1. Containerization

All services execute inside Docker containers.

Benefits achieved:

* reproducible environments
* isolated dependencies
* deterministic deployments
* portable runtimes
* simplified orchestration

---

## 2. Distributed Systems

Ferrum evolved from a single-process application into a distributed service topology.

Final runtime topology:

* gateway service
* worker service
* Redis queue
* PostgreSQL database
* Prometheus monitoring
* Grafana visualization

Each service became independently deployable and scalable.

---

## 3. Infrastructure as Code

All infrastructure is declared through:

* Docker Compose
* Kubernetes manifests
* ConfigMaps
* Secrets
* HPA definitions

This enabled:

* reproducible deployments
* deterministic environments
* version-controlled infrastructure
* rollback capability
* operational consistency

---

## 4. Kubernetes Orchestration

The project introduced real orchestration concepts:

| Kubernetes Concept | Purpose                 |
| ------------------ | ----------------------- |
| Pod                | execution unit          |
| Deployment         | replica management      |
| ReplicaSet         | pod replication         |
| Service            | internal networking     |
| Namespace          | isolation               |
| ConfigMap          | configuration injection |
| Secret             | credential injection    |
| PVC                | persistent storage      |
| HPA                | autoscaling             |
| Probes             | health monitoring       |

---

## 5. Observability Engineering

Ferrum added full metrics instrumentation.

Observability stack:

* Prometheus
* Grafana
* structured logs
* latency histograms
* queue delay metrics
* throughput metrics
* failure counters

This transformed the system from:

```text
"hope it works"
```

into:

```text
measurable operational visibility
```

---

## 6. Resilience Engineering

Phase 9 introduced deliberate infrastructure failures.

Injected failures:

* pod deletion
* Redis outages
* PostgreSQL outages
* latency injection
* retry storms
* webhook failures

This validated:

* autoscaling
* retries
* recovery behavior
* queue durability
* graceful degradation

---

## 7. Production Readiness

The final phase implemented:

* readiness probes
* liveness probes
* rolling deployments
* graceful shutdowns
* resource requests
* resource limits
* persistent storage
* autoscaling stability

This transitioned the system from:

```text
works locally
```

into:

```text
operationally survivable
```

---

# Runtime Modes

Ferrum supports two execution environments.

| Mode                  | Purpose                  |
| --------------------- | ------------------------ |
| Docker Compose        | local development        |
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

# Running Ferrum on Kubernetes 

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
kubectl apply -f k8s/namespace/namespace.yaml
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
kubectl apply -f k8s/config/
```

Verify:

```bash
kubectl get configmap ferrum-config -n ferrum
kubectl get configmap postgres-init -n ferrum
kubectl get configmap prometheus-config -n ferrum
```

Create Postgres secret:
```bash
kubectl apply -f k8s/secret/postgres-secret.yaml
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
kubectl apply -f k8s/pvc/postgres-pvc.yaml
```

Verify:
```bash
kubectl get pvc -n ferrum
```

---

# Step 6 — Deploy Infrastructure

```bash
export $(cat .env | xargs)
kubectl apply -f k8s/services/postgres.yaml
kubectl apply -f k8s/services/redis.yaml
kubectl apply -f k8s/services/prometheus.yaml
kubectl apply -f k8s/services/grafana.yaml
envsubst < k8s/services/gateway.yaml | kubectl apply -f -
envsubst < k8s/services/worker.yaml | kubectl apply -f -

kubectl apply -f k8s/hpa/gateway-hpa.yaml
kubectl apply -f k8s/hpa/worker-hpa.yaml
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

# Step 8 - Chaos testing

```bash
kubectl create configmap k6-chaos-script \
  --from-file=./tests/k6-chaos.js \
  -n ferrum
```
Run it:
```bash
run k6-chaos \
  --image=grafana/k6 \
  --restart=Never \
  --namespace ferrum \
    --overrides='
    {
      "spec": {
        "containers": [
          {
            "name": "k6",
            "image": "grafana/k6",
            "command": ["k6"],
            "args": ["run", "/scripts/k6-chaos.js"],
            "volumeMounts": [
              {
                "name": "k6-script",
                "mountPath": "/scripts"
              }
            ]
          }
        ],
      "volumes": [
        {
          "name": "k6-script",
          "configMap": {
            "name": "k6-chaos-script"
          }
        }
      ]
    }
  }'
```
---

# Step 9 — Observe Pods and verify autoscaling

```bash
kubectl get pods -n ferrum -w
kubectl get hpa -n ferrum -w
```

---

# Step 10 — Access Gateway

Get service info:

```bash
kubectl get svc -n ferrum
```
OR, to open directly:
```bash
minikube service gateway -n ferrum
```

---

# Step 11 — Test End-to-End Flow

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

# Observability Stack

## Prometheus Metrics

Metrics collected:

| Metric                          | Purpose                   |
| ------------------------------- | ------------------------- |
| gateway_requests_total          | throughput                |
| gateway_request_latency_seconds | latency                   |
| worker_events_processed_total   | worker throughput         |
| worker_queue_delay_seconds      | queue backlog             |
| worker_delivery_latency_seconds | outbound webhook latency  |
| worker_delivery_failures_total  | failure rate              |
| end_to_end_latency_seconds      | complete pipeline latency |

---

# Grafana Dashboards

Dashboards visualize:

* request throughput
* p95 latency
* queue delays
* worker throughput
* delivery failures
* CPU usage
* memory usage
* autoscaling events

---

# Phase 8 — Autoscaling Results

## k6 Load Test

### Configuration

| Parameter          | Value     |
| ------------------ | --------- |
| Virtual Users      | 50        |
| Requests Processed | 8,179     |
| Throughput         | 135 req/s |
| Failure Rate       | 0%        |

---

## Gateway Latency Metrics

| Metric          | Value |
| --------------- | ----- |
| Average Latency | 368ms |
| Median Latency  | 318ms |
| p90 Latency     | 603ms |
| p95 Latency     | 704ms |
| Max Latency     | 2.21s |

---

## Autoscaling Results

Gateway scaled dynamically:

```text
1 pod → 5 pods
```

Worker scaled dynamically:

```text
1 pod → 2 pods
```

Kubernetes automatically:

* created new replicas
* distributed load
* terminated excess pods after cooldown

This validated:

* HPA configuration
* CPU-based scaling
* replica reconciliation
* rolling pod scheduling

---

# Phase 9 — Failure Injection Results

Phase 9 intentionally destabilized the infrastructure.

Purpose:

* validate resilience
* measure recovery behavior
* observe cascading failures
* test retry mechanisms

---

## Failure Injection 1 — Pod Deletion

### Injected Failure

```bash
kubectl delete pod <gateway-pod> -n ferrum
```

### Observed Recovery

Kubernetes automatically:

* detected replica loss
* scheduled replacement pod
* recreated container
* restored service availability

Observed behavior:

| Metric              | Result         |
| ------------------- | -------------- |
| Recovery Time       | ~10–20 seconds |
| Manual Intervention | none           |
| Data Loss           | none           |

---

## Failure Injection 2 — Redis Failure

### Injected Failure

```bash
kubectl delete pod redis-xxxxx -n ferrum
```

### Observed Behavior

During outage:

* gateway enqueue operations failed
* worker BRPOP operations blocked
* retries accumulated

After Redis recovery:

* queue resumed automatically
* workers continued processing
* no cluster corruption occurred

---

## Failure Injection 3 — PostgreSQL Failure

### Injected Failure

```bash
kubectl delete pod postgres-xxxxx -n ferrum
```

### Observed Behavior

During outage:

* gateway DB writes failed
* worker delivery persistence failed
* requests returned errors

After recovery:

* PVC preserved data
* database restarted intact
* services resumed normally

This validated persistent volume correctness.

---

## Failure Injection 4 — Artificial Latency

### Injected Latency

Worker delivery path intentionally delayed.

### Result

Observed:

* queue delay growth
* increased p95 latency
* HPA scaling events
* backlog accumulation

Metrics confirmed:

```text
Higher queue delay → higher worker scaling
```

This validated:

* autoscaling sensitivity
* queue observability
* resilience under degraded performance

---

## Failure Injection 5 — Retry Storms

### Injected Failure

Webhook endpoints intentionally returned:

```text
HTTP 500
```

### Observed Behavior

Worker:

* retried failed deliveries
* applied exponential backoff
* prevented immediate retry storms
* eventually routed failed events into DLQ

Metrics observed:

* increased failure counters
* increased retry counters
* growing DLQ size

---

# Phase 10 — Production Readiness

Phase 10 stabilized the infrastructure.

---

## Readiness Probes

Added:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 8000
```

Effect:

* pods only received traffic after startup completion
* prevented connection-refused windows

---

## Liveness Probes

Added:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 8000
```

Effect:

* Kubernetes restarted unhealthy containers automatically
* improved long-running stability

---

## Resource Requests and Limits

Added:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Effect:

* enabled proper HPA calculations
* prevented uncontrolled resource consumption
* improved scheduling stability

---

## Rolling Deployments

Validated:

```bash
kubectl rollout restart deployment gateway -n ferrum
```

Observed:

* zero downtime restarts
* staggered pod replacement
* uninterrupted traffic handling

---

## Graceful Shutdowns

Observed during scaling:

* old pods entered Terminating state
* active requests completed
* replacements became ready before deletion

This validated production-safe deployment behavior.

---

# Major Operational Lessons Learned

---

## 1. Infrastructure Failures Are Different From Application Failures

Examples encountered:

* image pull failures
* secret mismatches
* DB authentication failures
* PVC misconfiguration
* startup race conditions
* autoscaling instability

---

## 2. Observability Is Mandatory

Without metrics:

* queue delays were invisible
* retries were invisible
* scaling behavior was invisible
* latency regressions were invisible

Prometheus and Grafana transformed debugging from guessing into measurement.

---

## 3. Kubernetes Is a Reconciliation System

Kubernetes continuously attempts to restore desired state.

Observed repeatedly during:

* pod deletion
* autoscaling
* rolling updates
* crash recovery

---

## 4. Reliability Requires Redundancy

The system became resilient because:

* multiple replicas existed
* queues decoupled services
* retries handled transient failures
* probes detected unhealthy pods
* PVCs preserved persistent state

---

## 5. Production Stability Is Emergent

Reliability came from layering:

* metrics
* retries
* probes
* autoscaling
* persistence
* observability
* deployment strategies

No single feature made the system production-ready.

---

# Final System Capabilities

## Infrastructure Features

✅ Dockerized services

✅ Kubernetes orchestration

✅ Namespace isolation

✅ Persistent storage

✅ Autoscaling

✅ Rolling deployments

✅ Health probes

✅ Redis queueing

✅ Retry infrastructure

✅ Dead letter queues

✅ Prometheus monitoring

✅ Grafana dashboards

✅ Structured logging

✅ Failure recovery

✅ CI/CD integration

✅ GHCR deployments

---

# Quantitative Outcomes

| Capability                        | Result              |
| --------------------------------- | ------------------- |
| Throughput Tested                 | 135 req/s           |
| Requests Processed                | 8,179               |
| HTTP Failure Rate                 | 0%                  |
| Gateway Autoscaling               | 1 → 5 pods          |
| Worker Autoscaling                | 1 → 2 pods          |
| p95 Latency                       | ~704ms              |
| Recovery From Pod Failure         | automatic           |
| Recovery From Redis Failure       | automatic           |
| Recovery From PostgreSQL Failure  | successful with PVC |
| Zero Downtime Rolling Deployments | validated           |

---

# Engineering Evolution

## Beginning of Project

```text
Single-process backend app
```

## End of Project

```text
Observable distributed cloud-native platform
```

The project evolved from:

* backend development

into:

* platform engineering
* DevOps
* distributed systems engineering
* resilience engineering
* cloud-native infrastructure
* production operations

---

# Phase-by-Phase Breakdown

| Phase    | Focus                          |
| -------- | ------------------------------ |
| Phase 1  | Core FastAPI gateway           |
| Phase 2  | PostgreSQL integration         |
| Phase 3  | Async worker architecture      |
| Phase 4  | Dockerization                  |
| Phase 5  | Observability + metrics        |
| Phase 6  | CI/CD + GHCR                   |
| Phase 7  | Kubernetes orchestration       |
| Phase 8  | Autoscaling + load testing     |
| Phase 9  | Failure injection + resilience |
| Phase 10 | Production readiness           |

---

# Final Summary

Ferrum Infrastructure evolved from:

```text
containers running locally
```

into:

```text
a resilient distributed infrastructure platform
```

By the end of the project, the system demonstrated:

* orchestration
* observability
* autoscaling
* failure recovery
* deployment automation
* production-safe operations
* measurable resilience
* cloud-native architecture patterns

This repository now represents a full-stack infrastructure engineering project rather than simple local container orchestration.
