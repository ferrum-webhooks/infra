# infra

Everything for running, deploying and measuring **Ferrum**, a service that delivers webhooks reliably ([API](https://github.com/ferrum-webhooks/ferrum-webhook-gateway) + [worker](https://github.com/ferrum-webhooks/ferrum-webhook-worker)). No application code lives here.

| Folder | What it holds |
|---|---|
| `local/` | `stack.sh`: starts the whole system on your computer with one command, on its own ports |
| `k8s/` | Kubernetes files for the app, database, Redis and monitoring |
| `k8s/secret/` | secret **templates** only (every value `CHANGE_ME`) and a script that creates random ones |
| `charts/ferrum/` | a Helm chart for the app (checked, but not yet installed on a real cluster) |
| `tests/` | an end-to-end check, a test receiver, and a load-test script |
| `bench/` | the speed tests behind the numbers in the docs |

## Run it locally

You need PostgreSQL and Redis installed, and the gateway and worker repositories next to this one, each with its virtualenv (see their READMEs).

```bash
infra/local/stack.sh up          # about 10 seconds
python infra/tests/smoke.py --base http://127.0.0.1:8100       # use a virtualenv's python; 13 checks should pass
infra/local/stack.sh down
```
Other commands: `status`, `psql`, `restart gateway|worker`, `kill9 worker` (simulate a crash), `clean`, `doctor` (find leftover processes), `reset`.

## Run it on Kubernetes (minikube example)

```bash
export TAG=dev-$(date +%H%M%S)        # use a new tag every build; local clusters keep the old image for a reused tag
docker build -t ghcr.io/ferrum-local/gateway:$TAG ../ferrum-webhook-gateway
docker build -t ghcr.io/ferrum-local/worker:$TAG  ../ferrum-webhook-worker
minikube image load ghcr.io/ferrum-local/gateway:$TAG ghcr.io/ferrum-local/worker:$TAG

kubectl apply -f k8s/namespace/ -f k8s/config/ -f k8s/pvc/
k8s/secret/create-secrets.sh ferrum                 # makes random secrets in the cluster; nothing is saved to files
kubectl apply -f k8s/services/postgres.yaml -f k8s/services/redis.yaml -f k8s/services/jaeger.yaml
helm upgrade --install ferrum charts/ferrum -n ferrum --set image.tag=$TAG --set image.pullPolicy=IfNotPresent
```
More detail (health checks, sizing, plain-manifest route): [deployment guide](https://github.com/ferrum-webhooks/docs/blob/main/deployment.md).

## Secrets

Nothing sensitive is stored in git. To replicate: run `k8s/secret/create-secrets.sh`, **or** copy each `*.example.yaml` to the same name without `.example`, replace every `CHANGE_ME`, and apply it (those copies are ignored by git).

## Speed tests

They push the computer hard and use their own database on port 5544 and Redis on 6390. Keep the laptop awake (`caffeinate -dims`) and run `local/stack.sh doctor` first.

| Script | Answers |
|---|---|
| `bench/ablation.sh` | which change made it faster? |
| `bench/scaling.sh` | how does it scale with more API processes, and where does it saturate? |
| `bench/tracing_overhead.sh` | what does tracing cost? (needs Docker) |
| `bench/e2e_latency.sh`, `drain_rate.sh` | how fast does the whole path run, and how fast do workers catch up? |
| `bench/count_statements.py` | how many database round trips per event? |

MIT licensed.
