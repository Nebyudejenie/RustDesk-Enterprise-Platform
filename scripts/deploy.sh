#!/bin/bash

# RustDesk Phase 1 Automated Deployment Script
# This script automates the entire deployment process
# Usage: sudo bash deploy.sh [action] [optional-args]

set -e

# Configuration
PROJECT_DIR="/opt/rustdesk-platform"
RELAY_HOST="${RELAY_HOST:-192.168.1.40}"
RELAY_PORT="${RELAY_PORT:-21117}"
SIGNAL_SERVER="${SIGNAL_SERVER:-192.168.1.40:21115}"
LOG_FILE="/var/log/rustdesk-deploy.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${GREEN}[${timestamp} INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        WARN)
            echo -e "${YELLOW}[${timestamp} WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp} ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        DEBUG)
            echo -e "${BLUE}[${timestamp} DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo bash deploy.sh"
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed"
    fi
    log "INFO" "✓ Docker installed: $(docker --version)"

    # Check Docker Compose
    if ! command -v docker compose &> /dev/null; then
        error_exit "Docker Compose is not installed"
    fi
    log "INFO" "✓ Docker Compose installed: $(docker compose --version)"

    # Check project directory
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error_exit "Project directory not found: $PROJECT_DIR"
    fi
    log "INFO" "✓ Project directory found: $PROJECT_DIR"

    # Check required files
    local required_files=(
        "docker compose.yml"
        ".env"
        "configs/RustDesk2.toml"
        "scripts/configure-firewall.sh"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_DIR/$file" ]]; then
            error_exit "Required file not found: $PROJECT_DIR/$file"
        fi
    done
    log "INFO" "✓ All required files present"
}

