#!/bin/bash
#
# Pipeline to create a KinD Kubernetes cluster with Cilium CNI and FluxCD.
#
# This is the main entry point for the kind-cilium-fluxcd project.
# All versions are defined in versions.env.
#
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=versions.env
source "${SCRIPT_DIR}/versions.env"

# Source helper scripts (functions only, not executed)
# shellcheck source=scripts/create-cluster.sh
source "${SCRIPT_DIR}/scripts/create-cluster.sh"
# shellcheck source=scripts/build-images.sh
source "${SCRIPT_DIR}/scripts/build-images.sh"

CREATE_CLUSTER=true
BUILD_IMAGES=false
INSTALL_CILIUM=true
METRICS_SERVER=false
FLUX=false
PODINFO=false
PULL_IMAGES=false
HEADLAMP=false
RELOADER=false
RELOADER_EXAMPLE=false
KUBE_PROMETHEUS_STACK=false
LOKI=false
SEAWEEDFS=false
SEAWEEDFS_EXAMPLE=false
OPENBAO=false
OPENBAO_EXAMPLE=false
CNPG=false
CNPG_EXAMPLE=false
VALKEY=false
VALKEY_EXAMPLE=false
MONGODB=false
MONGODB_EXAMPLE=false
ZABBIX=false

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo " -h, --help              Show this help message"
    echo " -c, --existing-cluster  Use existing cluster (do not create new)"
    echo " -n, --no-cilium         Do not install Cilium CNI (assumes cluster already has a CNI installed)"
    echo " -b, --build-images      Build Docker images (optionally with extra CA cert via EXTRA_CA_CERT)"
    echo " -m, --metrics-server    Deploy kubernetes metrics server"
    echo " -i, --pull-images       Pull Cilium images and push to local container registry"
    echo " -f, --flux              Install FluxCD"
    echo " -p, --podinfo           Install podinfo example with FluxCD"
    echo " -d, --dashboard         Install headlamp kubernetes dashboard"
    echo " -r, --reloader          Install reloader"
    echo " -e, --reloader-example  Deploy an example app demonstrating Reloader (ConfigMap + Deployment)"
    echo " -k, --kube-prometheus   Install kube-prometheus-stack (Prometheus, Grafana, Alertmanager)"
    echo " -l, --loki              Install Grafana Loki + Alloy (log aggregation)"
    echo " -s, --seaweedfs         Install SeaweedFS (S3-compatible object storage)"
    echo " -w, --seaweedfs-example Deploy an example app demonstrating SeaweedFS (upload/download S3 objects)"
    echo " -o, --openbao           Install OpenBao (secret management / key vault)"
    echo " -t, --openbao-example   Deploy an example app demonstrating OpenBao (read secrets from vault)"
    echo " -g, --cnpg              Install CloudNativePG (PostgreSQL database operator)"
    echo " -y, --cnpg-example      Deploy an example app demonstrating CloudNativePG (PostgreSQL read/write)"
    echo " -v, --valkey            Install Valkey (key-value cache, open-source Redis replacement)"
    echo " -x, --valkey-example    Deploy an example app demonstrating Valkey (write/read key-value pairs)"
    echo " -j, --mongodb           Install MongoDB (NoSQL document database)"
    echo " -q, --mongodb-example   Deploy an example app demonstrating MongoDB (insert/query documents)"
    echo " -z, --zabbix            Install Zabbix (monitoring and alerting platform)"
    echo " -a, --all               Install everything (metrics server, fluxcd, podinfo, dashboard, reloader, reloader-example, kube-prometheus-stack, loki, seaweedfs, seaweedfs-example, openbao, openbao-example, cnpg, cnpg-example, valkey, valkey-example, mongodb, mongodb-example, zabbix)"
}

