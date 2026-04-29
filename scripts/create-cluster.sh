#!/bin/bash
#
# Create a KinD cluster with a local Docker registry and optional registry proxy.
#
# Prerequisites:
#   - Docker is running
#   - kind is installed
#   - The KinD node image (kind-node-extra-ca) has been built
#   - If using the proxy: the proxy image has been pushed to the local registry
#
# Can be run standalone or sourced by other scripts for individual functions.
#
set -o errexit

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${_PROJECT_DIR}/versions.env"

# Set ENABLE_PROXY=false to skip the Docker registry proxy
ENABLE_PROXY="${ENABLE_PROXY:-true}"

setup_docker_network() {
    echo "Creating Docker network 'kind'..."
    docker network create -d bridge kind || true
}

start_registry() {
    if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
        echo "Starting local Docker registry '${REGISTRY_NAME}' on port ${REGISTRY_PORT}..."
        docker run -d \
            --restart=always \
            -p "127.0.0.1:${REGISTRY_PORT}:5000" \
            --network bridge \
            --name "${REGISTRY_NAME}" \
            registry:2
    else
        echo "Local Docker registry '${REGISTRY_NAME}' is already running."
    fi
}

start_proxy() {
    if [[ "${ENABLE_PROXY}" != "true" ]]; then
        echo "Docker registry proxy is disabled (ENABLE_PROXY=${ENABLE_PROXY})."
        return 0
    fi

    if [ "$(docker inspect -f '{{.State.Running}}' "docker_registry_proxy" 2>/dev/null || true)" != 'true' ]; then
        echo "Starting Docker registry proxy..."
        docker run -d \
            --restart=always \
            --name docker_registry_proxy -it \
            --net kind \
            --hostname docker-registry-proxy \
            -p 0.0.0.0:3128:3128 \
            -e ENABLE_MANIFEST_CACHE=true \
            -v "${HOME}/docker_mirror_cache:/docker_mirror_cache" \
            -v "${HOME}/docker_mirror_certs:/ca" \
            -e REGISTRIES="registry.k8s.io k8s.gcr.io gcr.io ghcr.io quay.io docker.elastic.co" \
            "${REGISTRY}/rpardini/docker-registry-proxy:${DOCKER_REGISTRY_PROXY_VERSION}" \
        || {
            echo "WARNING: Could not start Docker registry proxy."
            echo "         Make sure the proxy image is in the local registry."
            echo "         Run: ./scripts/build-images.sh --proxy"
            echo "         Continuing without proxy..."
            ENABLE_PROXY="false"
        }
    else
        echo "Docker registry proxy is already running."
    fi
}

couple_docker_registry_proxy() {
    if [[ "${ENABLE_PROXY}" != "true" ]]; then
        return 0
    fi

    echo "Configuring registry proxy on KinD nodes..."
    local KIND_NAME=${1-kind}
    local SETUP_URL=http://docker-registry-proxy:3128/setup/systemd
    local pids=""
    for NODE in $(kind get nodes --name "$KIND_NAME"); do
        docker exec "$NODE" sh -c "\
            curl $SETUP_URL \
            | sed s/docker\.service/containerd\.service/g \
            | sed '/Environment/ s/\$/ \"NO_PROXY=127.0.0.0\/8,10.0.0.0\/8,172.16.0.0\/12,192.168.0.0\/16\"/' \
            | bash" & pids="$pids $!"
    done
    wait $pids
}

create_kind_cluster() {
    # Optional Docker Hub authentication to avoid rate limits.
    # Set DOCKER_HUB_USERNAME and DOCKER_HUB_PASSWORD environment variables.
    local CONTAINERD_AUTH=""
    if [[ -n "${DOCKER_HUB_USERNAME:-}" && -n "${DOCKER_HUB_PASSWORD:-}" ]]; then
        CONTAINERD_AUTH=$(printf '  [plugins."io.containerd.grpc.v1.cri".registry.configs."registry-1.docker.io".auth]\n    username = "%s"\n    password = "%s"' \
            "${DOCKER_HUB_USERNAME}" "${DOCKER_HUB_PASSWORD}")
    fi

    echo "Creating KinD cluster..."
    cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
${CONTAINERD_AUTH}
nodes:
- role: control-plane
  image: ${KIND_NODE_IMAGE}
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: 127.0.0.1
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    listenAddress: 127.0.0.1
    protocol: TCP

- role: worker
  image: ${KIND_NODE_IMAGE}
  extraPortMappings:
  - containerPort: 80
    hostPort: 30080
    listenAddress: 127.0.0.1
    protocol: TCP

- role: worker
  image: ${KIND_NODE_IMAGE}
  extraPortMappings:
  - containerPort: 80
    hostPort: 30081
    listenAddress: 127.0.0.1
    protocol: TCP

- role: worker
  image: ${KIND_NODE_IMAGE}
  extraPortMappings:
  - containerPort: 80
    hostPort: 30082
    listenAddress: 127.0.0.1
    protocol: TCP

networking:
  disableDefaultCNI: true
  kubeProxyMode: none
EOF
}

configure_containerd_registry() {
    echo "Configuring containerd to use local registry..."
    local REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
    for node in $(kind get nodes); do
        docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
        cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${REGISTRY_NAME}:5000"]
EOF
    done
}

connect_registry_to_kind() {
    echo "Connecting registry to KinD network..."
    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}")" = 'null' ]; then
        docker network connect "kind" "${REGISTRY_NAME}"
    fi
}

document_registry() {
    echo "Documenting local registry in cluster..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

# If run directly (not sourced), execute all steps
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_docker_network
    start_registry
    start_proxy
    create_kind_cluster
    configure_containerd_registry
    couple_docker_registry_proxy
    connect_registry_to_kind
    document_registry
    echo
    echo "KinD cluster with local registry created successfully!"
fi
