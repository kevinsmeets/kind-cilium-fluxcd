#!/bin/bash
#
# Build Docker images and push to local registry.
#
# An optional extra CA certificate (e.g. a corporate MITM proxy CA such as
# Zscaler) can be injected into every image by setting the EXTRA_CA_CERT
# environment variable to the path of the certificate file. If EXTRA_CA_CERT
# is unset or empty, images are built without any extra CA — useful for users
# who are not behind such a proxy.
#
# Prerequisites:
#   - Docker is running
#   - For push operations: local Docker registry is running on localhost:5001
#   - Optional: EXTRA_CA_CERT points to a readable PEM-encoded CA certificate
#
# Can be run standalone or sourced by other scripts for individual functions.
#
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_DIR="$(cd "${_SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../versions.env
source "${_PROJECT_DIR}/versions.env"

# Validate the optional extra CA cert: if the variable is set but the file
# does not exist, fail early. If unset/empty, simply skip injection.
_check_extra_ca_cert() {
    if [[ -n "${EXTRA_CA_CERT:-}" && ! -f "$EXTRA_CA_CERT" ]]; then
        echo "ERROR: EXTRA_CA_CERT is set to '$EXTRA_CA_CERT' but the file does not exist."
        echo "Either unset EXTRA_CA_CERT or point it at a valid PEM-encoded CA certificate."
        exit 1
    fi
}

# Stage the extra CA cert (or an empty placeholder) into the build context so
# the Dockerfile's COPY always succeeds. Each Dockerfile decides at build
# time whether to trust the file based on its size.
# Usage: _stage_extra_ca <dockerfile_dir>
_stage_extra_ca() {
    local dir="$1"
    local dest="${dir}/${EXTRA_CA_CERT_FILENAME}"
    if [[ -n "${EXTRA_CA_CERT:-}" && -f "$EXTRA_CA_CERT" ]]; then
        cp "$EXTRA_CA_CERT" "$dest"
    else
        : >"$dest"
    fi
}

# Build, tag, push, and clean up the staged cert.
# Usage: _build_and_push <dockerfile_dir> <image_name> [push_to_registry=true]
_build_and_push() {
    local dir="$1"
    local image_name="$2"
    local push_to_registry="${3:-true}"

    echo "----------"
    echo "Building ${image_name}..."

    _stage_extra_ca "$dir"
    docker build --tag "$image_name" "$dir"
    rm -f "${dir}/${EXTRA_CA_CERT_FILENAME}"

    if [[ "$push_to_registry" == "true" ]]; then
        local registry_image="${REGISTRY}/${image_name}"
        docker tag "$image_name" "$registry_image"
        docker push "$registry_image"
        docker rmi "$registry_image"
        docker rmi "$image_name"
    fi
}

build_kind_node() {
    _check_extra_ca_cert
    echo
    echo "=== Building KinD node image ==="
    _build_and_push "${_PROJECT_DIR}/dockerfiles/kind-node" "$KIND_NODE_IMAGE" false
}

build_proxy() {
    _check_extra_ca_cert
    echo
    echo "=== Building Docker registry proxy ==="
    _build_and_push "${_PROJECT_DIR}/dockerfiles/docker-registry-proxy" \
        "rpardini/docker-registry-proxy:${DOCKER_REGISTRY_PROXY_VERSION}"
}

build_flux_controllers() {
    _check_extra_ca_cert
    echo
    echo "=== Building FluxCD controller images ==="
    _build_and_push "${_PROJECT_DIR}/dockerfiles/helm-controller" \
        "helm-controller:${HELM_CONTROLLER_VERSION}"
    _build_and_push "${_PROJECT_DIR}/dockerfiles/kustomize-controller" \
        "kustomize-controller:${KUSTOMIZE_CONTROLLER_VERSION}"
    _build_and_push "${_PROJECT_DIR}/dockerfiles/notification-controller" \
        "notification-controller:${NOTIFICATION_CONTROLLER_VERSION}"
    _build_and_push "${_PROJECT_DIR}/dockerfiles/source-controller" \
        "source-controller:${SOURCE_CONTROLLER_VERSION}"
}

build_podinfo() {
    _check_extra_ca_cert
    echo
    echo "=== Building podinfo image ==="
    _build_and_push "${_PROJECT_DIR}/dockerfiles/podinfo" \
        "podinfo:${PODINFO_VERSION}"
}

build_all() {
    build_kind_node
    build_proxy
    build_flux_controllers
    build_podinfo
}

# If run directly (not sourced), parse args and execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    BUILD_NODE=false
    BUILD_FLUX=false
    BUILD_PODINFO=false
    BUILD_PROXY=false
    BUILD_ALL=false

    usage() {
        echo "Usage: $0 [options]"
        echo
        echo "Build Docker images, optionally injecting an extra CA certificate."
        echo
        echo "Options:"
        echo "  -h, --help       Show this help message"
        echo "  -n, --node       Build KinD node image only"
        echo "  -f, --flux       Build FluxCD controller images only"
        echo "  -p, --podinfo    Build podinfo image only"
        echo "  -x, --proxy      Build Docker registry proxy image only"
        echo "  -a, --all        Build all images (default if no options given)"
        echo
        echo "Environment variables:"
        echo "  EXTRA_CA_CERT    Optional path to a PEM-encoded CA certificate"
        echo "                   to inject into every image (e.g. corporate"
        echo "                   MITM proxy CA). Leave unset to skip."
    }

    if [[ $# -eq 0 ]]; then
        BUILD_ALL=true
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            -n | --node) BUILD_NODE=true ;;
            -f | --flux) BUILD_FLUX=true ;;
            -p | --podinfo) BUILD_PODINFO=true ;;
            -x | --proxy) BUILD_PROXY=true ;;
            -a | --all) BUILD_ALL=true ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    echo "=========="
    echo "Building Docker images"
    if [[ -n "${EXTRA_CA_CERT:-}" ]]; then
        echo "Extra CA cert: $EXTRA_CA_CERT"
    else
        echo "Extra CA cert: (none — set EXTRA_CA_CERT to inject one)"
    fi
    echo "Registry:      $REGISTRY"
    echo "=========="

    if [[ "$BUILD_ALL" == "true" ]]; then
        build_all
    else
        [[ "$BUILD_NODE" == "true" ]] && build_kind_node
        [[ "$BUILD_PROXY" == "true" ]] && build_proxy
        [[ "$BUILD_FLUX" == "true" ]] && build_flux_controllers
        [[ "$BUILD_PODINFO" == "true" ]] && build_podinfo
    fi

    echo
    echo "=========="
    echo "Image build complete!"
    echo "Check http://${REGISTRY}/v2/_catalog"
    echo "=========="
fi
