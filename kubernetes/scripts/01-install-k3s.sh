#!/bin/bash

# ============================================================================
# RustDesk Phase 2 - K3S Installation Script
# Installs Kubernetes on Ubuntu 24.04 LTS for RustDesk deployment
# ============================================================================

set -e

KUBE_VERSION="${KUBE_VERSION:-v1.27.0}"
K3S_CHANNEL="${K3S_CHANNEL:-stable}"
INSTALL_DIR="/opt/k3s"
CONFIG_DIR="/etc/rancher/k3s"
DATA_DIR="/var/lib/rancher/k3s"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${GREEN}[${timestamp}]${NC} ${GREEN}✓${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[${timestamp}]${NC} ${YELLOW}⚠${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}]${NC} ${RED}✗${NC} $message"
            ;;
        HEADER)
            echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BLUE}║${NC} $message"
            echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
            ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "HEADER" "CHECKING PREREQUISITES"

    [[ $EUID -eq 0 ]] || error_exit "Must run as root"
    log "INFO" "Running as root"

    # Check OS
    if ! grep -q "24.04" /etc/issue; then
        log "WARN" "Not Ubuntu 24.04 - installation may require adjustments"
    fi

    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        error_exit "No internet connectivity - cannot download K3S"
    fi
    log "INFO" "Internet connectivity verified"

    # Check free space
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 5242880 ]]; then  # 5GB in KB
        error_exit "Insufficient disk space - need at least 5GB"
    fi
    log "INFO" "Disk space available: $(df -h / | awk 'NR==2 {print $4}')"

    # Check memory
    local mem=$(free -m | awk 'NR==2 {print $2}')
    if [[ $mem -lt 4096 ]]; then  # 4GB minimum
        log "WARN" "Less than 4GB RAM - performance may be limited"
    fi
    log "INFO" "Memory available: ${mem}MB"
}

# Update system packages
update_system() {
    log "HEADER" "UPDATING SYSTEM PACKAGES"

    apt-get update -qq
    apt-get upgrade -y -qq

    # Install required packages
    apt-get install -y -qq \
        curl \
        wget \
        git \
        jq \
        net-tools \
        vim \
        htop \
        iotop

    log "INFO" "System packages updated and installed"
}

# Disable swap (Kubernetes requirement)
disable_swap() {
    log "HEADER" "DISABLING SWAP"

    if grep -q "^[^#].*swap" /etc/fstab; then
        sed -i '/\sswap\s/s/^/#/' /etc/fstab
        log "INFO" "Swap disabled in /etc/fstab"
    fi

    if swapon --show | grep -q .; then
        swapoff -a
        log "INFO" "Swap disabled on running system"
    else
        log "INFO" "Swap already disabled"
    fi
}

# Configure kernel parameters
configure_kernel() {
    log "HEADER" "CONFIGURING KERNEL PARAMETERS"

    # Load required modules
    modprobe overlay
    modprobe br_netfilter

    # Add to /etc/modules-load.d/
    cat > /etc/modules-load.d/k3s.conf << 'EOF'
overlay
br_netfilter
EOF

    # Configure sysctl parameters
    cat > /etc/sysctl.d/99-k3s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.ip_nonlocal_bind=1
EOF

    sysctl --system > /dev/null
    log "INFO" "Kernel parameters configured"
}

# Install K3S
install_k3s() {
    log "HEADER" "INSTALLING K3S"

    local k3s_install_url="https://get.k3s.io"

    log "INFO" "Downloading K3S installer..."
    curl -sfL "$k3s_install_url" | INSTALL_K3S_CHANNEL="$K3S_CHANNEL" bash -

    log "INFO" "K3S installed successfully"

    # Verify installation
    if ! command -v k3s &> /dev/null; then
        error_exit "K3S installation verification failed"
    fi

    log "INFO" "K3S binary verified: $(k3s --version)"
}

# Configure kubectl
configure_kubectl() {
    log "HEADER" "CONFIGURING KUBECTL"

    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config

    # Export kubeconfig path
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
    echo 'export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"' >> /etc/profile.d/k3s.sh

    log "INFO" "kubectl configured"
    log "INFO" "Kubeconfig: /etc/rancher/k3s/k3s.yaml"
}

