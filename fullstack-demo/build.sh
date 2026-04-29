#!/bin/bash
set -euo pipefail

# Source the central versions.env for EXTRA_CA_CERT and REGISTRY
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
source "${PROJECT_ROOT}/versions.env"

# Stage the optional extra CA cert (or an empty placeholder if not provided)
# into the build context so the Dockerfile's COPY always succeeds.
STAGED_CERT="$SCRIPT_DIR/${EXTRA_CA_CERT_FILENAME}"
if [[ -n "${EXTRA_CA_CERT:-}" ]]; then
    if [[ ! -f "$EXTRA_CA_CERT" ]]; then
        echo "ERROR: EXTRA_CA_CERT='$EXTRA_CA_CERT' is set but does not exist."
        exit 1
    fi
    cp -f "$EXTRA_CA_CERT" "$STAGED_CERT"
else
    : > "$STAGED_CERT"
fi

# Build and push the image to the local registry
cd "$SCRIPT_DIR"
docker build --no-cache -t "$REGISTRY/fullstack-demo:latest" .
docker push "$REGISTRY/fullstack-demo:latest"

# Clean up the staged cert from the build context
rm -f "$STAGED_CERT"

# --- Patch k8s.yaml with current CNPG app user password and deploy ---
PG_NAMESPACE="postgres"
PG_SECRET="postgres-app"
PG_PASSWORD=$(kubectl get secret "$PG_SECRET" -n "$PG_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)




# Patch only POSTGRES_PASSWORD to the generated password

# Patch only the value for POSTGRES_PASSWORD, never touch POSTGRES_USER or POSTGRES_DB
TMP_K8S_YAML=$(mktemp)
awk -v pw="$PG_PASSWORD" '
  $0 ~ /name: POSTGRES_PASSWORD/ {
    print;
    getline;
    print "          value: \"" pw "\"";
    next;
  }
  $0 ~ /name: POSTGRES_USER/ || $0 ~ /name: POSTGRES_DB/ {
    print;
    getline;
    print;
    next;
  }
  {print}
' "$SCRIPT_DIR/k8s.yaml" > "$TMP_K8S_YAML"

echo "Deploying fullstack-demo with current PostgreSQL app user password..."
kubectl apply -f "$TMP_K8S_YAML"
rm -f "$TMP_K8S_YAML"

echo "Image built and pushed to $REGISTRY/fullstack-demo:latest"