while [ $# -gt 0 ]; do
    if [[ $1 == "-h" || $1 == "--help" ]]; then
        usage
        exit 0
    elif [[ $1 == "-c" || $1 == "--existing-cluster" ]]; then
        CREATE_CLUSTER=false
    elif [[ $1 == "-n" || $1 == "--no-cilium" ]]; then
        INSTALL_CILIUM=false
    elif [[ $1 == "-b" || $1 == "--build-images" ]]; then
        BUILD_IMAGES=true
    elif [[ $1 == "-m" || $1 == "--metrics-server" ]]; then
        METRICS_SERVER=true
    elif [[ $1 == "-i" || $1 == "--pull-images" ]]; then
        PULL_IMAGES=true
    elif [[ $1 == "-f" || $1 == "--flux" ]]; then
        FLUX=true
    elif [[ $1 == "-p" || $1 == "--podinfo" ]]; then
        PODINFO=true
    elif [[ $1 == "-d" || $1 == "--dashboard" ]]; then
        HEADLAMP=true
    elif [[ $1 == "-r" || $1 == "--reloader" ]]; then
        RELOADER=true
    elif [[ $1 == "-e" || $1 == "--reloader-example" ]]; then
        RELOADER_EXAMPLE=true
    elif [[ $1 == "-k" || $1 == "--kube-prometheus" ]]; then
        KUBE_PROMETHEUS_STACK=true
    elif [[ $1 == "-l" || $1 == "--loki" ]]; then
        LOKI=true
    elif [[ $1 == "-s" || $1 == "--seaweedfs" ]]; then
        SEAWEEDFS=true
    elif [[ $1 == "-w" || $1 == "--seaweedfs-example" ]]; then
        SEAWEEDFS_EXAMPLE=true
    elif [[ $1 == "-o" || $1 == "--openbao" ]]; then
        OPENBAO=true
    elif [[ $1 == "-t" || $1 == "--openbao-example" ]]; then
        OPENBAO_EXAMPLE=true
    elif [[ $1 == "-g" || $1 == "--cnpg" ]]; then
        CNPG=true
    elif [[ $1 == "-y" || $1 == "--cnpg-example" ]]; then
        CNPG_EXAMPLE=true
    elif [[ $1 == "-v" || $1 == "--valkey" ]]; then
        VALKEY=true
    elif [[ $1 == "-x" || $1 == "--valkey-example" ]]; then
        VALKEY_EXAMPLE=true
    elif [[ $1 == "-j" || $1 == "--mongodb" ]]; then
        MONGODB=true
    elif [[ $1 == "-q" || $1 == "--mongodb-example" ]]; then
        MONGODB_EXAMPLE=true
    elif [[ $1 == "-z" || $1 == "--zabbix" ]]; then
        ZABBIX=true
    elif [[ $1 == "-a" || $1 == "--all" ]]; then
        METRICS_SERVER=true
        FLUX=true
        HEADLAMP=true
        PODINFO=true
        RELOADER=true
        RELOADER_EXAMPLE=true
        KUBE_PROMETHEUS_STACK=true
        LOKI=true
        SEAWEEDFS=true
        SEAWEEDFS_EXAMPLE=true
        OPENBAO=true
        OPENBAO_EXAMPLE=true
        CNPG=true
        CNPG_EXAMPLE=true
        VALKEY=true
        VALKEY_EXAMPLE=true
        MONGODB=true
        MONGODB_EXAMPLE=true
        ZABBIX=true
    else
        echo "$0: unknown option: $1"
        exit 1
    fi
    shift
done

# Auto-enable dependencies: if an example/consumer is requested, ensure its prerequisite is also enabled
if [[ $METRICS_SERVER == true || $PODINFO == true ]] && [[ $FLUX != true ]]; then
    echo "Note: Enabling FluxCD (required by metrics-server/podinfo)."
    FLUX=true
fi
if [[ $RELOADER_EXAMPLE == true ]] && [[ $RELOADER != true ]]; then
    echo "Note: Enabling Reloader (required by reloader-example)."
    RELOADER=true
fi
if [[ $SEAWEEDFS_EXAMPLE == true ]] && [[ $SEAWEEDFS != true ]]; then
    echo "Note: Enabling SeaweedFS (required by seaweedfs-example)."
    SEAWEEDFS=true
fi
if [[ $OPENBAO_EXAMPLE == true ]] && [[ $OPENBAO != true ]]; then
    echo "Note: Enabling OpenBao (required by openbao-example)."
    OPENBAO=true
fi
if [[ $CNPG_EXAMPLE == true ]] && [[ $CNPG != true ]]; then
    echo "Note: Enabling CloudNativePG (required by cnpg-example)."
    CNPG=true
fi
if [[ $VALKEY_EXAMPLE == true ]] && [[ $VALKEY != true ]]; then
    echo "Note: Enabling Valkey (required by valkey-example)."
    VALKEY=true
fi
if [[ $MONGODB_EXAMPLE == true ]] && [[ $MONGODB != true ]]; then
    echo "Note: Enabling MongoDB (required by mongodb-example)."
    MONGODB=true
fi

echo "----------"
date

# Phase 1: Build images (if requested)
if [[ $BUILD_IMAGES == true ]]; then
    echo "----------"
    echo "Building KinD node image..."
    build_kind_node
fi

# Phase 2: Create cluster
if [[ $CREATE_CLUSTER == true ]]; then
    echo "----------"
    echo "Create kubernetes cluster..."
    setup_docker_network
    start_registry

    if [[ $BUILD_IMAGES == true ]]; then
        echo "----------"
        echo "Building and pushing images to local registry..."
        build_proxy
        build_flux_controllers
        build_podinfo
    fi

    start_proxy
    create_kind_cluster
    configure_containerd_registry
    couple_docker_registry_proxy
    connect_registry_to_kind
    document_registry
fi

# Phase 3: Install Cilium CNI
if [[ $INSTALL_CILIUM == true ]]; then
    echo "----------"
    echo "Install Cilium CNI..."
    CILIUM_AGENT="quay.io/cilium/cilium:${CILIUM_AGENT_TAG}"
    CILIUM_OPERATOR="quay.io/cilium/operator-generic:${CILIUM_OPERATOR_TAG}"
    CILIUM_ENVOY="quay.io/cilium/cilium-envoy:${CILIUM_ENVOY_TAG}"
    HUBBLE_RELAY="quay.io/cilium/hubble-relay:${HUBBLE_RELAY_TAG}"
    HUBBLE_UI_BE="quay.io/cilium/hubble-ui-backend:${HUBBLE_UI_BE_TAG}"
    HUBBLE_UI_FE="quay.io/cilium/hubble-ui:${HUBBLE_UI_FE_TAG}"

    if [ $PULL_IMAGES == true ]; then
        echo "Pulling and pushing images to local registry..."
        for image in "$CILIUM_AGENT" "$CILIUM_OPERATOR" "$CILIUM_ENVOY" "$HUBBLE_RELAY" "$HUBBLE_UI_BE" "$HUBBLE_UI_FE"; do
            docker pull "$image"
            local_image="${REGISTRY}/${image#*/}"
            docker tag "$image" "$local_image"
            docker push "$local_image"
            docker rmi "$local_image"
            docker rmi "$image"
        done
    fi
    echo "----------"
    echo "Install Gateway API CRDs (${GATEWAY_API_VERSION})..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
    # For TLSRoute if needed:
    # kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_API_VERSION}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
    echo "----------"
    echo "Install Prometheus Operator CRDs (required for Cilium ServiceMonitors)..."
    PROMETHEUS_OPERATOR_VERSION="$(helm show chart --repo https://prometheus-community.github.io/helm-charts kube-prometheus-stack --version "${KUBE_PROMETHEUS_STACK_VERSION}" | awk '/^appVersion:/ {print $2}')"
    echo "Prometheus Operator version (from kube-prometheus-stack ${KUBE_PROMETHEUS_STACK_VERSION}): ${PROMETHEUS_OPERATOR_VERSION}"
    kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
    kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml"
    kubectl apply --server-side -f "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml"
    echo "----------"
    echo "Create monitoring namespace (required for Cilium dashboard ConfigMaps)..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    echo "----------"
    echo "Install Cilium helm chart..."
    helm upgrade --install --namespace kube-system --version $CILIUM_HELM_CHART_VERSION --repo https://helm.cilium.io cilium cilium \
    --values - <<EOF
l7Proxy: true
endpointRoutes:
  enabled: true
hostLegacyRouting: true
gatewayAPI:
  enabled: true
ingressController:
  enabled: true
  default: false
  loadbalancerMode: dedicated
l2announcements:
  enabled: true
kubeProxyReplacement: true
k8sServiceHost: kind-control-plane
k8sServicePort: 6443
hostServices:
  enabled: false
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
  repository: localhost:5001/cilium/cilium
  tag: $CILIUM_AGENT_TAG
  digest: ""
  useDigest: false
ipam:
  mode: kubernetes
enableIPv4Masquerade: true
autoDirectNodeRoutes: true
ipv4:
  enabled: true
ipv6:
  enabled: false
bpf:
  masquerade: true
  tproxy: true
ipMasqAgent:
  enabled: true
  config:
    nonMasqueradeCIDRs:
      - 10.244.0.0/8
prometheus:
  enabled: true
  serviceMonitor:
    enabled: true
    trustCRDsExist: true
dashboards:
  enabled: true
  namespace: monitoring
  labelValue: "1"
operator:
  replicas: 3
  image:
    pullPolicy: IfNotPresent
    repository: localhost:5001/cilium/operator
    tag: $CILIUM_OPERATOR_TAG
    digest: ""
    useDigest: false
  prometheus:
    serviceMonitor:
      enabled: true
      trustCRDsExist: true
  dashboards:
    enabled: true
    namespace: monitoring
    labelValue: "1"
envoy:
  enabled: true
  image:
    pullPolicy: IfNotPresent
    repository: localhost:5001/cilium/cilium-envoy
    tag: $CILIUM_ENVOY_TAG
    digest: ""
    useDigest: false
  prometheus:
    serviceMonitor:
      enabled: true
      trustCRDsExist: true
hubble:
  enabled: true
  relay:
    enabled: true
    image:
      pullPolicy: IfNotPresent
      repository: localhost:5001/cilium/hubble-relay
      tag: $HUBBLE_RELAY_TAG
      digest: ""
      useDigest: false
  metrics:
    enableOpenMetrics: true
    enabled:
      - dns:query;ignoreAAAA
      - drop
      - tcp
      - flow
      - port-distribution
      - icmp
      - "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
    serviceMonitor:
      enabled: true
      trustCRDsExist: true
    dashboards:
      enabled: true
      namespace: monitoring
      labelValue: "1"
  dropEventEmitter:
    enabled: true
    interval: 1m
    reasons:
      - auth_required
      - policy_denied
  ui:
    enabled: true
    backend:
      image:
        pullPolicy: IfNotPresent
        repository: localhost:5001/cilium/hubble-ui-backend
        tag: $HUBBLE_UI_BE_TAG
        digest: ""
        useDigest: false
    frontend:
      image:
        pullPolicy: IfNotPresent
        repository: localhost:5001/cilium/hubble-ui
        tag: $HUBBLE_UI_FE_TAG
        digest: ""
        useDigest: false
    ingress:
      enabled: true
      annotations: {}
      className: cilium
      hosts:
        - hubble-ui.k8s.local
routingMode: native
EOF
    cilium status --wait
    kubectl -n kube-system rollout status --watch --timeout=15m deployment/cilium-operator
    kubectl -n kube-system rollout status --watch --timeout=15m daemonset/cilium-envoy
    kubectl -n kube-system rollout status --watch --timeout=15m daemonset/cilium
    kubectl -n kube-system rollout status --watch --timeout=15m deployment/hubble-relay
    kubectl -n kube-system rollout status --watch --timeout=15m deployment/hubble-ui
    echo
    echo "To use hubble, run these commands:"
    echo
    echo "cilium hubble port-forward &"
    echo "hubble status"
    echo "cilium hubble ui"
    echo
    echo "Patching coredns..."
    kubectl -n kube-system apply -f - <<EOF
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . 8.8.8.8 {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
EOF


    kubectl -n kube-system rollout restart deployment coredns

    DEPLOY_CILIUM_LB_CONFIG="TRUE"
    if [ "$DEPLOY_CILIUM_LB_CONFIG" == "TRUE" ]; then
        # 1) Get the IPv4 subnet of the Docker 'kind' network (e.g. 172.18.0.0/16)
        DOCKER_NETWORK_SUBNET="$(
        docker network inspect kind \
            --format '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' \
            | grep -E '^[0-9]+\.' \
            | head -n1
        )"
        if [[ -z "${DOCKER_NETWORK_SUBNET}" ]]; then
            echo "ERROR: Could not determine an IPv4 subnet for docker network 'kind'." >&2
            exit 1
        fi

        # 2) Choose a /24 inside it: x.y.250.0/24
        BASE_IP="${DOCKER_NETWORK_SUBNET%%/*}"
        CIDR="${BASE_IP%.*.*}.250.0/24"

        echo "Using CIDR: ${CIDR}"

        echo "Add CiliumLoadBalancerIPPool..."
        kubectl -n default apply -f - <<EOF
apiVersion: "cilium.io/v2"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "default"
spec:
  blocks:
  - cidr: "$CIDR"
EOF
        echo "Add CiliumL2AnnouncementPolicy..."
        kubectl -n default apply -f - <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default
spec:
  nodeSelector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
  interfaces:
  - ^eth[0-9]+
  externalIPs: true
  loadBalancerIPs: true
EOF
    fi
fi

echo "----------"
if [[ $FLUX == true ]]; then
      echo "Install FluxCD..."
      kubectl create namespace cluster-config --dry-run=client -o yaml | kubectl apply -f -
      flux install --registry ${REGISTRY} --namespace cluster-config --components=source-controller,kustomize-controller,helm-controller,notification-controller
      kubectl -n cluster-config rollout status --watch --timeout=5m deployment/source-controller
      kubectl -n cluster-config rollout status --watch --timeout=5m deployment/kustomize-controller
      kubectl -n cluster-config rollout status --watch --timeout=5m deployment/helm-controller
      kubectl -n cluster-config rollout status --watch --timeout=5m deployment/notification-controller
fi

if [[ $METRICS_SERVER == true ]]; then
    echo "Deploy kubernetes metrics server..."
    flux create source git metrics-server \
        --namespace=cluster-config \
        --url=https://github.com/kubernetes-sigs/metrics-server \
        --tag=v0.8.1 \
        --interval=1h

    flux create kustomization metrics-server \
        --namespace=cluster-config \
        --source=GitRepository/metrics-server \
        --path="./manifests/overlays/release" \
        --target-namespace=kube-system \
        --prune=true \
        --interval=5m

    kubectl -n cluster-config patch kustomization metrics-server --type='merge' --patch "$(cat <<'PATCH'
spec:
  patches:
    - target:
        kind: Deployment
        name: metrics-server
        namespace: kube-system
      patch: |-
        - op: add
          path: /spec/template/spec/containers/0/args/-
          value: --kubelet-insecure-tls
PATCH
)"

    flux reconcile kustomization metrics-server -n cluster-config

    kubectl -n cluster-config wait \
        --for='jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' \
        kustomization/metrics-server --timeout=5m
fi

if [[ $PODINFO == true ]]; then
    echo "Deploy podinfo example application..."
    flux create source git podinfo \
        --namespace=cluster-config \
        --url=https://github.com/stefanprodan/podinfo \
        --tag=${PODINFO_VERSION} \
        --interval=1h

    kubectl create namespace podinfo --dry-run=client -o yaml | kubectl apply -f -

    flux create kustomization podinfo \
        --namespace=cluster-config \
        --source=GitRepository/podinfo \
        --path="./kustomize" \
        --target-namespace=podinfo \
        --prune=true \
        --interval=5m

    kubectl -n cluster-config patch kustomization podinfo --type merge -p '{
"spec": {
    "images": [
      {
        "name": "ghcr.io/stefanprodan/podinfo",
        "newName": "'${REGISTRY}'/podinfo",
        "newTag": "'${PODINFO_VERSION}'"
      }
    ]
  }
}'

    kubectl -n cluster-config wait \
        --for='jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' \
        kustomization/podinfo --timeout=5m

    kubectl -n podinfo apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: podinfo
spec:
  ingressClassName: cilium
  rules:
  - host: podinfo.k8s.local
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: podinfo
            port:
              number: 9898
EOF
fi

if [[ $HEADLAMP == true ]]; then
    helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
    helm upgrade --install headlamp headlamp/headlamp --namespace kube-system --set replicaCount=2
    echo "Access token for dashboard:"
    kubectl -n kube-system create token headlamp
    #echo "Run 'kubectl port-forward -n kube-system service/headlamp 8080:80' to access the dashboard."

    #curl -s https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp-ingress-sample.yaml
    kubectl -n kube-system apply -f - <<EOF
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: headlamp
  namespace: kube-system
spec:
  ingressClassName: cilium
  rules:
  - host: headlamp.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: headlamp
            port:
              number: 80
EOF
fi


if [[ $RELOADER == true ]]; then
    helm repo add stakater https://stakater.github.io/stakater-charts
    helm install reloader stakater/reloader -n reloader --create-namespace
