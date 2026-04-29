#!/bin/bash
# Retrieve the current CNPG-generated app user password for the fullstack-demo app
# Usage: ./get-postgres-app-password.sh

set -euo pipefail

# Namespace and secret name for CNPG-managed PostgreSQL
PG_NAMESPACE="postgres"
PG_SECRET="postgres-app"

# Extract and decode the password
PASSWORD=$(kubectl get secret "$PG_SECRET" -n "$PG_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)

# Output the password (for scripting, export, or patching)
echo "$PASSWORD"