# Deploy services
deploy() {
    log "INFO" "Starting RustDesk deployment..."

    # Change to project directory
    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"

    # Create data directories
    log "INFO" "Creating data directories..."
    mkdir -p data/{hbbs,hbbr,postgres}/{logs,keys,config}
    chmod 755 data/*
    log "INFO" "✓ Data directories created"

    # Configure firewall
    log "INFO" "Configuring UFW firewall..."
    if [[ -f "scripts/configure-firewall.sh" ]]; then
        bash scripts/configure-firewall.sh >> "$LOG_FILE" 2>&1
        log "INFO" "✓ Firewall configured"
    fi

    # Build/pull images if needed
    log "INFO" "Pulling Docker images..."
    docker compose pull >> "$LOG_FILE" 2>&1
    log "INFO" "✓ Docker images updated"

    # Start services
    log "INFO" "Starting Docker Compose services..."
    docker compose up -d >> "$LOG_FILE" 2>&1
    log "INFO" "✓ Services started"

    # Wait for services to be healthy
    log "INFO" "Waiting for services to become healthy..."
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        local hbbs_status=$(docker ps --filter "name=rustdesk-hbbs" --format "{{.Status}}" 2>/dev/null || echo "")

        if [[ "$hbbs_status" == *"healthy"* ]]; then
            log "INFO" "✓ Services are healthy"
            break
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log "WARN" "Services did not reach healthy status within timeout"
        fi

        echo -ne "  Attempt $attempt/$max_attempts...\r"
        sleep 2
        ((attempt++))
    done

    # Display service status
    log "INFO" "Service status:"
    docker compose ps | tee -a "$LOG_FILE"

    # Show listening ports
    log "INFO" "Listening ports:"
    netstat -tlnup 2>/dev/null | grep -E "21115|21116|21117|21118|21119" | sed 's/^/  /' | tee -a "$LOG_FILE" || true

    log "INFO" "✓ Deployment completed successfully!"
}

# Stop services
stop() {
    log "INFO" "Stopping RustDesk services..."

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"
    docker compose down >> "$LOG_FILE" 2>&1

    log "INFO" "✓ Services stopped"
}

# Restart services
restart() {
    log "INFO" "Restarting RustDesk services..."

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"
    docker compose restart >> "$LOG_FILE" 2>&1

    sleep 2

    log "INFO" "Service status:"
    docker compose ps

    log "INFO" "✓ Services restarted"
}

# Show status
status() {
    log "INFO" "RustDesk Service Status"
    log "INFO" "======================="

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"

    docker compose ps

    log "INFO" ""
    log "INFO" "Network Status:"
    netstat -tlnup 2>/dev/null | grep -E "21115|21116|21117|21118|21119" | sed 's/^/  /' || true

    log "INFO" ""
    log "INFO" "Container Resource Usage:"
    docker stats --no-stream rustdesk-hbbs rustdesk-hbbr 2>/dev/null || true

    log "INFO" ""
    log "INFO" "Recent Logs (hbbs):"
    docker logs --tail 5 rustdesk-hbbs | sed 's/^/  /'

    log "INFO" ""
    log "INFO" "Recent Logs (hbbr):"
    docker logs --tail 5 rustdesk-hbbr | sed 's/^/  /'
}

# View logs
logs() {
    local service="${1:-all}"

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"

    if [[ "$service" == "all" ]]; then
        docker compose logs -f
    else
        docker compose logs -f "$service"
    fi
}

# Generate device installer URL
generate_installer_url() {
    log "INFO" "Device Installer URLs"
    log "INFO" "===================="
    log "INFO" ""
    log "INFO" "Windows POS Device (PowerShell):"
    log "INFO" "powershell -ExecutionPolicy Bypass -Command @\""
    log "INFO" "\$url = 'http://$RELAY_HOST:8000/installers/windows-silent-install.ps1'"
    log "INFO" "\$params = @{ DeviceId = 'POS-ADDIS-001'; RelayHost = '$RELAY_HOST'; RelayPort = $RELAY_PORT; SignalServer = '$SIGNAL_SERVER' }"
    log "INFO" "Invoke-WebRequest -Uri \$url -OutFile \$env:TEMP\install.ps1 -UseBasicParsing"
    log "INFO" "& \$env:TEMP\install.ps1 @params"
    log "INFO" "\"@"
    log "INFO" ""
    log "INFO" "Linux POS Device (Bash):"
    log "INFO" "curl -fsSL http://$RELAY_HOST:8000/installers/linux-silent-install.sh | bash -s 'POS-LINUX-001' '$RELAY_HOST' '$RELAY_PORT'"
}

# Backup configuration
backup() {
    log "INFO" "Backing up RustDesk configuration..."

    local backup_dir="/backup/rustdesk-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"

    # Backup key files
    cp -r data/hbbs/keys "$backup_dir/" 2>/dev/null || true
    cp -r data/hbbr "$backup_dir/" 2>/dev/null || true
    cp .env "$backup_dir/" 2>/dev/null || true
    cp docker compose.yml "$backup_dir/" 2>/dev/null || true

    log "INFO" "✓ Backup created: $backup_dir"
}

# Verify installation
verify() {
    log "INFO" "Verifying RustDesk installation..."

    cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"

    local all_pass=true

    # Check containers
    if docker compose ps | grep -q "rustdesk-hbbs"; then
        log "INFO" "✓ hbbs container is running"
    else
        log "WARN" "✗ hbbs container is NOT running"
        all_pass=false
    fi

    if docker compose ps | grep -q "rustdesk-hbbr"; then
        log "INFO" "✓ hbbr container is running"
    else
        log "WARN" "✗ hbbr container is NOT running"
        all_pass=false
    fi

    # Check ports
    local ports=(21115 21116 21117 21118 21119)
    for port in "${ports[@]}"; do
        if ss -tlnup 2>/dev/null | grep -q ":$port"; then
            log "INFO" "✓ Port $port is listening"
        else
            log "WARN" "✗ Port $port is NOT listening"
            all_pass=false
        fi
    done

    # Check data directories
    if [[ -d "data/hbbs" ]] && [[ -d "data/hbbr" ]]; then
        log "INFO" "✓ Data directories exist"
    else
        log "WARN" "✗ Data directories NOT found"
        all_pass=false
    fi

    if [[ "$all_pass" == "true" ]]; then
        log "INFO" "✓ All checks passed!"
    else
        log "WARN" "⚠ Some checks failed - see details above"
    fi
}

# Clean up (stop and remove containers)
cleanup() {
    log "WARN" "This will stop and remove all RustDesk containers and volumes!"
    read -p "Are you sure? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        cd "$PROJECT_DIR" || error_exit "Cannot change to project directory"
        docker compose down -v >> "$LOG_FILE" 2>&1
        log "INFO" "✓ Cleanup completed"
    else
        log "INFO" "Cleanup cancelled"
    fi
}

# Show usage
usage() {
    cat << EOF
RustDesk Phase 1 Deployment Script

Usage: sudo bash deploy.sh [COMMAND] [ARGUMENTS]

Commands:
  deploy              Deploy and start all services
  stop                Stop all services
  restart             Restart all services
  status              Show current service status
  logs [service]      View service logs (all|hbbs|hbbr)
  verify              Verify installation
  backup              Backup configuration and keys
  urls                Show device installer URLs
  cleanup             Stop and remove all containers (CAUTION!)
  help                Show this help message

Examples:
  sudo bash deploy.sh deploy
  sudo bash deploy.sh status
  sudo bash deploy.sh logs hbbs
  sudo bash deploy.sh logs -f hbbr

Environment Variables:
  RELAY_HOST          Relay server IP (default: 192.168.1.40)
  RELAY_PORT          Relay port (default: 21117)
  SIGNAL_SERVER       Signal server address (default: 192.168.1.40:21115)

Log file: $LOG_FILE

EOF
}

# Main script logic
main() {
    mkdir -p "$(dirname "$LOG_FILE")"

    case "${1:-help}" in
        deploy)
            check_prerequisites
            deploy
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "${2:-all}"
            ;;
        verify)
            verify
            ;;
        backup)
            backup
            ;;
        urls)
            generate_installer_url
            ;;
        cleanup)
            cleanup
            ;;
        help)
            usage
            ;;
        *)
            echo "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