fi

if [[ $RELOADER_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy Reloader example app (ConfigMap + Deployment)..."
    kubectl create namespace reloader-example --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n reloader-example apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: reloader-demo-config
  namespace: reloader-example
  labels:
    app: reloader-demo
data:
  APP_COLOR: "blue"
  APP_MESSAGE: "Hello from Reloader demo!"
---
apiVersion: v1
kind: Secret
metadata:
  name: reloader-demo-secret
  namespace: reloader-example
  labels:
    app: reloader-demo
type: Opaque
stringData:
  API_KEY: "demo-secret-key"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reloader-demo
  namespace: reloader-example
  labels:
    app: reloader-demo
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: reloader-demo
  template:
    metadata:
      labels:
        app: reloader-demo
    spec:
      containers:
      - name: nginx
        image: nginx:${NGINX_ALPINE_VERSION}
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: reloader-demo-config
        - secretRef:
            name: reloader-demo-secret
EOF

    kubectl -n reloader-example rollout status --watch --timeout=5m deployment/reloader-demo
    echo
    echo "Reloader example deployed to namespace 'reloader-example'."
    echo "To test: edit the ConfigMap and watch the pods restart automatically:"
    echo
    echo "  kubectl -n reloader-example edit configmap reloader-demo-config"
    echo "  kubectl -n reloader-example get pods -w"
fi

if [[ $KUBE_PROMETHEUS_STACK == true ]]; then
    echo "----------"
    echo "Install kube-prometheus-stack (v${KUBE_PROMETHEUS_STACK_VERSION})..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update prometheus-community
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --version "${KUBE_PROMETHEUS_STACK_VERSION}" \
        --values - <<EOF
prometheus:
  prometheusSpec:
    retention: 7d
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 2Gi
    storageSpec: {}
grafana:
  enabled: true
  adminPassword: admin
  sidecar:
    dashboards:
      searchNamespace: ALL
  ingress:
    enabled: true
    ingressClassName: cilium
    hosts:
      - grafana.k8s.local
alertmanager:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: cilium
    paths:
      - /
    pathType: Prefix
    hosts:
      - alertmanager.k8s.local
EOF

    kubectl -n monitoring rollout status --watch --timeout=10m deployment/kube-prometheus-stack-operator
    kubectl -n monitoring rollout status --watch --timeout=10m deployment/kube-prometheus-stack-grafana
    echo
    echo "Grafana available at: http://grafana.k8s.local"
    echo "  Username: admin"
    echo "  Password: admin"
    echo "Alertmanager available at: http://alertmanager.k8s.local"
fi

if [[ $LOKI == true ]]; then
    echo "----------"
    echo "Install Grafana Loki (v${LOKI_HELM_CHART_VERSION}) + Alloy (v${ALLOY_HELM_CHART_VERSION})..."
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update grafana
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Install Loki in single-binary (monolithic) mode for local development
    helm upgrade --install loki grafana/loki \
        --namespace monitoring \
        --version "${LOKI_HELM_CHART_VERSION}" \
        --values - <<EOF
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  storage:
    type: filesystem
singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 10Gi
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
gateway:
  enabled: false
monitoring:
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false
lokiCanary:
  enabled: false
test:
  enabled: false
EOF

    kubectl -n monitoring rollout status --watch --timeout=10m statefulset/loki

    # Install Alloy to collect and ship logs to Loki
    helm upgrade --install alloy grafana/alloy \
        --namespace monitoring \
        --version "${ALLOY_HELM_CHART_VERSION}" \
        --values - <<EOF
alloy:
  configMap:
    content: |
      // Discover all pods in the cluster
      discovery.kubernetes "pods" {
        role = "pod"
      }

      // Relabel to set useful labels for log collection
      discovery.relabel "pods" {
        targets = discovery.kubernetes.pods.targets

        rule {
          source_labels = ["__meta_kubernetes_namespace"]
          target_label  = "namespace"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_name"]
          target_label  = "pod"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_container_name"]
          target_label  = "container"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
          target_label  = "app"
        }
      }

      // Collect logs from discovered pods
      loki.source.kubernetes "pods" {
        targets    = discovery.relabel.pods.output
        forward_to = [loki.write.default.receiver]
      }

      // Ship logs to Loki
      loki.write "default" {
        endpoint {
          url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
        }
      }
EOF

    kubectl -n monitoring rollout status --watch --timeout=10m daemonset/alloy

    # Add Loki as a datasource in Grafana if kube-prometheus-stack is installed
    if kubectl get deployment -n monitoring kube-prometheus-stack-grafana &>/dev/null; then
        echo "Adding Loki datasource to Grafana..."
        kubectl -n monitoring apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource-loki
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.monitoring.svc.cluster.local:3100
        isDefault: false
        editable: true
EOF
        # Restart Grafana to pick up the new datasource
        kubectl -n monitoring rollout restart deployment/kube-prometheus-stack-grafana
        kubectl -n monitoring rollout status --watch --timeout=5m deployment/kube-prometheus-stack-grafana
    fi

    echo
    echo "Loki + Alloy deployed to monitoring namespace."
    echo "Explore logs in Grafana: http://grafana.k8s.local -> Explore -> Loki datasource"
fi

if [[ $SEAWEEDFS == true ]]; then
    echo "----------"
    echo "Install SeaweedFS (v${SEAWEEDFS_HELM_CHART_VERSION})..."
    helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
    helm repo update seaweedfs
    kubectl create namespace seaweedfs --dry-run=client -o yaml | kubectl apply -f -

    helm upgrade --install seaweedfs seaweedfs/seaweedfs \
        --namespace seaweedfs \
        --version "${SEAWEEDFS_HELM_CHART_VERSION}" \
        --values - <<EOF
master:
  replicas: 1
  data:
    type: "persistentVolumeClaim"
    size: "1Gi"
  nodeSelector: {}
volume:
  replicas: 1
  data:
    type: "persistentVolumeClaim"
    size: "10Gi"
  idx:
    type: "persistentVolumeClaim"
    size: "1Gi"
  nodeSelector: {}
filer:
  replicas: 1
  extraArgs: ["-s3.iam=false"]
  data:
    type: "persistentVolumeClaim"
    size: "5Gi"
  s3:
    enabled: true
    enableAuth: false
  nodeSelector: {}
s3:
  enabled: false
EOF

    kubectl -n seaweedfs rollout status --watch --timeout=10m statefulset/seaweedfs-master
    kubectl -n seaweedfs rollout status --watch --timeout=10m statefulset/seaweedfs-volume
    kubectl -n seaweedfs rollout status --watch --timeout=10m statefulset/seaweedfs-filer

    # Create an Ingress for the S3 API endpoint (via filer's built-in S3)
    kubectl -n seaweedfs apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: seaweedfs-s3
  namespace: seaweedfs
spec:
  ingressClassName: cilium
  rules:
  - host: s3.k8s.local
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: seaweedfs-filer
            port:
              number: 8333
EOF

    echo
    echo "SeaweedFS deployed to namespace 'seaweedfs'."
    echo "S3 endpoint available at: http://s3.k8s.local"
    echo "Internal S3 endpoint: http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333"
    echo
    echo "Test with AWS CLI (any credentials work, auth is disabled):"
    echo "  export AWS_ACCESS_KEY_ID=admin"
    echo "  export AWS_SECRET_ACCESS_KEY=admin"
    echo
    echo "Create a bucket:"
    echo "  aws --endpoint-url http://s3.k8s.local s3 mb s3://test-bucket"
    echo
    echo "Upload a file:"
    echo "  echo 'hello seaweedfs' > /tmp/test.txt"
    echo "  aws --endpoint-url http://s3.k8s.local s3 cp /tmp/test.txt s3://test-bucket/test.txt"
    echo
    echo "List bucket contents:"
    echo "  aws --endpoint-url http://s3.k8s.local s3 ls s3://test-bucket/"
    echo
    echo "Download a file:"
    echo "  aws --endpoint-url http://s3.k8s.local s3 cp s3://test-bucket/test.txt /tmp/downloaded.txt"
fi

if [[ $SEAWEEDFS_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy SeaweedFS example app (upload/download S3 objects)..."
    kubectl create namespace seaweedfs-example --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n seaweedfs-example apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: seaweedfs-demo-script
  namespace: seaweedfs-example
data:
  demo.sh: |
    #!/bin/sh
    set -e
    S3_ENDPOINT="\${S3_ENDPOINT:-http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333}"
    S3_BUCKET="\${S3_BUCKET:-demo-bucket}"
    POD_NAME="\${HOSTNAME}"

    echo "SeaweedFS S3 demo app starting..."
    echo "Endpoint: \${S3_ENDPOINT}"
    echo "Bucket:   \${S3_BUCKET}"
    echo

    # Configure aws CLI to use the SeaweedFS endpoint
    export AWS_ACCESS_KEY_ID="\${AWS_ACCESS_KEY_ID:-admin}"
    export AWS_SECRET_ACCESS_KEY="\${AWS_SECRET_ACCESS_KEY:-admin}"
    alias s3="aws --endpoint-url \${S3_ENDPOINT} s3"

    # Create the demo bucket (ignore error if it already exists)
    aws --endpoint-url "\${S3_ENDPOINT}" s3 mb "s3://\${S3_BUCKET}" 2>/dev/null || true
    echo "Bucket '\${S3_BUCKET}' ready."

    COUNTER=0
    while true; do
      COUNTER=\$((COUNTER + 1))
      TIMESTAMP="\$(date -Iseconds)"
      OBJECT_KEY="events/\${POD_NAME}/\${COUNTER}.json"

      # Create a JSON document
      PAYLOAD="{\"pod\":\"\${POD_NAME}\",\"counter\":\${COUNTER},\"timestamp\":\"\${TIMESTAMP}\"}"

      # Upload the object
      echo "\${PAYLOAD}" | aws --endpoint-url "\${S3_ENDPOINT}" s3 cp - "s3://\${S3_BUCKET}/\${OBJECT_KEY}"

      # Read it back
      DOWNLOADED="\$(aws --endpoint-url "\${S3_ENDPOINT}" s3 cp "s3://\${S3_BUCKET}/\${OBJECT_KEY}" -)"

      echo "[\${TIMESTAMP}] PUT \${OBJECT_KEY} | GET = \${DOWNLOADED}"

      # List the pod's objects and count them
      OBJ_COUNT="\$(aws --endpoint-url "\${S3_ENDPOINT}" s3 ls "s3://\${S3_BUCKET}/events/\${POD_NAME}/" | wc -l)"
      echo "[\${TIMESTAMP}] Objects stored by \${POD_NAME}: \${OBJ_COUNT}"

      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: seaweedfs-demo
  namespace: seaweedfs-example
  labels:
    app: seaweedfs-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: seaweedfs-demo
  template:
    metadata:
      labels:
        app: seaweedfs-demo
    spec:
      containers:
      - name: seaweedfs-demo
        image: amazon/aws-cli:${AWS_CLI_VERSION}
        command: ["/bin/sh", "/scripts/demo.sh"]
        env:
        - name: S3_ENDPOINT
          value: "http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333"
        - name: S3_BUCKET
          value: "demo-bucket"
        - name: AWS_ACCESS_KEY_ID
          value: "admin"
        - name: AWS_SECRET_ACCESS_KEY
          value: "admin"
        volumeMounts:
        - name: demo-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 64Mi
            cpu: 10m
          limits:
            memory: 128Mi
      volumes:
      - name: demo-script
        configMap:
          name: seaweedfs-demo-script
          defaultMode: 0755
EOF

    kubectl -n seaweedfs-example rollout status --watch --timeout=5m deployment/seaweedfs-demo
    echo
    echo "SeaweedFS example deployed to namespace 'seaweedfs-example'."
    echo "Two pods upload JSON objects and read them back every 10 seconds."
    echo
    echo "Watch the logs:"
    echo "  kubectl -n seaweedfs-example logs -f -l app=seaweedfs-demo"
    echo
    echo "List objects in the demo bucket:"
    echo "  aws --endpoint-url http://s3.k8s.local s3 ls s3://demo-bucket/events/ --recursive"
fi

if [[ $OPENBAO == true ]]; then
    echo "----------"
    echo "Install OpenBao (v${OPENBAO_HELM_CHART_VERSION})..."
    helm repo add openbao https://openbao.github.io/openbao-helm
    helm repo update openbao
    kubectl create namespace openbao --dry-run=client -o yaml | kubectl apply -f -

    # OpenBao runs in standalone mode with file storage on a PersistentVolume,
    # so secrets and tokens survive pod restarts and helm upgrades. Dev mode
    # is intentionally disabled (it would override storage with in-memory).
    helm upgrade --install openbao openbao/openbao \
        --namespace openbao \
        --version "${OPENBAO_HELM_CHART_VERSION}" \
        --values - <<EOF
injector:
  enabled: false
server:
  dev:
    enabled: false
  standalone:
    enabled: true
    config: |
      ui = true

      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        telemetry {
          unauthenticated_metrics_access = "true"
        }
      }
      storage "file" {
        path = "/openbao/data"
      }

      telemetry {
        prometheus_retention_time = "30s"
        disable_hostname = true
      }
  dataStorage:
    enabled: true
    size: 2Gi
    mountPath: "/openbao/data"
    accessMode: ReadWriteOnce
  ingress:
    enabled: true
    ingressClassName: cilium
    hosts:
      - host: openbao.k8s.local
        paths: []
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
  affinity: ""
ui:
  enabled: true
  serviceType: ClusterIP
serverTelemetry:
  serviceMonitor:
    enabled: true
    selectors: {}
    interval: 30s
    scrapeTimeout: 10s
  prometheusRules:
    enabled: false
  grafanaDashboard:
    enabled: true
    defaultLabel: true
    extraAnnotations:
      grafana_folder: "OpenBao"
      k8s-sidecar-target-directory: "/tmp/dashboards/OpenBao"
EOF

    # Wait for the openbao-0 pod to start its container (it will report
    # NotReady until unsealed; we cannot use --for=condition=Ready here).
    echo "Waiting for openbao-0 pod to start..."
    for i in $(seq 1 60); do
        phase="$(kubectl -n openbao get pod openbao-0 -o jsonpath='{.status.phase}' 2>/dev/null || true)"
        if [[ "$phase" == "Running" ]]; then
            break
        fi
        sleep 5
    done

    # Initialize OpenBao on first install: a freshly created file storage
    # vault is uninitialized and sealed. Generate one unseal key + root token
    # and persist them in a Kubernetes Secret so the auto-unsealer (below)
    # and example app can use them across pod restarts.
    if ! kubectl -n openbao get secret openbao-keys >/dev/null 2>&1; then
        echo "Initializing OpenBao (first install)..."
        # Wait until 'bao status' reports a usable state (uninitialized).
        for i in $(seq 1 60); do
            if kubectl -n openbao exec openbao-0 -- bao status -format=json >/tmp/bao-status.json 2>/dev/null \
               || [[ $? -eq 2 ]]; then
                break
            fi
            sleep 2
        done

        OPENBAO_INIT_JSON="$(kubectl -n openbao exec openbao-0 -- \
            bao operator init -key-shares=1 -key-threshold=1 -format=json)"
        OPENBAO_UNSEAL_KEY="$(echo "${OPENBAO_INIT_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["unseal_keys_b64"][0])')"
        OPENBAO_ROOT_TOKEN="$(echo "${OPENBAO_INIT_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["root_token"])')"

        kubectl -n openbao create secret generic openbao-keys \
            --from-literal=unseal-key="${OPENBAO_UNSEAL_KEY}" \
            --from-literal=root-token="${OPENBAO_ROOT_TOKEN}"

        echo "Performing initial unseal..."
        kubectl -n openbao exec openbao-0 -- bao operator unseal "${OPENBAO_UNSEAL_KEY}" >/dev/null
    else
        echo "OpenBao already initialized (openbao-keys Secret exists); skipping init."
    fi

    # Deploy a tiny auto-unsealer Deployment that polls openbao-0 directly
    # via the headless service (which publishes not-ready addresses) and
    # unseals it whenever it reports HTTP 503 (sealed). This makes restarts
    # transparent: PVC keeps the data, unsealer brings it back online.
    kubectl -n openbao apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao-unsealer
  namespace: openbao
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-unsealer-script
  namespace: openbao
data:
  unseal.sh: |
    #!/bin/sh
    set -u
    BAO_ADDR="${BAO_ADDR:-http://openbao-0.openbao-internal.openbao.svc.cluster.local:8200}"
    echo "openbao-unsealer starting; watching ${BAO_ADDR}"
    while true; do
      # /v1/sys/health returns:
      #   200=unsealed/active, 429=standby, 501=not initialized, 503=sealed
      # Match only the response status line (leading whitespace + HTTP/),
      # not the 'wget: server returned error' message which also contains 'HTTP/'.
      CODE=$(wget -T 5 -S -O /dev/null \
              "${BAO_ADDR}/v1/sys/health?standbyok=true&sealedcode=503&uninitcode=501" 2>&1 \
              | awk '/^[[:space:]]+HTTP\// {code=$2} END {print code+0}')
      if [ "$CODE" = "503" ]; then
        echo "$(date -Iseconds) sealed (503) - unsealing..."
        wget -T 5 -q -O - --header='Content-Type: application/json' \
          --post-data="{\"key\":\"${UNSEAL_KEY}\"}" \
          "${BAO_ADDR}/v1/sys/unseal" >/dev/null 2>&1 \
          && echo "$(date -Iseconds) unseal request sent" \
          || echo "$(date -Iseconds) unseal POST failed"
      elif [ "$CODE" = "501" ]; then
        echo "$(date -Iseconds) not initialized (501) - waiting"
      elif [ "$CODE" = "200" ] || [ "$CODE" = "429" ]; then
        : # healthy, no log spam
      else
        echo "$(date -Iseconds) unexpected status: ${CODE}"
      fi
      sleep 5
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao-unsealer
  namespace: openbao
  labels:
    app: openbao-unsealer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao-unsealer
  template:
    metadata:
      labels:
        app: openbao-unsealer
    spec:
      serviceAccountName: openbao-unsealer
      containers:
      - name: unsealer
        image: busybox:1.37
        command: ["/bin/sh", "/scripts/unseal.sh"]
        env:
        - name: BAO_ADDR
          value: "http://openbao-0.openbao-internal.openbao.svc.cluster.local:8200"
        - name: UNSEAL_KEY
          valueFrom:
            secretKeyRef:
              name: openbao-keys
              key: unseal-key
        volumeMounts:
        - name: script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 16Mi
            cpu: 5m
          limits:
            memory: 64Mi
      volumes:
      - name: script
        configMap:
          name: openbao-unsealer-script
          defaultMode: 0755
EOF
    kubectl -n openbao rollout status deployment/openbao-unsealer --timeout=2m

    # Patch the OpenBao dashboard: replace __inputs datasource placeholder with
    # a direct Prometheus datasource reference so Grafana sidecar can use it.
    echo "Patching OpenBao Grafana dashboard datasource..."
    kubectl -n openbao get configmap openbao-dashboard -o json \
      | python3 -c '
import sys, json, re

cm = json.load(sys.stdin)
key = list(cm["data"].keys())[0]
dash = json.loads(cm["data"][key])

# Remove __inputs (import-time placeholders)
dash.pop("__inputs", None)
# Remove __requires
dash.pop("__requires", None)

# Replace all ${DS_PROMXY} datasource references with a Prometheus type ref
raw = json.dumps(dash)
raw = raw.replace("${DS_PROMXY}", "Prometheus")
dash = json.loads(raw)

# Ensure all panel datasource refs use type "prometheus"
def fix_ds(obj, in_panels=False):
    if isinstance(obj, dict):
        if in_panels and (obj.get("uid") == "Prometheus" or obj.get("uid") == "prometheus") and "type" in obj and obj["type"] != "__expr__":
            obj["type"] = "prometheus"
            obj["uid"] = "prometheus"
        for k, v in obj.items():
            fix_ds(v, in_panels=(in_panels or k == "panels"))
    elif isinstance(obj, list):
        for v in obj:
            fix_ds(v, in_panels)

fix_ds(dash)

cm["data"][key] = json.dumps(dash)
json.dump(cm, sys.stdout)
' | kubectl apply -f -

    # Restart Grafana to pick up the patched dashboard
    if kubectl get deployment -n monitoring kube-prometheus-stack-grafana &>/dev/null; then
        kubectl -n monitoring rollout restart deployment/kube-prometheus-stack-grafana
        kubectl -n monitoring rollout status --watch --timeout=5m deployment/kube-prometheus-stack-grafana
    fi

    kubectl -n openbao wait --for=condition=Ready pod/openbao-0 --timeout=10m

    echo
    echo "OpenBao deployed to namespace 'openbao' (persistent file storage on PVC)."
    echo "UI available at: http://openbao.k8s.local"
    echo
    echo "Root token and unseal key are stored in Secret 'openbao-keys' in the openbao namespace."
    echo "Retrieve them with:"
    echo "  kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d; echo"
    echo "  kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.unseal-key}'  | base64 -d; echo"
    echo
    echo "If the openbao-0 pod restarts it comes up sealed; the openbao-unsealer"
    echo "Deployment automatically unseals it within a few seconds."
    echo
    echo "To interact with OpenBao (exec into the openbao-0 pod):"
    echo
    echo "  ROOT=\$(kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d)"
    echo
    echo "Enable a KV secrets engine:"
    echo "  kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN=\"\$ROOT\" bao secrets enable -path=secret kv-v2"
    echo
    echo "Write a secret:"
    echo "  kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN=\"\$ROOT\" bao kv put secret/my-app username=admin password=s3cr3t"
    echo
    echo "Read a secret:"
    echo "  kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN=\"\$ROOT\" bao kv get secret/my-app"
fi

if [[ $OPENBAO_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy OpenBao example app (read secrets from vault)..."

    # Configure OpenBao: enable KV engine, write demo secrets, enable Kubernetes auth
    echo "Configuring OpenBao for the example app..."
    OPENBAO_ROOT_TOKEN="$(kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d)"
    kubectl -n openbao exec openbao-0 -- env BAO_TOKEN="${OPENBAO_ROOT_TOKEN}" sh -c '
        export BAO_ADDR="http://127.0.0.1:8200"

        # Enable KV v2 secrets engine (idempotent - ignore if already enabled)
        bao secrets enable -path=secret kv-v2 2>/dev/null || true

        # Write demo secrets
        bao kv put secret/demo-app \
            username="demo-user" \
            password="P@ssw0rd-from-OpenBao" \
            api-key="bao-dk-1234567890abcdef" \
            database-url="postgresql://demo:secret@cnpg-example-rw.cnpg-example:5432/app"

        # Enable Kubernetes auth method (idempotent)
        bao auth enable kubernetes 2>/dev/null || true

        # Configure Kubernetes auth to use the in-cluster service account
        bao write auth/kubernetes/config \
            kubernetes_host="https://kubernetes.default.svc:443"

        # Create a policy that allows reading the demo secrets
        bao policy write demo-app - <<POLICY
            path "secret/data/demo-app" {
                capabilities = ["read"]
            }
            path "secret/metadata/demo-app" {
                capabilities = ["read", "list"]
            }
POLICY

        # Create a Kubernetes auth role that binds the demo service accounts to
        # the policy. Both the openbao-example demo app and the fullstack-demo
        # app (SA "fullstack-demo" in the "default" namespace) are allowed to
        # log in and read secret/demo-app.
        bao write auth/kubernetes/role/demo-app \
            bound_service_account_names=openbao-demo-app,fullstack-demo \
            bound_service_account_namespaces=openbao-example,default \
            policies=demo-app \
            ttl=1h
    '

    kubectl create namespace openbao-example --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n openbao-example apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao-demo-app
  namespace: openbao-example
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-demo-script
  namespace: openbao-example
data:
  demo.sh: |
    #!/bin/sh
    set -e
    BAO_ADDR="\${BAO_ADDR:-http://openbao.openbao.svc.cluster.local:8200}"
    BAO_ROLE="\${BAO_ROLE:-demo-app}"
    SA_TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"

    echo "OpenBao demo app starting..."
    echo "OpenBao address: \${BAO_ADDR}"
    echo "Auth role: \${BAO_ROLE}"
    echo

    while true; do
      TIMESTAMP="\$(date -Iseconds)"
      echo "[\${TIMESTAMP}] --- Authenticating with OpenBao via Kubernetes auth ---"

      # Read the service account JWT token
      SA_JWT="\$(cat \${SA_TOKEN_PATH})"

      # Authenticate with OpenBao using the Kubernetes auth method
      LOGIN_RESPONSE="\$(wget -qO- --header='Content-Type: application/json' \\
        --post-data="{\\"role\\": \\"\${BAO_ROLE}\\", \\"jwt\\": \\"\${SA_JWT}\\"}" \\
        \${BAO_ADDR}/v1/auth/kubernetes/login 2>&1)" || {
        echo "[\${TIMESTAMP}] ERROR: Failed to authenticate with OpenBao"
        sleep 15
        continue
      }

      # Extract the client token from the JSON response
      CLIENT_TOKEN="\$(echo "\${LOGIN_RESPONSE}" | sed -n 's/.*"client_token":"\\([^"]*\\)".*/\\1/p')"

      if [ -z "\${CLIENT_TOKEN}" ]; then
        echo "[\${TIMESTAMP}] ERROR: No client_token in login response"
        sleep 15
        continue
      fi

      echo "[\${TIMESTAMP}] Authenticated successfully (token: \${CLIENT_TOKEN:0:12}...)"

      # Read secrets from OpenBao using the client token
      SECRETS="\$(wget -qO- --header="X-Vault-Token: \${CLIENT_TOKEN}" \\
        \${BAO_ADDR}/v1/secret/data/demo-app 2>&1)" || {
        echo "[\${TIMESTAMP}] ERROR: Failed to read secrets"
        sleep 15
        continue
      }

      # Parse and display the secrets (mask sensitive values)
      USERNAME="\$(echo "\${SECRETS}" | sed -n 's/.*"username":"\\([^"]*\\)".*/\\1/p')"
      PASSWORD="\$(echo "\${SECRETS}" | sed -n 's/.*"password":"\\([^"]*\\)".*/\\1/p')"
      API_KEY="\$(echo "\${SECRETS}" | sed -n 's/.*"api-key":"\\([^"]*\\)".*/\\1/p')"
      DB_URL="\$(echo "\${SECRETS}" | sed -n 's/.*"database-url":"\\([^"]*\\)".*/\\1/p')"

      echo "[\${TIMESTAMP}] Secrets retrieved from OpenBao:"
      echo "  username:     \${USERNAME}"
      echo "  password:     \${PASSWORD:0:4}********"
      echo "  api-key:      \${API_KEY:0:8}********"
      echo "  database-url: \${DB_URL:0:20}..."
      echo

      sleep 30
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao-demo
  namespace: openbao-example
  labels:
    app: openbao-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: openbao-demo
  template:
    metadata:
      labels:
        app: openbao-demo
    spec:
      serviceAccountName: openbao-demo-app
      containers:
      - name: openbao-demo
        image: busybox:${BUSYBOX_VERSION}
        command: ["/bin/sh", "/scripts/demo.sh"]
        env:
        - name: BAO_ADDR
          value: "http://openbao.openbao.svc.cluster.local:8200"
        - name: BAO_ROLE
          value: "demo-app"
        volumeMounts:
        - name: demo-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 32Mi
            cpu: 10m
          limits:
            memory: 64Mi
      volumes:
      - name: demo-script
        configMap:
          name: openbao-demo-script
          defaultMode: 0755
EOF

    kubectl -n openbao-example rollout status --watch --timeout=5m deployment/openbao-demo
    echo
    echo "OpenBao example deployed to namespace 'openbao-example'."
    echo "Two pods authenticate via Kubernetes auth and read secrets every 30 seconds."
    echo
    echo "Watch the logs:"
    echo "  kubectl -n openbao-example logs -f -l app=openbao-demo"
    echo
    echo "Verify the secrets in OpenBao:"
    echo "  kubectl -n openbao exec -it openbao-0 -- bao kv get secret/demo-app"
fi

if [[ $CNPG == true ]]; then
    echo "----------"
    echo "Install CloudNativePG operator (v${CNPG_HELM_CHART_VERSION})..."
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    helm repo update cnpg
    kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -

    helm upgrade --install cnpg cnpg/cloudnative-pg \
        --namespace cnpg-system \
        --version "${CNPG_HELM_CHART_VERSION}" \
        --values - <<EOF
monitoring:
  podMonitorEnabled: true
  grafanaDashboard:
    create: true
    namespace: monitoring
    labels:
      grafana_dashboard: "1"
EOF

    kubectl -n cnpg-system rollout status --watch --timeout=10m deployment/cnpg-cloudnative-pg

    # Wait for the CNPG webhook to become reachable (Cilium needs time to
    # program the service endpoints after the operator pod is Ready).
    echo "Waiting for CNPG webhook to become ready..."
    for i in $(seq 1 30); do
        if kubectl -n cnpg-system get endpoints cnpg-webhook-service -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; then
            echo "CNPG webhook endpoint is ready."
            break
        fi
        echo "  Attempt $i/30: webhook endpoint not yet available, retrying in 5s..."
        sleep 5
    done

    # Create a PostgreSQL cluster
    kubectl create namespace postgres --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n postgres apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: postgres
spec:
  instances: 1
  storage:
    size: 5Gi
  monitoring:
    enablePodMonitor: true
    customQueriesConfigMap:
      - name: cnpg-default-monitoring
        key: queries
  postgresql:
    parameters:
      shared_buffers: "128MB"
      max_connections: "100"
  bootstrap:
    initdb:
      database: app
      owner: app
EOF

    echo "Waiting for PostgreSQL cluster to be ready..."
    kubectl -n postgres wait --for=condition=Ready cluster/postgres --timeout=10m

    # Patch the CNPG Grafana dashboard: replace __inputs/__requires datasource
    # placeholders with a direct Prometheus datasource reference so the
    # Grafana sidecar can load it without manual import.
    if kubectl get configmap -n monitoring cnpg-grafana-dashboard &>/dev/null; then
        echo "Patching CNPG Grafana dashboard datasource..."
        kubectl -n monitoring get configmap cnpg-grafana-dashboard -o json \
          | python3 -c '
import sys, json

cm = json.load(sys.stdin)
key = list(cm["data"].keys())[0]
dash = json.loads(cm["data"][key])

# Remove __inputs (import-time placeholders)
dash.pop("__inputs", None)
# Remove __requires
dash.pop("__requires", None)

# Replace all ${DS_PROMETHEUS} datasource references
raw = json.dumps(dash)
raw = raw.replace("${DS_PROMETHEUS}", "prometheus")
dash = json.loads(raw)

# Ensure all panel datasource refs use type "prometheus"
def fix_ds(obj, in_panels=False):
    if isinstance(obj, dict):
        # Only fix datasource refs inside panels, not template variables
        if in_panels and obj.get("uid") == "prometheus" and "type" in obj and obj["type"] != "__expr__":
            obj["type"] = "prometheus"
            obj["uid"] = "prometheus"
        for k, v in obj.items():
            fix_ds(v, in_panels=(in_panels or k == "panels"))
    elif isinstance(obj, list):
        for v in obj:
            fix_ds(v, in_panels)

fix_ds(dash)

# Ensure the DS_PROMETHEUS template variable keeps type "datasource"
for v in dash.get("templating", {}).get("list", []):
    if v.get("name") == "DS_PROMETHEUS":
        v["type"] = "datasource"
        v["query"] = "prometheus"
        v["current"] = {"selected": False, "text": "Prometheus", "value": "prometheus"}

cm["data"][key] = json.dumps(dash)
json.dump(cm, sys.stdout)
' | kubectl apply -f -
    fi

    # Restart Grafana to pick up the new dashboards
    if kubectl get deployment -n monitoring kube-prometheus-stack-grafana &>/dev/null; then
        kubectl -n monitoring rollout restart deployment/kube-prometheus-stack-grafana
        kubectl -n monitoring rollout status --watch --timeout=5m deployment/kube-prometheus-stack-grafana
    fi

    echo
    echo "CloudNativePG deployed."
    echo "PostgreSQL cluster 'postgres' running in namespace 'postgres'."
    echo
    echo "Connection details (from within the cluster):"
    echo "  Host: postgres-rw.postgres.svc.cluster.local"
    echo "  Port: 5432"
    echo "  Database: app"
    echo "  Username: app"
    echo "  Password: kubectl -n postgres get secret postgres-app -o jsonpath='{.data.password}' | base64 -d"
    echo
    echo "Connect with psql:"
    echo "  kubectl -n postgres exec -it postgres-1 -- psql -h localhost -U app -d app"
    echo
    echo "Superuser access:"
    echo "  kubectl -n postgres get secret postgres-superuser -o jsonpath='{.data.password}' | base64 -d"
fi

if [[ $CNPG_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy CloudNativePG example app (PostgreSQL read/write)..."
    kubectl create namespace cnpg-example --dry-run=client -o yaml | kubectl apply -f -

    # Copy the postgres-app secret from the postgres namespace
    APP_PASSWORD=$(kubectl -n postgres get secret postgres-app -o jsonpath='{.data.password}')
    kubectl -n cnpg-example apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-app
  namespace: cnpg-example
type: Opaque
data:
  password: "${APP_PASSWORD}"
EOF

    kubectl -n cnpg-example apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cnpg-demo-script
  namespace: cnpg-example
data:
  demo.sh: |
    #!/bin/bash
    set -e

    DB_HOST="${DB_HOST:-postgres-rw.postgres.svc.cluster.local}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:-app}"
    DB_USER="${DB_USER:-app}"
    POD_NAME="${HOSTNAME}"

    export PGPASSWORD="${DB_PASSWORD}"

    echo "CloudNativePG demo app starting..."
    echo "Connecting to ${DB_HOST}:${DB_PORT}/${DB_NAME} as ${DB_USER}"

    # Wait for PostgreSQL to be ready
    until psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &>/dev/null; do
      echo "Waiting for PostgreSQL to be ready..."
      sleep 3
    done
    echo "PostgreSQL is ready."

    # Create demo table if not exists
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
      CREATE TABLE IF NOT EXISTS demo_events (
        id SERIAL PRIMARY KEY,
        pod_name TEXT NOT NULL,
        message TEXT NOT NULL,
        counter INTEGER NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );"
    echo "Table 'demo_events' ready."

    COUNTER=0
    while true; do
      COUNTER=$((COUNTER + 1))
      TIMESTAMP="$(date -Iseconds)"

      # Insert a row
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO demo_events (pod_name, message, counter) VALUES ('${POD_NAME}', 'ping at ${TIMESTAMP}', ${COUNTER});"

      # Count total rows from all pods
      TOTAL=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tA \
        -c "SELECT COUNT(*) FROM demo_events;")

      # Get distinct pod count
      PODS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tA \
        -c "SELECT COUNT(DISTINCT pod_name) FROM demo_events;")

      echo "[${TIMESTAMP}] Inserted row #${COUNTER} from ${POD_NAME} | Total rows: ${TOTAL} | Distinct pods: ${PODS}"

      sleep 10
    done
EOF

    kubectl -n cnpg-example apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cnpg-demo
  namespace: cnpg-example
  labels:
    app: cnpg-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cnpg-demo
  template:
    metadata:
      labels:
        app: cnpg-demo
    spec:
      containers:
      - name: cnpg-demo
        image: postgres:${POSTGRES_VERSION}
        command: ["/bin/bash", "/scripts/demo.sh"]
        env:
        - name: DB_HOST
          value: "postgres-rw.postgres.svc.cluster.local"
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: "app"
        - name: DB_USER
          value: "app"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-app
              key: password
        volumeMounts:
        - name: demo-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 32Mi
            cpu: 10m
          limits:
            memory: 64Mi
      volumes:
      - name: demo-script
        configMap:
          name: cnpg-demo-script
          defaultMode: 0755
EOF

    kubectl -n cnpg-example rollout status --watch --timeout=5m deployment/cnpg-demo
    echo
    echo "CloudNativePG example deployed to namespace 'cnpg-example'."
    echo "Two pods insert rows into the 'demo_events' table every 10 seconds."
    echo
    echo "Watch the logs:"
    echo "  kubectl -n cnpg-example logs -f -l app=cnpg-demo"
    echo
    echo "Query the shared table:"
    echo "  kubectl -n postgres exec -it postgres-1 -- psql -h localhost -U app -d app -c 'SELECT * FROM demo_events ORDER BY id DESC LIMIT 10;'"
fi

if [[ $VALKEY == true ]]; then
    echo "----------"
    echo "Install Valkey (v${VALKEY_HELM_CHART_VERSION})..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update bitnami
    kubectl create namespace valkey --dry-run=client -o yaml | kubectl apply -f -

    helm upgrade --install valkey bitnami/valkey \
        --namespace valkey \
        --version "${VALKEY_HELM_CHART_VERSION}" \
        --values - <<EOF
architecture: standalone
auth:
  enabled: true
  password: "valkey"
primary:
  persistence:
    enabled: true
    size: 1Gi
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 256Mi
replica:
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 256Mi
metrics:
  enabled: true
  resources:
    requests:
      memory: 32Mi
      cpu: 50m
    limits:
      memory: 64Mi
  serviceMonitor:
    enabled: true
    namespace: monitoring
    additionalLabels:
      release: kube-prometheus-stack
  prometheusRule:
    enabled: true
    namespace: monitoring
    additionalLabels:
      release: kube-prometheus-stack
    rules:
      - alert: ValkeyDown
        expr: valkey_up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Valkey instance is down"
          description: 'Valkey instance {{ "{{" }} \$labels.instance {{ "}}" }} is down.'
      - alert: ValkeyHighMemoryUsage
        expr: valkey_memory_used_bytes / valkey_memory_max_bytes * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Valkey high memory usage"
          description: 'Valkey instance {{ "{{" }} \$labels.instance {{ "}}" }} memory usage is above 80%.'
EOF

    kubectl -n valkey rollout status --watch --timeout=10m statefulset/valkey-primary

    # Add Grafana dashboard for Valkey metrics (based on redis-exporter metrics)
    if kubectl get deployment -n monitoring kube-prometheus-stack-grafana &>/dev/null; then
        echo "Adding Valkey Grafana dashboard..."
        kubectl -n monitoring apply -f - <<'DASHBOARD_EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-valkey
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  valkey-dashboard.json: |
    {
      "annotations": { "list": [] },
      "description": "Valkey (Redis-compatible) dashboard for Prometheus redis_exporter metrics",
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 1,
      "links": [],
      "panels": [
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": { "color": { "mode": "thresholds" }, "thresholds": { "steps": [{ "color": "green", "value": null }, { "color": "red", "value": 0.5 }] }, "mappings": [{ "options": { "0": { "text": "DOWN" }, "1": { "text": "UP" } }, "type": "value" }] },
            "overrides": []
          },
          "gridPos": { "h": 4, "w": 4, "x": 0, "y": 0 },
          "id": 1,
          "options": { "colorMode": "background", "graphMode": "none", "justifyMode": "auto", "textMode": "auto", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Status",
          "type": "stat",
          "targets": [{ "expr": "redis_up{namespace=\"valkey\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "s" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 4, "y": 0 },
          "id": 2,
          "options": { "colorMode": "value", "graphMode": "none", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Uptime",
          "type": "stat",
          "targets": [{ "expr": "redis_uptime_in_seconds{namespace=\"valkey\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 8, "y": 0 },
          "id": 3,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Connected Clients",
          "type": "stat",
          "targets": [{ "expr": "redis_connected_clients{namespace=\"valkey\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "bytes" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 12, "y": 0 },
          "id": 4,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Used Memory",
          "type": "stat",
          "targets": [{ "expr": "redis_memory_used_bytes{namespace=\"valkey\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 16, "y": 0 },
          "id": 5,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Total Keys",
          "type": "stat",
          "targets": [{ "expr": "sum(redis_db_keys{namespace=\"valkey\"})", "legendFormat": "keys" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "ops" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 20, "y": 0 },
          "id": 6,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Commands/sec",
          "type": "stat",
          "targets": [{ "expr": "rate(redis_commands_processed_total{namespace=\"valkey\"}[5m])", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "bytes" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 },
          "id": 7,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Memory Usage",
          "type": "timeseries",
          "targets": [
            { "expr": "redis_memory_used_bytes{namespace=\"valkey\"}", "legendFormat": "used" },
            { "expr": "redis_memory_max_bytes{namespace=\"valkey\"}", "legendFormat": "max" },
            { "expr": "redis_memory_used_rss_bytes{namespace=\"valkey\"}", "legendFormat": "rss" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 4 },
          "id": 8,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Connected Clients",
          "type": "timeseries",
          "targets": [
            { "expr": "redis_connected_clients{namespace=\"valkey\"}", "legendFormat": "clients" },
            { "expr": "redis_blocked_clients{namespace=\"valkey\"}", "legendFormat": "blocked" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "ops" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 12 },
          "id": 9,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Commands per Second",
          "type": "timeseries",
          "targets": [{ "expr": "rate(redis_commands_processed_total{namespace=\"valkey\"}[5m])", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 12 },
          "id": 10,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Hits / Misses per Second",
          "type": "timeseries",
          "targets": [
            { "expr": "rate(redis_keyspace_hits_total{namespace=\"valkey\"}[5m])", "legendFormat": "hits" },
            { "expr": "rate(redis_keyspace_misses_total{namespace=\"valkey\"}[5m])", "legendFormat": "misses" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "bytes" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 20 },
          "id": 11,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Network I/O",
          "type": "timeseries",
          "targets": [
            { "expr": "rate(redis_net_input_bytes_total{namespace=\"valkey\"}[5m])", "legendFormat": "input" },
            { "expr": "rate(redis_net_output_bytes_total{namespace=\"valkey\"}[5m])", "legendFormat": "output" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 20 },
          "id": 12,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Keys by Database",
          "type": "timeseries",
          "targets": [{ "expr": "redis_db_keys{namespace=\"valkey\"}", "legendFormat": "{{ db }}" }]
        }
      ],
      "schemaVersion": 39,
      "tags": ["valkey", "redis", "cache"],
      "templating": { "list": [] },
      "time": { "from": "now-1h", "to": "now" },
      "title": "Valkey",
      "uid": "valkey-overview"
    }
DASHBOARD_EOF
        # Restart Grafana to pick up the dashboard
        kubectl -n monitoring rollout restart deployment/kube-prometheus-stack-grafana
        kubectl -n monitoring rollout status --watch --timeout=5m deployment/kube-prometheus-stack-grafana
    fi

    echo
    echo "Valkey deployed to namespace 'valkey'."
    echo "Internal endpoint: valkey-primary.valkey.svc.cluster.local:6379"
    echo "Password: valkey"
    echo
    echo "To connect with valkey-cli:"
    echo "  kubectl -n valkey exec -it statefulset/valkey-primary -- valkey-cli -a valkey"
    echo
    echo "Test commands:"
    echo "  SET hello world"
    echo "  GET hello"
    echo "  INFO server"
fi

if [[ $VALKEY_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy Valkey example app (write/read key-value pairs)..."
    kubectl create namespace valkey-example --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n valkey-example apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: valkey-demo-script
  namespace: valkey-example
data:
  demo.sh: |
    #!/bin/sh
    set -e
    VALKEY_HOST="\${VALKEY_HOST:-valkey-primary.valkey.svc.cluster.local}"
    VALKEY_PORT="\${VALKEY_PORT:-6379}"

    echo "Valkey demo app starting..."
    echo "Connecting to \${VALKEY_HOST}:\${VALKEY_PORT}"

    while true; do
      TIMESTAMP="\$(date -Iseconds)"
      KEY="demo:\$(hostname)"

      # Write a key-value pair
      valkey-cli -h "\$VALKEY_HOST" -p "\$VALKEY_PORT" -a "\$VALKEY_PASSWORD" --no-auth-warning \
        SET "\$KEY" "\$TIMESTAMP" EX 300 > /dev/null

      # Read it back
      VALUE="\$(valkey-cli -h "\$VALKEY_HOST" -p "\$VALKEY_PORT" -a "\$VALKEY_PASSWORD" --no-auth-warning \
        GET "\$KEY")"

      echo "[\$TIMESTAMP] SET \$KEY = \$TIMESTAMP | GET \$KEY = \$VALUE"

      # Increment a shared counter
      COUNT="\$(valkey-cli -h "\$VALKEY_HOST" -p "\$VALKEY_PORT" -a "\$VALKEY_PASSWORD" --no-auth-warning \
        INCR demo:total-requests)"
      echo "[\$TIMESTAMP] Total requests across all pods: \$COUNT"

      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: valkey-demo
  namespace: valkey-example
  labels:
    app: valkey-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: valkey-demo
  template:
    metadata:
      labels:
        app: valkey-demo
    spec:
      containers:
      - name: valkey-demo
        image: bitnami/valkey:${BITNAMI_VALKEY_VERSION}
        command: ["/bin/sh", "/scripts/demo.sh"]
        env:
        - name: VALKEY_HOST
          value: "valkey-primary.valkey.svc.cluster.local"
        - name: VALKEY_PORT
          value: "6379"
        - name: VALKEY_PASSWORD
          valueFrom:
            secretKeyRef:
              name: valkey-credentials
              key: password
        volumeMounts:
        - name: demo-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 32Mi
            cpu: 10m
          limits:
            memory: 64Mi
      volumes:
      - name: demo-script
        configMap:
          name: valkey-demo-script
          defaultMode: 0755
---
apiVersion: v1
kind: Secret
metadata:
  name: valkey-credentials
  namespace: valkey-example
type: Opaque
stringData:
  password: "valkey"
EOF

    kubectl -n valkey-example rollout status --watch --timeout=5m deployment/valkey-demo
    echo
    echo "Valkey example deployed to namespace 'valkey-example'."
    echo "Two pods write timestamps and increment a shared counter every 10 seconds."
    echo
    echo "Watch the logs:"
    echo "  kubectl -n valkey-example logs -f -l app=valkey-demo"
    echo
    echo "Verify the shared counter:"
    echo "  kubectl -n valkey exec -it statefulset/valkey-primary -- valkey-cli -a valkey --no-auth-warning GET demo:total-requests"
fi

if [[ $MONGODB == true ]]; then
    echo "----------"
    echo "Install MongoDB (v${MONGODB_HELM_CHART_VERSION})..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update bitnami
    kubectl create namespace mongodb --dry-run=client -o yaml | kubectl apply -f -

    helm upgrade --install mongodb bitnami/mongodb \
        --namespace mongodb \
        --version "${MONGODB_HELM_CHART_VERSION}" \
        --values - <<EOF
architecture: standalone
auth:
  enabled: true
  rootUser: root
  rootPassword: "mongodb"
  databases:
    - app
  usernames:
    - app
  passwords:
    - app
persistence:
  enabled: true
  size: 5Gi
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
arbiter:
  enabled: false
mcp:
  enabled: false
metrics:
  enabled: true
  resources:
    requests:
      memory: 32Mi
      cpu: 50m
    limits:
      memory: 64Mi
  serviceMonitor:
    enabled: true
    namespace: monitoring
    additionalLabels:
      release: kube-prometheus-stack
  prometheusRule:
    enabled: true
    namespace: monitoring
    additionalLabels:
      release: kube-prometheus-stack
    rules:
      - alert: MongoDBDown
        expr: mongodb_up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "MongoDB instance is down"
          description: 'MongoDB instance {{ "{{" }} \$labels.instance {{ "}}" }} is down.'
      - alert: MongoDBHighMemoryUsage
        expr: mongodb_memory_resident_megabytes / 512 * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MongoDB high memory usage"
          description: 'MongoDB instance {{ "{{" }} \$labels.instance {{ "}}" }} memory usage is above 80%.'
EOF

    kubectl -n mongodb rollout status --watch --timeout=10m deployment/mongodb

    # Add Grafana dashboard for MongoDB metrics
    if kubectl get deployment -n monitoring kube-prometheus-stack-grafana &>/dev/null; then
        echo "Adding MongoDB Grafana dashboard..."
        kubectl -n monitoring apply -f - <<'DASHBOARD_EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-mongodb
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  mongodb-dashboard.json: |
    {
      "annotations": { "list": [] },
      "description": "MongoDB dashboard for Prometheus mongodb_exporter metrics",
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 1,
      "links": [],
      "panels": [
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": {
            "defaults": { "color": { "mode": "thresholds" }, "thresholds": { "steps": [{ "color": "green", "value": null }, { "color": "red", "value": 0.5 }] }, "mappings": [{ "options": { "0": { "text": "DOWN" }, "1": { "text": "UP" } }, "type": "value" }] },
            "overrides": []
          },
          "gridPos": { "h": 4, "w": 4, "x": 0, "y": 0 },
          "id": 1,
          "options": { "colorMode": "background", "graphMode": "none", "justifyMode": "auto", "textMode": "auto", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Status",
          "type": "stat",
          "targets": [{ "expr": "mongodb_up{namespace=\"mongodb\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "s" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 4, "y": 0 },
          "id": 2,
          "options": { "colorMode": "value", "graphMode": "none", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Uptime",
          "type": "stat",
          "targets": [{ "expr": "mongodb_instance_uptime_seconds{namespace=\"mongodb\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 8, "y": 0 },
          "id": 3,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Current Connections",
          "type": "stat",
          "targets": [{ "expr": "mongodb_connections{state=\"current\",namespace=\"mongodb\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "decmbytes" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 12, "y": 0 },
          "id": 4,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Resident Memory",
          "type": "stat",
          "targets": [{ "expr": "mongodb_memory{type=\"resident\",namespace=\"mongodb\"}", "legendFormat": "{{ instance }}" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 16, "y": 0 },
          "id": 5,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Total Collections",
          "type": "stat",
          "targets": [{ "expr": "mongodb_ss_catalogStats_collections{namespace=\"mongodb\"}", "legendFormat": "collections" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "unit": "ops" }, "overrides": [] },
          "gridPos": { "h": 4, "w": 4, "x": 20, "y": 0 },
          "id": 6,
          "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"] } },
          "title": "Operations/sec",
          "type": "stat",
          "targets": [{ "expr": "sum(rate(mongodb_op_counters_total{namespace=\"mongodb\"}[5m]))", "legendFormat": "ops/s" }]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "decmbytes" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 },
          "id": 7,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Memory Usage",
          "type": "timeseries",
          "targets": [
            { "expr": "mongodb_memory{type=\"resident\",namespace=\"mongodb\"}", "legendFormat": "resident" },
            { "expr": "mongodb_memory{type=\"virtual\",namespace=\"mongodb\"}", "legendFormat": "virtual" },
            { "expr": "mongodb_memory{type=\"mapped\",namespace=\"mongodb\"}", "legendFormat": "mapped" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 4 },
          "id": 8,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Connections",
          "type": "timeseries",
          "targets": [
            { "expr": "mongodb_connections{state=\"current\",namespace=\"mongodb\"}", "legendFormat": "current" },
            { "expr": "mongodb_connections{state=\"available\",namespace=\"mongodb\"}", "legendFormat": "available" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "ops" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 12 },
          "id": 9,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Operations per Second",
          "type": "timeseries",
          "targets": [
            { "expr": "rate(mongodb_op_counters_total{type=\"insert\",namespace=\"mongodb\"}[5m])", "legendFormat": "insert" },
            { "expr": "rate(mongodb_op_counters_total{type=\"query\",namespace=\"mongodb\"}[5m])", "legendFormat": "query" },
            { "expr": "rate(mongodb_op_counters_total{type=\"update\",namespace=\"mongodb\"}[5m])", "legendFormat": "update" },
            { "expr": "rate(mongodb_op_counters_total{type=\"delete\",namespace=\"mongodb\"}[5m])", "legendFormat": "delete" },
            { "expr": "rate(mongodb_op_counters_total{type=\"command\",namespace=\"mongodb\"}[5m])", "legendFormat": "command" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "bytes" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 12 },
          "id": 10,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Network I/O",
          "type": "timeseries",
          "targets": [
            { "expr": "rate(mongodb_ss_network_bytesIn{namespace=\"mongodb\"}[5m])", "legendFormat": "input" },
            { "expr": "rate(mongodb_ss_network_bytesOut{namespace=\"mongodb\"}[5m])", "legendFormat": "output" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 0, "y": 20 },
          "id": 11,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Document Operations per Second",
          "type": "timeseries",
          "targets": [
            { "expr": "rate(mongodb_mongod_metrics_document_total{state=\"inserted\",namespace=\"mongodb\"}[5m])", "legendFormat": "inserted" },
            { "expr": "rate(mongodb_mongod_metrics_document_total{state=\"returned\",namespace=\"mongodb\"}[5m])", "legendFormat": "returned" },
            { "expr": "rate(mongodb_mongod_metrics_document_total{state=\"updated\",namespace=\"mongodb\"}[5m])", "legendFormat": "updated" },
            { "expr": "rate(mongodb_mongod_metrics_document_total{state=\"deleted\",namespace=\"mongodb\"}[5m])", "legendFormat": "deleted" }
          ]
        },
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "fieldConfig": { "defaults": { "custom": { "drawStyle": "line", "fillOpacity": 10, "spanNulls": false }, "unit": "short" }, "overrides": [] },
          "gridPos": { "h": 8, "w": 12, "x": 12, "y": 20 },
          "id": 12,
          "options": { "legend": { "displayMode": "list", "placement": "bottom" }, "tooltip": { "mode": "multi" } },
          "title": "Page Faults",
          "type": "timeseries",
          "targets": [{ "expr": "rate(mongodb_extra_info_page_faults_total{namespace=\"mongodb\"}[5m])", "legendFormat": "page faults/s" }]
        }
      ],
      "schemaVersion": 39,
      "tags": ["mongodb", "nosql", "database"],
      "templating": { "list": [] },
      "time": { "from": "now-1h", "to": "now" },
      "title": "MongoDB",
      "uid": "mongodb-overview"
    }
DASHBOARD_EOF
        # Restart Grafana to pick up the dashboard
        kubectl -n monitoring rollout restart deployment/kube-prometheus-stack-grafana
        kubectl -n monitoring rollout status --watch --timeout=5m deployment/kube-prometheus-stack-grafana
    fi

    echo
    echo "MongoDB deployed to namespace 'mongodb'."
    echo "Internal endpoint: mongodb.mongodb.svc.cluster.local:27017"
    echo "Root password: mongodb"
    echo "App database: app (user: app, password: app)"
    echo
    echo "To connect with mongosh:"
    echo "  kubectl -n mongodb exec -it deployment/mongodb -- mongosh -u app -p app --authenticationDatabase app app"
    echo
    echo "Test commands:"
    echo "  db.test.insertOne({ hello: 'world', timestamp: new Date() })"
    echo "  db.test.find()"
    echo "  db.stats()"
fi

if [[ $MONGODB_EXAMPLE == true ]]; then
    echo "----------"
    echo "Deploy MongoDB example app (insert/query documents)..."
    kubectl create namespace mongodb-example --dry-run=client -o yaml | kubectl apply -f -

    kubectl -n mongodb-example apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-credentials
  namespace: mongodb-example
type: Opaque
stringData:
  password: "app"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-demo-script
  namespace: mongodb-example
data:
  demo.sh: |
    #!/bin/bash
    set -e

    MONGO_HOST="\${MONGO_HOST:-mongodb.mongodb.svc.cluster.local}"
    MONGO_PORT="\${MONGO_PORT:-27017}"
    MONGO_DB="\${MONGO_DB:-app}"
    MONGO_USER="\${MONGO_USER:-app}"
    POD_NAME="\${HOSTNAME}"
    MONGO_URI="mongodb://\${MONGO_USER}:\${MONGO_PASSWORD}@\${MONGO_HOST}:\${MONGO_PORT}/\${MONGO_DB}?authSource=\${MONGO_DB}"

    echo "MongoDB demo app starting..."
    echo "Connecting to \${MONGO_HOST}:\${MONGO_PORT}/\${MONGO_DB} as \${MONGO_USER}"

    # Wait for MongoDB to be ready
    until mongosh "\${MONGO_URI}" --quiet --eval "db.runCommand({ ping: 1 })" &>/dev/null; do
      echo "Waiting for MongoDB to be ready..."
      sleep 3
    done
    echo "MongoDB is ready."

    # Ensure index on created_at for efficient queries
    mongosh "\${MONGO_URI}" --quiet --eval '
      db.demo_events.createIndex({ created_at: 1 });
    '
    echo "Index on 'created_at' ready."

    COUNTER=0
    while true; do
      COUNTER=\$((COUNTER + 1))
      TIMESTAMP="\$(date -Iseconds)"

      # Insert a document and get counts in one mongosh call
      RESULT=\$(mongosh "\${MONGO_URI}" --quiet --eval "
        const doc = {
          pod_name: '\${POD_NAME}',
          message: 'ping at \${TIMESTAMP}',
          counter: \${COUNTER},
          created_at: new Date()
        };
        const r = db.demo_events.insertOne(doc);
        const total = db.demo_events.countDocuments();
        const pods = db.demo_events.distinct('pod_name').length;
        print('id=' + r.insertedId + ' total=' + total + ' pods=' + pods);
      ")

      echo "[\${TIMESTAMP}] Inserted doc #\${COUNTER} from \${POD_NAME} | \${RESULT}"

      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-demo
  namespace: mongodb-example
  labels:
    app: mongodb-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mongodb-demo
  template:
    metadata:
      labels:
        app: mongodb-demo
    spec:
      containers:
      - name: mongodb-demo
        image: bitnami/mongodb:${BITNAMI_MONGODB_VERSION}
        command: ["/bin/bash", "/scripts/demo.sh"]
        env:
        - name: MONGO_HOST
          value: "mongodb.mongodb.svc.cluster.local"
        - name: MONGO_PORT
          value: "27017"
        - name: MONGO_DB
          value: "app"
        - name: MONGO_USER
          value: "app"
        - name: MONGO_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-credentials
              key: password
        volumeMounts:
        - name: demo-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            memory: 128Mi
            cpu: 10m
          limits:
            memory: 512Mi
      volumes:
      - name: demo-script
        configMap:
          name: mongodb-demo-script
          defaultMode: 0755
EOF

    kubectl -n mongodb-example rollout status --watch --timeout=5m deployment/mongodb-demo
    echo
    echo "MongoDB example deployed to namespace 'mongodb-example'."
    echo "Two pods insert documents into the 'demo_events' collection every 10 seconds."
    echo
    echo "Watch the logs:"
    echo "  kubectl -n mongodb-example logs -f -l app=mongodb-demo"
    echo
    echo "Query the shared collection:"
    echo "  kubectl -n mongodb exec -it deployment/mongodb -- mongosh -u app -p app --authenticationDatabase app app --eval 'db.demo_events.find().sort({created_at:-1}).limit(10).pretty()'"
fi

if [[ $ZABBIX == true ]]; then
    echo "----------"
    echo "Install Zabbix (v${ZABBIX_HELM_CHART_VERSION})..."
    helm repo add zabbix-community https://zabbix-community.github.io/helm-zabbix
    helm repo update zabbix-community
    kubectl create namespace zabbix --dry-run=client -o yaml | kubectl apply -f -

    helm upgrade --install zabbix zabbix-community/zabbix \
        --dependency-update \
        --namespace zabbix \
        --version "${ZABBIX_HELM_CHART_VERSION}" \
        --values - <<EOF
# Zabbix image tag (LTS)
zabbixImageTag: ubuntu-7.0.16

# --- PostgreSQL (built-in, for dev/test) ---
postgresql:
  enabled: true
  image:
    repository: postgres
    tag: 16
  persistence:
    enabled: true
    storageSize: 5Gi
  extraRuntimeParameters:
    max_connections: 100

postgresAccess:
  host: zabbix-postgresql
  port: "5432"
  database: zabbix
  user: zabbix
  password: zabbix

# --- Zabbix Server ---
zabbixServer:
  enabled: true
  replicaCount: 1
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi

# --- Zabbix Web (frontend) ---
zabbixWeb:
  enabled: true
  replicaCount: 1
  resources:
    requests:
      memory: 128Mi
      cpu: 50m
    limits:
      memory: 512Mi

# --- Zabbix Agent2 (sidecar mode, default) ---
zabbixAgent:
  enabled: true
  runAsSidecar: true
  runAsDaemonSet: false

# --- Zabbix Web Service ---
zabbixWebService:
  enabled: true
  replicaCount: 1

# --- Ingress for Zabbix Web UI ---
ingress:
  enabled: true
  annotations: {}
  hosts:
    - host: zabbix.k8s.local
      paths:
        - path: /
          pathType: Prefix
  pathType: Prefix
EOF

    echo "Waiting for Zabbix PostgreSQL to be ready..."
    kubectl -n zabbix rollout status --watch --timeout=10m statefulset/zabbix-postgresql

    echo "Waiting for Zabbix Server to be ready..."
    kubectl -n zabbix rollout status --watch --timeout=10m deployment/zabbix-zabbix-server

    echo "Waiting for Zabbix Web to be ready..."
    kubectl -n zabbix rollout status --watch --timeout=10m deployment/zabbix-zabbix-web

    # Patch the Ingress to use Cilium ingress class
    kubectl -n zabbix patch ingress zabbix --type='json' -p='[{"op":"add","path":"/spec/ingressClassName","value":"cilium"}]' 2>/dev/null || true

    echo
    echo "Zabbix deployed to namespace 'zabbix'."
    echo "Web UI available at: http://zabbix.k8s.local"
    echo "  Username: Admin"
    echo "  Password: zabbix"
    echo
    echo "Internal endpoints:"
    echo "  Zabbix Server: zabbix-zabbix-server.zabbix.svc.cluster.local:10051"
    echo "  Zabbix Web:    zabbix-zabbix-web.zabbix.svc.cluster.local:80"
    echo "  PostgreSQL:    zabbix-postgresql.zabbix.svc.cluster.local:5432"
fi
