#!/bin/bash
#
# Delete the KinD cluster and clean up associated Docker containers.
#
set -o errexit

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${_PROJECT_DIR}/versions.env"

CLEANUP_REGISTRY="${CLEANUP_REGISTRY:-true}"
CLEANUP_PROXY="${CLEANUP_PROXY:-true}"

echo "Current KinD clusters:"
kind get clusters

cluster_name="${1:-kind}"

echo "Deleting KinD cluster '${cluster_name}'..."
kind delete cluster --name "$cluster_name"

if [[ "$CLEANUP_PROXY" == "true" ]]; then
    if [ "$(docker inspect -f '{{.State.Running}}' "docker_registry_proxy" 2>/dev/null || true)" == 'true' ]; then
        echo "Stopping Docker registry proxy..."
        docker rm -f docker_registry_proxy
    fi
fi

if [[ "$CLEANUP_REGISTRY" == "true" ]]; then
    if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" == 'true' ]; then
        echo "Stopping local Docker registry..."
        docker rm -f "${REGISTRY_NAME}"
    fi
fi

echo "Cluster '${cluster_name}' deleted."
