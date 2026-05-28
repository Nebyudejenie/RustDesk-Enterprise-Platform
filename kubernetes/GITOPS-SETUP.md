# RustDesk Phase 2 - GitOps Setup with ArgoCD

## Overview

GitOps enables declarative, version-controlled infrastructure deployment through Git. This guide sets up ArgoCD for continuous deployment of RustDesk to Kubernetes.

## Architecture

```
Git Repository
    ↓
    (commit push)
    ↓
ArgoCD Controller (watches repo)
    ↓
    (syncs manifests)
    ↓
Kubernetes Cluster (deploys RustDesk)
```

## Installation

### 1. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD using Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.insecure=true \  # Use HTTPS in production
  --set server.ingress.enabled=true \
  --set server.ingress.hosts={argocd.yourdomain.com}

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
```

### 2. Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login to https://localhost:8080
# Username: admin
# Password: (from above)
```

### 3. Connect Git Repository

```bash
# Add Git repository credentials
argocd repo add https://github.com/yourusername/rustdesk-k8s \
  --username <github-username> \
  --password <github-token> \
  --insecure-skip-verify

# Or use SSH
argocd repo add git@github.com:yourusername/rustdesk-k8s.git \
  --ssh-private-key-path ~/.ssh/id_rsa \
  --insecure-skip-verify

# Verify repository
argocd repo list
```

## GitOps Repository Structure

```
rustdesk-k8s/
├── apps/
│   ├── rustdesk-dev.yaml
│   ├── rustdesk-staging.yaml
│   └── rustdesk-prod.yaml
├── manifests/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── hbbs-deployment.yaml
│   │   ├── hbbr-deployment.yaml
│   │   └── services.yaml
│   ├── overlays/
│   │   ├── dev/
│   │   │   └── kustomization.yaml
│   │   ├── staging/
│   │   │   └── kustomization.yaml
│   │   └── prod/
│   │       └── kustomization.yaml
├── helm/
│   └── values-{dev,staging,prod}.yaml
└── README.md
```

## Create ArgoCD Application

### Option 1: Using Helm (Recommended)

```yaml
# rustdesk-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk
  namespace: argocd
spec:
  # Project
  project: default

  # Source
  source:
    repoURL: https://github.com/yourusername/rustdesk-k8s
    targetRevision: main
    path: helm
    helm:
      releaseName: rustdesk
      values: |
        global:
          environment: production
        hbbs:
          replicaCount: 1
        hbbr:
          replicaCount: 3
          
  # Destination
  destination:
    server: https://kubernetes.default.svc
    namespace: rustdesk-system

  # Sync policy
  syncPolicy:
    automated:
      prune: true      # Auto-delete removed resources
      selfHeal: true   # Auto-sync when cluster diverges
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Option 2: Using Kustomize

```yaml
# rustdesk-app-kustomize.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk-prod
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/yourusername/rustdesk-k8s
    targetRevision: main
    path: manifests/overlays/prod

  destination:
    server: https://kubernetes.default.svc
    namespace: rustdesk-system

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Deploy Application

```bash
# Create the Application resource
kubectl apply -f rustdesk-app.yaml

# Check application status
argocd app get rustdesk

# Monitor sync
argocd app wait rustdesk --sync

# View application logs
kubectl logs -f deployment/argocd-application-controller -n argocd
```

## Continuous Delivery Workflow

### 1. Developer Makes Changes

```bash
# Developer commits to main branch
git add .
git commit -m "Update RustDesk relay replicas to 5"
git push origin main
```

### 2. ArgoCD Detects Change

```bash
# ArgoCD webhook receives GitHub push notification
# Syncs within seconds (or minutes depending on refresh interval)

# Check sync status
argocd app sync rustdesk
```

### 3. Kubernetes Updates

```bash
# Resources are automatically updated
kubectl get deployments -n rustdesk-system -w

# View rollout progress
kubectl rollout status deployment/rustdesk-hbbr -n rustdesk-system
```

## Advanced GitOps Features

### 1. Environment Promotion

