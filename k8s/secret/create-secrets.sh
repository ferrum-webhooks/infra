#!/usr/bin/env bash
# Generate random secrets and create them in the cluster. Nothing is written to disk or git.
#   infra/k8s/secret/create-secrets.sh [namespace=ferrum]
#   DRY_RUN=1 infra/k8s/secret/create-secrets.sh        # no cluster needed; prints only the key names, never values
#   FORCE=1   ...                                       # replace existing secrets (see warning)
#
# Warning: Postgres reads DB_PASSWORD only when its volume is first initialised. Replacing the secret afterwards
# does NOT change the database role; rotate the role password in the database too, or recreate the volume.
set -euo pipefail
NS="${1:-ferrum}"
rand() { openssl rand -base64 "$1" | tr -d '=+/\n' | cut -c1-"$2"; }

make() { # name key=value...
  local name="$1"; shift
  local args=()
  for kv in "$@"; do args+=(--from-literal="$kv"); done
  if [ -n "${DRY_RUN:-}" ]; then
    echo "secret/$name keys: $(kubectl create secret generic "$name" -n "$NS" "${args[@]}" --dry-run=client -o jsonpath='{.data}' | python3 -c 'import sys,json;print(", ".join(sorted(json.load(sys.stdin))))')"
    return
  fi
  if kubectl get secret "$name" -n "$NS" >/dev/null 2>&1 && [ -z "${FORCE:-}" ]; then
    echo "secret/$name already exists: left untouched (FORCE=1 to replace)"; return
  fi
  kubectl create secret generic "$name" -n "$NS" "${args[@]}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  echo "secret/$name created"
}

make postgres-secret POSTGRES_USER=postgres "POSTGRES_PASSWORD=$(rand 32 32)" POSTGRES_DB=postgres \
                     DB_USER=ferrum_user "DB_PASSWORD=$(rand 32 32)" DB_NAME=ferrum_db
make ferrum-secret   "JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')"
make grafana-secret  "ADMIN_PASSWORD=$(rand 24 24)"
