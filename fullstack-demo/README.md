# Fullstack Demo App

A minimal FastAPI app that demonstrates using all major services in the kind-cilium-fluxcd stack:

- **PostgreSQL (CloudNativePG)**: Inserts a row in a table
- **MongoDB**: Inserts a document
- **Valkey**: Sets and gets a key
- **SeaweedFS (S3)**: Uploads and downloads a file
- **OpenBao**: Reads a secret using Kubernetes auth

## Endpoints

- `/` — Health check
- `/demo` — Performs all service actions and returns a summary
- `/demo/download` — Downloads the file from S3

## Deploy

1. Build and push the image to the local registry (optionally with an extra CA cert):

   ```bash
   ./build.sh
   # This script sources versions.env. If EXTRA_CA_CERT is set, it stages
   # the cert into the build context; otherwise it stages an empty placeholder.
   # It then builds the image, pushes it to the local registry, and cleans up.
   # KinD nodes pull from localhost:5001 automatically.
   ```

2. Apply the manifests:

   ```bash
   kubectl apply -f k8s.yaml
   ```

3. Add to `/etc/hosts`:

   ```
   172.18.250.8  fullstack-demo.k8s.local
   ```
   (Use the actual IP assigned by CiliumLoadBalancerIPPool)

4. Test:

   ```bash
   curl http://fullstack-demo.k8s.local/demo
   ```

## Requirements
- All backing services must be running (see main project)
- The S3 bucket (`demo-bucket`) must exist (see SeaweedFS example)
- The OpenBao secret and role must be set up (see OpenBao example)