```yaml
# Dev → Staging → Prod workflow
# Create separate Applications for each environment

# Dev (auto-sync)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk-dev
  namespace: argocd
spec:
  source:
    path: manifests/overlays/dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# Staging (manual sync required)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk-staging
  namespace: argocd
spec:
  source:
    path: manifests/overlays/staging
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
---
# Prod (manual sync with approval)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk-prod
  namespace: argocd
spec:
  source:
    path: manifests/overlays/prod
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### 2. Multi-Cluster Deployment

```yaml
# Deploy to multiple clusters
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rustdesk-global
  namespace: argocd
spec:
  source:
    path: helm
  
  destinations:
    - server: https://us-east-aks.kubeconfig
      namespace: rustdesk-system
    - server: https://eu-west-aks.kubeconfig
      namespace: rustdesk-system
```

### 3. Secrets Management with Sealed Secrets

```bash
# Install Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Encrypt secret for GitOps
echo -n 'my-secret-value' | kubeseal -o yaml > sealed-secret.yaml

# Check sealed secret
kubectl get sealedsecrets -n rustdesk-system
```

### 4. Notification/Webhooks

```yaml
# Configure GitHub webhook in ArgoCD UI
# Settings → Repositories → Add GitHub webhook

# Or via CLI
argocd proj role create-token default github-webhook

# Test webhook notification
curl -X POST https://argocd.yourdomain.com/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"push": {"repository": {"full_name": "yourusername/rustdesk-k8s"}}}'
```

## Troubleshooting GitOps

### Application stuck in "Syncing"

```bash
# Check application status
kubectl describe application rustdesk -n argocd

# View sync logs
argocd app logs rustdesk

# Force sync
argocd app sync rustdesk --force
```

### Git repository authentication fails

```bash
# Verify credentials
argocd repo get https://github.com/yourusername/rustdesk-k8s

# Re-add repository
argocd repo rm https://github.com/yourusername/rustdesk-k8s
argocd repo add https://github.com/yourusername/rustdesk-k8s \
  --username <token> \
  --password $(cat ~/.github-token)
```

### Manifests not updating

```bash
# Check refresh interval (default 3m)
kubectl get secret argocd-secret -n argocd -o yaml

# Manually trigger refresh
argocd app get rustdesk --refresh

# Enable webhook for instant sync
# Settings → Repositories → Enable webhook
```

## Best Practices

1. **Protection Rules:**
   - Require PR reviews before merging to main
   - Use branch protection rules in GitHub
   - Implement CODEOWNERS for approvals

2. **Secrets:**
   - Never commit secrets to Git
   - Use Sealed Secrets or External Secrets Operator
   - Rotate secrets regularly

3. **Testing:**
   - Use pre-commit hooks to validate manifests
   - Run `kubectl apply --dry-run` before commit
   - Use Kyverno policies for validation

4. **Monitoring:**
   - Enable ArgoCD notifications
   - Monitor application sync status
   - Set up Prometheus alerts for failures

5. **Documentation:**
   - Document deployment procedures
   - Keep README updated
   - Maintain runbooks for common issues

## Integrations

### Slack Notifications

```yaml
# ArgoCD Slack notification template
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} sync is {{.app.status.operationState.phase}}
      {{if eq .app.status.operationState.phase "Succeeded"}}:white_check_mark:{{end}}
```

### CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Trigger ArgoCD sync
        run: |
          argocd app sync rustdesk \
            --server argocd.yourdomain.com \
            --auth-token ${{ secrets.ARGOCD_TOKEN }}
```

## Reference Commands

```bash
# List all applications
argocd app list

# Get application status
argocd app get rustdesk

# Sync application
argocd app sync rustdesk

# Delete application
argocd app delete rustdesk

# Set auto-sync
argocd app set rustdesk --auto-prune

# Disable auto-sync
argocd app unset rustdesk --auto-prune

# View application logs
argocd app logs rustdesk --tail=100

# Get application manifests
argocd app manifests rustdesk

# Validate manifest
kubectl apply --dry-run=client -f manifest.yaml
```

## Conclusion

GitOps with ArgoCD provides:
- Declarative, version-controlled deployments
- Automated continuous delivery
- Easy rollback via Git history
- Audit trail of all changes
- Multi-cluster management

This enables RustDesk to achieve enterprise-grade deployment practices.
