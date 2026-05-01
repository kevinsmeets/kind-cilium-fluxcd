# kind-cilium-fluxcd

A self-contained project to create a local Kubernetes cluster using [KinD](https://kind.sigs.k8s.io/) with [Cilium](https://cilium.io/) as the CNI and [FluxCD](https://fluxcd.io/) for GitOps.

All Docker images can optionally be rebuilt with an **extra CA certificate** injected (e.g. a corporate MITM proxy CA such as Zscaler, Netskope, etc.), so the cluster can operate behind such a proxy. This is opt-in via the `EXTRA_CA_CERT` environment variable; if unset, images are built without any custom CA.

## Project Structure

```text
kind-cilium-fluxcd/
├── pipeline.sh                         # Main pipeline script (orchestrates everything)
├── versions.env                        # Central version configuration
├── scripts/
│   ├── create-cluster.sh               # Create KinD cluster with local Docker registry
│   ├── build-images.sh                 # Build Docker images (optional extra CA cert)
│   ├── delete-cluster.sh               # Delete KinD cluster and clean up
│   └── fix-too-many-open-files.sh      # Fix system limits for KinD
├── dockerfiles/
│   ├── kind-node/                      # KinD node image (optional extra CA)
│   ├── helm-controller/                # FluxCD helm-controller (optional extra CA)
│   ├── kustomize-controller/           # FluxCD kustomize-controller (optional extra CA)
│   ├── notification-controller/        # FluxCD notification-controller (optional extra CA)
│   ├── source-controller/              # FluxCD source-controller (optional extra CA)
│   ├── podinfo/                        # Podinfo (optional extra CA)
│   └── docker-registry-proxy/          # Docker registry proxy (optional extra CA)
└── README.md
```

## Prerequisites

- Docker
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/)
- [flux](https://fluxcd.io/flux/cmd/)
- [cilium-cli](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli)
- *(Optional, only if behind a TLS-intercepting corporate proxy)* a PEM-encoded
  CA certificate. Set `EXTRA_CA_CERT` to its path, e.g.:

  ```bash
  export EXTRA_CA_CERT=/usr/local/share/ca-certificates/ZscalerRootCertificate-2048-SHA256.crt
  ```

## Quick Start

### Option 1: Full pipeline (everything at once)

```bash
# Build images, create cluster, install Cilium, FluxCD, and podinfo
./pipeline.sh -a -b -i
```

### Option 2: Step by step

```bash
# 1. Build all Docker images (KinD node + FluxCD controllers + podinfo + proxy)
./scripts/build-images.sh

# 2. Create cluster (starts local registry, registry proxy, and KinD cluster)
./scripts/create-cluster.sh

# 3. Run the pipeline on the existing cluster
./pipeline.sh -c -a -i
```

### Option 3: Selective installation

```bash
# Build only the KinD node image
./scripts/build-images.sh --node

# Create cluster with Cilium only (no FluxCD)
./pipeline.sh -b -i

# Add FluxCD later on existing cluster
./pipeline.sh -c -f

# Add podinfo on existing cluster
./pipeline.sh -c -p
```

## Pipeline Options

```text
Usage: ./pipeline.sh [options]
Options:
 -h, --help              Show this help message
 -c, --existing-cluster  Use existing cluster (do not create new)
 -n, --no-cilium         Do not install Cilium CNI (assumes cluster already has a CNI installed)
 -b, --build-images      Build Docker images (optionally with extra CA cert via EXTRA_CA_CERT)
 -m, --metrics-server    Deploy kubernetes metrics server
 -i, --pull-images       Pull Cilium images and push to local container registry
 -f, --flux              Install FluxCD
 -p, --podinfo           Install podinfo example with FluxCD
 -d, --dashboard         Install headlamp kubernetes dashboard
 -r, --reloader          Install reloader
 -e, --reloader-example  Deploy an example app demonstrating Reloader (ConfigMap + Deployment)
 -k, --kube-prometheus   Install kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
 -l, --loki              Install Grafana Loki + Alloy (log aggregation)
 -s, --seaweedfs         Install SeaweedFS (S3-compatible object storage)
 -w, --seaweedfs-example Deploy an example app demonstrating SeaweedFS (upload/download S3 objects)
 -o, --openbao           Install OpenBao (secret management / key vault)
 -t, --openbao-example   Deploy an example app demonstrating OpenBao (read secrets from vault)
 -g, --cnpg              Install CloudNativePG (PostgreSQL database operator)
 -y, --cnpg-example      Deploy an example app demonstrating CloudNativePG (PostgreSQL read/write)
 -v, --valkey            Install Valkey (key-value cache, open-source Redis replacement)
 -x, --valkey-example    Deploy an example app demonstrating Valkey (write/read key-value pairs)
 -j, --mongodb           Install MongoDB (NoSQL document database)
 -q, --mongodb-example   Deploy an example app demonstrating MongoDB (insert/query documents)
 -z, --zabbix            Install Zabbix (monitoring and alerting platform)
 -a, --all               Install everything
```

## Build Images Script

```text
Usage: ./scripts/build-images.sh [options]
Options:
 -h, --help       Show help message
 -n, --node       Build KinD node image only
 -f, --flux       Build FluxCD controller images only
 -p, --podinfo    Build podinfo image only
 -x, --proxy      Build Docker registry proxy image only
 -a, --all        Build all images (default)
```

## Version Management

All component versions are defined centrally in [versions.env](versions.env). Update versions there and they propagate to all scripts.

> **Note:** Dockerfile `FROM` lines contain pinned versions. When upgrading, update both `versions.env` and the corresponding Dockerfile.

## Docker Hub Authentication (Optional)

To avoid Docker Hub rate limits, set these environment variables before running the pipeline:

```bash
export DOCKER_HUB_USERNAME="your-username"
export DOCKER_HUB_PASSWORD="your-token"
```

## Cluster Teardown

```bash
# Delete cluster, registry, and proxy
./scripts/delete-cluster.sh

# Delete cluster only (keep registry and proxy running)
CLEANUP_REGISTRY=false CLEANUP_PROXY=false ./scripts/delete-cluster.sh
```

## Troubleshooting

### Too many open files

If you encounter "too many open files" errors with KinD:

```bash
./scripts/fix-too-many-open-files.sh
```

Then open a new terminal session.

## Host DNS Configuration

KinD clusters run inside Docker and are not accessible via public DNS. Services exposed through Cilium Ingress get a LoadBalancer IP from the Docker `kind` network (the `172.18.250.0/24` CIDR pool configured by `CiliumLoadBalancerIPPool`). To access these services by hostname from your host machine, you need to add entries to `/etc/hosts` that map each ingress hostname to its assigned LoadBalancer IP.

Without these entries, your browser and CLI tools (e.g. `curl`, `aws`, `bao`) cannot resolve `*.k8s.local` hostnames, and ingress-based access will not work.

Add the following to `/etc/hosts` (adjust IPs if your Docker network differs):

```text
172.18.250.0	hubble-ui.k8s.local
172.18.250.2	podinfo.k8s.local
172.18.250.3	headlamp.k8s.local
172.18.250.4	alertmanager.k8s.local
172.18.250.5	grafana.k8s.local
172.18.250.6	s3.k8s.local
172.18.250.7	openbao.k8s.local
```

To find the actual IPs assigned to each ingress, run:

```bash
kubectl get ingress -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOST:.spec.rules[0].host,ADDRESS:.status.loadBalancer.ingress[0].ip'
```

> **Note:** The IPs are allocated from the `CiliumLoadBalancerIPPool` CIDR (`x.y.250.0/24` derived from the Docker `kind` network subnet). They are stable across pod restarts but may change if you recreate the cluster or delete and re-create ingress resources, so verify with the command above after cluster creation.

## What Gets Deployed

| Component | Description |
|-----------|-------------|
| **KinD Cluster** | 1 control-plane + 3 worker nodes, CNI disabled for Cilium |
| **Local Docker Registry** | `localhost:5001` for hosting container images |
| **Docker Registry Proxy** | Caching proxy for upstream registries |
| **Cilium CNI** | Network plugin with Gateway API, Ingress, L2 announcements, Hubble UI, Prometheus metrics, ServiceMonitors, and Grafana dashboards |
| **FluxCD** | GitOps toolkit (helm, kustomize, notification, source controllers) |
| **Podinfo** | Sample application deployed via FluxCD |
| **Headlamp** | Kubernetes dashboard (optional, `-d` flag) |
| **Reloader** | Watches ConfigMap/Secret changes (optional, `-r` flag) |
| **Reloader Example** | Demo app: Deployment with ConfigMap/Secret that auto-restarts on changes (optional, `-e` flag) |
| **kube-prometheus-stack** | Prometheus, Grafana, and Alertmanager (optional, `-k` flag) |
| **Grafana Loki + Alloy** | Log aggregation with Loki, collection with Alloy (optional, `-l` flag) |
| **SeaweedFS** | S3-compatible object storage, accessible at `s3.k8s.local` (optional, `-s` flag) |
| **SeaweedFS Example** | Demo app: 2 pods upload/download JSON objects via S3 API every 10s (optional, `-w` flag) |
| **OpenBao** | Secret management / key vault (Vault fork), UI at `openbao.k8s.local` (optional, `-o` flag) |
| **OpenBao Example** | Demo app: 2 pods authenticate via Kubernetes auth and read secrets every 30s (optional, `-t` flag) |
| **CloudNativePG** | PostgreSQL database operator with a single-instance cluster, PodMonitor, extended metrics, and Grafana dashboard (optional, `-g` flag) |
| **CloudNativePG Example** | Demo app: 2 pods insert rows into a shared PostgreSQL table every 10s (optional, `-y` flag) |
| **Valkey** | Key-value cache (open-source Redis replacement), with Prometheus metrics, ServiceMonitor, alerts, and Grafana dashboard (optional, `-v` flag) |
| **Valkey Example** | Demo app: 2 pods write timestamps and increment a shared counter every 10s (optional, `-x` flag) |
| **MongoDB** | NoSQL document database, with Prometheus metrics, ServiceMonitor, alerts, and Grafana dashboard (optional, `-j` flag) |
| **MongoDB Example** | Demo app: 2 pods insert documents into a shared collection every 10s (optional, `-q` flag) |
| **Metrics Server** | Kubernetes metrics (optional, `-m` flag) |

## Cilium Metrics & Grafana Dashboards

When kube-prometheus-stack is installed (`-k` flag), Cilium is automatically configured with:

- **Prometheus metrics** for the Cilium agent, operator, envoy, and Hubble
- **ServiceMonitors** for all Cilium components (auto-discovered by Prometheus)
- **Grafana dashboards** for the Cilium agent, operator, and Hubble (auto-loaded via sidecar)
- **Hubble metrics**: DNS, drop, TCP, flow, port-distribution, ICMP, and HTTP (with exemplars and label context)

Prometheus Operator CRDs (ServiceMonitor, PodMonitor, PrometheusRule) are pre-installed before Cilium to satisfy Helm template validation, with the CRD version automatically derived from the kube-prometheus-stack chart's appVersion.

## OpenBao (Secret Management)

[OpenBao](https://openbao.org/) is an open source (MPL 2.0) community fork of HashiCorp Vault, maintained under the Linux Foundation. It provides secret management, encryption as a service, PKI/certificates, and dynamic secrets.

When installed (`-o` flag), OpenBao is deployed in **standalone mode with persistent file storage**, so secrets, tokens, auth methods and policies survive pod restarts and helm upgrades:

- **UI**: <http://openbao.k8s.local>
- **Storage**: `file` backend on a 2 Gi PVC mounted at `/openbao/data` in the `openbao-0` pod
- **Initialization**: on first install the script runs `bao operator init` with 1 key share / threshold 1 and stores the unseal key + root token in the Kubernetes Secret `openbao-keys` in the `openbao` namespace
- **Auto-unsealer**: a small `openbao-unsealer` Deployment (busybox + `wget`) polls `openbao-0` directly via the headless `openbao-internal` service and unseals it automatically whenever it comes up sealed (e.g. after a pod restart)
- **Prometheus ServiceMonitor**: auto-discovered by kube-prometheus-stack
- **Grafana dashboard**: auto-loaded via sidecar (with patched datasource)

> **Note:** The unseal key and root token in `openbao-keys` are stored in plain Kubernetes Secrets (base64-encoded, not encrypted). This setup is intended for local development on an ephemeral KinD cluster — for production you would use auto-unseal with a KMS (AWS KMS, GCP KMS, Transit, etc.) and never persist these values in-cluster.

Retrieve the root token and unseal key from the Kubernetes Secret:

```bash
# Root token (used to administer OpenBao)
kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d; echo

# Unseal key (the auto-unsealer uses this; you normally never need it manually)
kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.unseal-key}'  | base64 -d; echo
```

Interact with OpenBao by exec-ing into the `openbao-0` pod (which has the `bao` CLI). Pass the root token via `BAO_TOKEN`:

```bash
# Capture the root token once
ROOT=$(kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d)

# Enable a KV secrets engine
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao secrets enable -path=secret kv-v2

# Write a secret
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao kv put secret/my-app username=admin password=s3cr3t

# Read a secret
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao kv get secret/my-app

# Check seal/init status (no token required)
kubectl -n openbao exec -it openbao-0 -- bao status
```

To verify persistence, write a secret, delete the `openbao-0` pod, wait a few seconds for the auto-unsealer to do its work, then read it back — the data is still there:

```bash
ROOT=$(kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d)
kubectl -n openbao exec openbao-0 -- env BAO_TOKEN="$ROOT" bao kv put secret/persist-test note="hello"
kubectl -n openbao delete pod openbao-0
kubectl -n openbao wait --for=condition=Ready pod/openbao-0 --timeout=2m
kubectl -n openbao exec openbao-0 -- env BAO_TOKEN="$ROOT" bao kv get secret/persist-test

# Watch the unsealer in action
kubectl -n openbao logs -f deployment/openbao-unsealer
```

### OpenBao Example App

When the example is enabled (`-t` flag), a demo application is deployed that demonstrates **Kubernetes auth** with OpenBao — the recommended way to authenticate pods without hardcoding tokens.

The example sets up:

1. **KV v2 secrets engine** at `secret/` with demo credentials (username, password, API key, database URL)
2. **Kubernetes auth method** — pods authenticate using their service account JWT token
3. **Policy** (`demo-app`) — grants read-only access to `secret/demo-app`
4. **Auth role** (`demo-app`) — binds the `openbao-demo-app` service account in namespace `openbao-example` to the policy
5. **Deployment** (2 replicas) — each pod authenticates with OpenBao every 30 seconds and reads the secrets

```bash
# Watch the demo pods authenticate and read secrets
kubectl -n openbao-example logs -f -l app=openbao-demo

# Example output:
# [2026-03-31T16:30:00+00:00] --- Authenticating with OpenBao via Kubernetes auth ---
# [2026-03-31T16:30:00+00:00] Authenticated successfully (token: hvs.CAESIG0p...)
# [2026-03-31T16:30:00+00:00] Secrets retrieved from OpenBao:
#   username:     demo-user
#   password:     P@ss********
#   api-key:      bao-dk-12********
#   database-url: postgresql://demo:sec...

# Capture the root token from the openbao-keys Secret
ROOT=$(kubectl -n openbao get secret openbao-keys -o jsonpath='{.data.root-token}' | base64 -d)

# Verify the secrets stored in OpenBao
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao kv get secret/demo-app

# List the Kubernetes auth roles
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao list auth/kubernetes/role

# Read the demo-app role configuration
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao read auth/kubernetes/role/demo-app

# Read the demo-app policy
kubectl -n openbao exec -it openbao-0 -- env BAO_TOKEN="$ROOT" bao policy read demo-app
```

This demonstrates the full flow: **ServiceAccount → Kubernetes Auth → Vault Token → Read Secrets** — no hardcoded credentials in the pod spec.

## CloudNativePG (PostgreSQL Database)

[CloudNativePG](https://cloudnative-pg.io/) is a Kubernetes operator for managing PostgreSQL clusters natively in Kubernetes. It covers the full lifecycle of a PostgreSQL cluster: automated failover, rolling updates, backup/recovery, and monitoring.

When installed (`-g` flag), the operator and a single-instance PostgreSQL cluster are deployed with:

- **Namespace**: operator in `cnpg-system`, database cluster in `postgres`
- **Database**: `app` (owner: `app`)
- **Storage**: 5Gi persistent volume
- **PodMonitor**: auto-discovered by kube-prometheus-stack
- **Extended metrics**: backends, WAL archiving, replication, database stats (via `cnpg-default-monitoring` ConfigMap)
- **Grafana dashboard**: "CloudNativePG" with panels for server health, replication, connections, TPS, CPU/memory, transactions, deadlocks, WAL archiving, storage usage, session states, I/O, and operator reconcile errors

Connect with psql:

```bash
kubectl -n postgres exec -it postgres-1 -- psql -h localhost -U app -d app
```

Get the `app` user password:

```bash
kubectl -n postgres get secret postgres-app -o jsonpath='{.data.password}' | base64 -d
```

Get the superuser password:

```bash
kubectl -n postgres get secret postgres-superuser -o jsonpath='{.data.password}' | base64 -d
```

Internal endpoint for other services in the cluster:

```text
postgres-rw.postgres.svc.cluster.local:5432
```

### CloudNativePG Example App

When the example is deployed (`-y` flag), two pods run a loop that inserts rows into a shared `demo_events` table every 10 seconds, demonstrating cross-pod database writes:

```bash
# Watch the demo logs
kubectl -n cnpg-example logs -f -l app=cnpg-demo

# Query the shared table
kubectl -n postgres exec -it postgres-1 -- psql -h localhost -U app -d app -c 'SELECT * FROM demo_events ORDER BY id DESC LIMIT 10;'
```

## Valkey (Key-Value Cache)

[Valkey](https://valkey.io/) is an open source (BSD-3-Clause) high-performance key-value store, forked from Redis 7.2 under the Linux Foundation. It is a drop-in Redis replacement, fully wire-protocol compatible with all existing Redis clients.

When installed (`-v` flag), Valkey is deployed in **standalone mode** with:

- **Persistence**: 1Gi PVC for data durability
- **Authentication**: password-protected (password: `valkey`)
- **Prometheus metrics**: redis-exporter sidecar, auto-discovered by kube-prometheus-stack
- **ServiceMonitor**: created in the monitoring namespace
- **PrometheusRules**: `ValkeyDown` and `ValkeyHighMemoryUsage` alerts
- **Grafana dashboard**: auto-loaded with panels for status, memory, clients, commands/sec, cache hits/misses, network I/O, and keys

Connect with valkey-cli:

```bash
kubectl -n valkey exec -it statefulset/valkey-primary -- valkey-cli -a valkey
```

Test commands:

```text
SET hello world
GET hello
INFO server
```

Internal endpoint for other services in the cluster:

```text
valkey-primary.valkey.svc.cluster.local:6379
```

### Valkey Example App

When the example is deployed (`-x` flag), two pods run a loop that writes timestamps and increments a shared counter in Valkey every 10 seconds, demonstrating cross-pod shared state:

```bash
# Watch the demo logs
kubectl -n valkey-example logs -f -l app=valkey-demo

# Check the shared counter
kubectl -n valkey exec -it statefulset/valkey-primary -- valkey-cli -a valkey --no-auth-warning GET demo:total-requests
```

## MongoDB (NoSQL Document Database)

[MongoDB](https://www.mongodb.com/) is a general-purpose, document-oriented NoSQL database that stores data in flexible, JSON-like documents. It is widely used for modern applications requiring schema flexibility, horizontal scaling, and rich querying.

When installed (`-j` flag), MongoDB is deployed in **standalone mode** with:

- **Persistence**: 5Gi PVC for data durability
- **Authentication**: root user and a dedicated `app` database with `app` user
- **Prometheus metrics**: mongodb-exporter sidecar, auto-discovered by kube-prometheus-stack
- **ServiceMonitor**: created in the monitoring namespace
- **PrometheusRules**: `MongoDBDown` and `MongoDBHighMemoryUsage` alerts
- **Grafana dashboard**: auto-loaded with panels for status, uptime, connections, memory, operations/sec, network I/O, document operations, and page faults

Connect with mongosh:

```bash
kubectl -n mongodb exec -it deployment/mongodb -- mongosh -u app -p app --authenticationDatabase app app
```

Test commands:

```javascript
db.test.insertOne({ hello: 'world', timestamp: new Date() })
db.test.find()
db.stats()
```

Internal endpoint for other services in the cluster:

```text
mongodb.mongodb.svc.cluster.local:27017
```

Get the `app` user password:

```bash
kubectl -n mongodb get secret mongodb -o jsonpath='{.data.mongodb-passwords}' | base64 -d | awk -F',' '{print $1}'
```

Get the root password:

```bash
kubectl -n mongodb get secret mongodb -o jsonpath='{.data.mongodb-root-password}' | base64 -d
```

### MongoDB Example App

When the example is deployed (`-q` flag), two pods run a loop that inserts documents into a shared `demo_events` collection every 10 seconds, demonstrating cross-pod document writes:

```bash
# Watch the demo logs
kubectl -n mongodb-example logs -f -l app=mongodb-demo

# Query the shared collection
kubectl -n mongodb exec -it deployment/mongodb -- mongosh -u app -p app --authenticationDatabase app app --eval 'db.demo_events.find().sort({created_at:-1}).limit(10).pretty()'
```