# Wait for K3S to be ready
wait_for_k3s() {
    log "HEADER" "WAITING FOR K3S CLUSTER"

    local max_attempts=60
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if kubectl get nodes &>/dev/null; then
            log "INFO" "K3S cluster is ready"
            return 0
        fi

        echo -ne "  Attempt $attempt/$max_attempts...\r"
        sleep 5
        ((attempt++))
    done

    error_exit "K3S cluster did not become ready in time"
}

# Verify cluster
verify_cluster() {
    log "HEADER" "VERIFYING CLUSTER"

    # Check nodes
    log "INFO" "Cluster nodes:"
    kubectl get nodes
    echo ""

    # Check system pods
    log "INFO" "System namespace pods:"
    kubectl get pods -n kube-system
    echo ""

    # Get cluster info
    log "INFO" "Cluster info:"
    kubectl cluster-info
    echo ""
}

# Install MetalLB (load balancer)
install_metallb() {
    log "HEADER" "INSTALLING METALLB (LOAD BALANCER)"

    # Create MetalLB namespace
    kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

    # Install MetalLB using Helm
    if ! command -v helm &> /dev/null; then
        log "WARN" "Helm not found - skipping MetalLB installation via Helm"
        log "INFO" "To install MetalLB manually, run:"
        log "INFO" "  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/manifests/namespace.yaml"
        log "INFO" "  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/manifests/metallb.yaml"
        return
    fi

    log "INFO" "Installing MetalLB using Helm..."
    helm repo add metallb https://metallb.universe.tf >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1

    helm install metallb metallb/metallb \
        --namespace metallb-system \
        --set controller.image.tag=v0.13.10 \
        --set speaker.image.tag=v0.13.10 \
        >/dev/null 2>&1

    log "INFO" "MetalLB installed"

    # Wait for MetalLB to be ready
    log "INFO" "Waiting for MetalLB to be ready..."
    kubectl wait --for=condition=ready pod -l app=metallb --namespace metallb-system --timeout=300s 2>/dev/null || true

    log "INFO" "MetalLB is ready"
}

# Install local-path provisioner
install_local_path_provisioner() {
    log "HEADER" "INSTALLING LOCAL-PATH PROVISIONER"

    # K3S comes with local-path provisioner, just verify it
    if kubectl get storageclass local-path >/dev/null 2>&1; then
        log "INFO" "Local-path provisioner is already installed"
        kubectl get storageclass
    else
        log "WARN" "Local-path provisioner not found"
    fi
}

# Print summary and next steps
print_summary() {
    log "HEADER" "K3S INSTALLATION COMPLETE"

    echo "Cluster Information:"
    echo "  API Server: https://127.0.0.1:6443"
    echo "  Kubeconfig: /etc/rancher/k3s/k3s.yaml"
    echo "  Kubectl: $(which kubectl)"
    echo ""

    echo "Next Steps:"
    echo "  1. Verify cluster: kubectl get nodes"
    echo "  2. Deploy RustDesk: helm install rustdesk ./kubernetes/helm"
    echo "  3. Check services: kubectl get svc -n rustdesk-system"
    echo ""

    echo "Useful Commands:"
    echo "  View cluster info: kubectl cluster-info"
    echo "  List all resources: kubectl get all --all-namespaces"
    echo "  Get pod logs: kubectl logs <pod-name> -n <namespace>"
    echo "  Port forward: kubectl port-forward <pod-name> <local-port>:<pod-port>"
    echo ""
}

# Main execution
main() {
    log "HEADER" "RUSTDESK PHASE 2 - K3S INSTALLATION"

    check_prerequisites
    update_system
    disable_swap
    configure_kernel
    install_k3s
    configure_kubectl
    wait_for_k3s
    verify_cluster
    install_metallb
    install_local_path_provisioner
    print_summary

    log "INFO" "K3S installation complete!"
}

main "$@"
