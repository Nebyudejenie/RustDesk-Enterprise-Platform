# RustDesk Phase 2 - AKS Migration Guide

## Overview

This guide explains how to migrate RustDesk from local Kubernetes (k3s) to Azure Kubernetes Service (AKS).

## What Changes Between k3s and AKS

### 1. **Storage**

**k3s (local-path provisioner):**
```yaml
storageClassName: rustdesk-local
```

**AKS (managed disks):**
```yaml
storageClassName: managed-premium  # or managed-standard
```

### 2. **Load Balancing**

**k3s (MetalLB):**
```yaml
type: LoadBalancer
metallb.universe.tf/allow-shared-ip: "rustdesk-external"
```

**AKS (Azure Load Balancer):**
```yaml
type: LoadBalancer
service.beta.kubernetes.io/azure-load-balancer-internal: "false"  # External
```

### 3. **Networking**

**k3s:**
- Services exposed on node IPs via MetalLB
- External IP from local network pool

**AKS:**
- Public IPs assigned by Azure Load Balancer
- Use Azure Network Policies instead of Kubernetes NetworkPolicy

### 4. **Authentication & RBAC**

**k3s:**
- Basic kubeconfig authentication

**AKS:**
- Azure AD integration
- RBAC with Azure roles
- Use Azure Identity for pod authentication

## AKS-Specific Configuration

### values-aks.yaml

```yaml
# AKS-specific overrides
storage:
  storageClass: managed-premium
  accessMode: ReadWriteOnce

ingress:
  enabled: true
  className: azure-application-gateway  # Or nginx-ingress

serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<client-id>"
    azure.workload.identity/tenant-id: "<tenant-id>"

# Use Azure Container Registry
image:
  registry: yourregistry.azurecr.io
  repository: rustdesk/rustdesk-server
  
# Azure Key Vault for secrets
secrets:
  provider: azure-keyvault
  keyvaultName: "your-keyvault"
```

### Azure Disk Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium
provisioner: pd.csi.storage.gke.io
parameters:
  type: Premium_LRS
  replication-type: Regional
allowVolumeExpansion: true
```

### Azure Load Balancer Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rustdesk-hbbr-external
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"
    service.beta.kubernetes.io/azure-pip-name: "rustdesk-pip"
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - "0.0.0.0/0"  # Restrict to specific IPs in production
```

## Migration Steps

### 1. Create AKS Cluster

```bash
# Create resource group
az group create --name rustdesk-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group rustdesk-rg \
  --name rustdesk-aks \
  --node-count 3 \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin azure \
  --kubernetes-version 1.27.0

# Get credentials
az aks get-credentials \
  --resource-group rustdesk-rg \
  --name rustdesk-aks \
  --admin
```

### 2. Install Container Network Interface (CNI)

AKS uses Azure CNI by default - no additional installation needed.

### 3. Install Required Controllers

```bash
# Install Ingress Nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Install Cert-Manager (for HTTPS)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Install ArgoCD (GitOps)
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace
```

### 4. Create Service Principal (for Pod Identity)

```bash
# Create service principal
az ad sp create-for-rbac \
  --name rustdesk-pod-identity \
  --role Contributor \
  --scope /subscriptions/{subscription-id}

# Note the appId and password for use in values.yaml
```

### 5. Deploy RustDesk to AKS

```bash
# Deploy with AKS-specific values
helm install rustdesk ./kubernetes/helm \
  -f kubernetes/values.yaml \
  -f kubernetes/values-aks.yaml \
  --namespace rustdesk-system \
  --create-namespace
```

### 6. Verify Deployment

```bash
# Check services
kubectl get svc -n rustdesk-system -w

# Get external IP (note: takes a few minutes to provision)
kubectl get svc rustdesk-hbbr-external -n rustdesk-system

# Watch logs
kubectl logs -f deployment/rustdesk-hbbs -n rustdesk-system
```

## Key Differences in Operations

### Scaling

**k3s:**
```bash
kubectl scale deployment rustdesk-hbbr --replicas=5 -n rustdesk-system
```

**AKS (with VMSS):**
Same kubectl command works, but underlying VMs are auto-managed by Azure.

### Monitoring

**k3s:**
Use Prometheus + Grafana (self-hosted)

**AKS:**
Use Azure Monitor (native integration) or Prometheus in AKS.

### Backup & Recovery

**k3s:**
Manual PVC backup via kubectl cp or Velero

**AKS:**
Azure Backup for cluster backup
Velero for PVC backup

### Cost Optimization

1. **Auto-scaling:** Enable cluster autoscaling
   ```bash
   az aks update --enable-cluster-autoscaling \
     --min-count 2 --max-count 10 \
     --resource-group rustdesk-rg \
     --name rustdesk-aks
   ```

2. **Spot VMs:** Use Azure Spot instances for dev/staging
   ```yaml
   nodeSelector:
     agentpool: spotpool
   ```

3. **Reserved Instances:** Purchase 1-year or 3-year RIs for production

## Troubleshooting AKS-Specific Issues

### LoadBalancer stuck in "Pending"

```bash
# Check service events
kubectl describe svc rustdesk-hbbr-external -n rustdesk-system

# Verify Azure subscription limits
az account list-usage --query "[?contains(name.value, 'LoadBalancers')].{Name:name.localizedValue, Current:currentValue, Limit:limit}"
```

### Storage mounting issues

```bash
# Check PV/PVC binding
kubectl get pv,pvc -n rustdesk-system

# Describe failing PVC
kubectl describe pvc rustdesk-hbbs-pvc -n rustdesk-system
```

### Pod networking issues

```bash
# Check Azure subnet delegation
az network vnet subnet show \
  --resource-group rustdesk-rg \
  --vnet-name aks-vnet \
  --name aks-subnet

# Verify Network Policies
kubectl get networkpolicies -n rustdesk-system
```

## Cost Comparison: k3s vs AKS

### k3s (self-hosted on Proxmox VM)
- VM: ~$50-200/month (depending on size)
- Storage: Included
- Networking: Included
- **Total: $50-200/month**

### AKS (3-node cluster)
- VMs (3x Standard_B4ms): ~$300/month
- Load Balancer: ~$15/month
- Public IPs: ~$3/month per IP
- Storage (Premium): ~$0.15 per GB per month
- **Total: ~$350-400/month for production**

## Recommendations

1. **Start with k3s** for development and testing
2. **Migrate to AKS** when you need:
   - Enterprise SLA (99.99% uptime)
   - Multi-region failover
   - Integration with other Azure services
   - Automatic security updates
3. **Use Terraform/Bicep** for infrastructure as code
4. **Enable Azure Policy** for compliance and governance

## Additional Resources

- [AKS Best Practices](https://learn.microsoft.com/azure/aks/best-practices)
- [AKS Network Concepts](https://learn.microsoft.com/azure/aks/concepts-network)
- [AKS Storage Options](https://learn.microsoft.com/azure/aks/concepts-storage)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)
