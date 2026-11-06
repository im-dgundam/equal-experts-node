# Kubernetes manifests (Minikube)

These manifests are applied by the `deploy-minikube` GitHub Actions workflow
running on the local self-hosted runner.

| File | Purpose |
|---|---|
| `deployment.yaml` | Deploys one replica of `gists-api-server` |
| `service.yaml` | Exposes it as a `NodePort` service |

## Quick manual apply

```bash
# Point kubectl at Minikube
kubectl config use-context minikube

# Load the image into Minikube's Docker daemon
eval $(minikube docker-env)
docker pull ghcr.io/<owner>/<repo>:latest

# Apply manifests
kubectl apply -f k8s/

# Open in browser / get URL
minikube service gists-api-server
```
