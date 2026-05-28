#!/bin/bash

# UFW Firewall Configuration for RustDesk
# Run on Ubuntu server: sudo bash configure-firewall.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$@"

    case "$level" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root. Use: sudo bash configure-firewall.sh"
fi

log "INFO" "RustDesk UFW Firewall Configuration"
log "INFO" "===================================="

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    log "INFO" "UFW not found. Installing UFW..."
    apt-get update -qq
    apt-get install -y ufw
    log "INFO" "UFW installed successfully"
fi

# Check if UFW is already enabled
if ufw status | grep -q "Status: inactive"; then
    log "WARN" "UFW is currently disabled. Will enable after configuring rules."
    UFW_WAS_INACTIVE=true
else
    log "INFO" "UFW is already enabled"
    UFW_WAS_INACTIVE=false
fi

# Set default policies
log "INFO" "Setting UFW default policies..."
ufw default deny incoming
ufw default allow outgoing
log "INFO" "Default policies set: deny incoming, allow outgoing"

# RustDesk hbbs (Signal Server) ports
log "INFO" "Configuring RustDesk hbbs (Signal Server) rules..."

ufw allow 21115/tcp comment "RustDesk hbbs TCP signal server" > /dev/null 2>&1
ufw allow 21116/tcp comment "RustDesk hbbs TCP connection" > /dev/null 2>&1
ufw allow 21116/udp comment "RustDesk hbbs UDP connection" > /dev/null 2>&1
ufw allow 21118/tcp comment "RustDesk hbbs web console" > /dev/null 2>&1

log "INFO" "hbbs rules added (ports 21115, 21116 TCP/UDP, 21118)"

# RustDesk hbbr (Relay Server) ports
log "INFO" "Configuring RustDesk hbbr (Relay Server) rules..."

ufw allow 21117/tcp comment "RustDesk hbbr main relay TCP" > /dev/null 2>&1
ufw allow 21117/udp comment "RustDesk hbbr main relay UDP" > /dev/null 2>&1
ufw allow 21119/tcp comment "RustDesk hbbr secondary relay" > /dev/null 2>&1

log "INFO" "hbbr rules added (ports 21117 TCP/UDP, 21119)"

# SSH access (CRITICAL - don't lock yourself out!)
log "INFO" "Configuring SSH access..."

ufw allow 22/tcp comment "SSH access" > /dev/null 2>&1

log "INFO" "SSH access allowed (port 22)"

# Optional: HTTP and HTTPS for future web dashboard
log "INFO" "Configuring HTTP/HTTPS for future web dashboard..."

ufw allow 80/tcp comment "HTTP - Future web dashboard" > /dev/null 2>&1
ufw allow 443/tcp comment "HTTPS - Future web dashboard" > /dev/null 2>&1

log "INFO" "HTTP/HTTPS rules added (ports 80, 443)"

# Optional: Docker services internal communication
log "INFO" "Configuring Docker network access..."

ufw allow from 172.22.0.0/16 comment "Docker internal network" > /dev/null 2>&1

log "INFO" "Docker network access configured"

# DNS (if running internal DNS resolver)
log "INFO" "Configuring DNS access..."

ufw allow 53/tcp comment "DNS TCP" > /dev/null 2>&1
ufw allow 53/udp comment "DNS UDP" > /dev/null 2>&1

log "INFO" "DNS rules added (port 53 TCP/UDP)"

# Enable UFW if it was not enabled before
if [[ "$UFW_WAS_INACTIVE" == "true" ]]; then
    log "INFO" "Enabling UFW..."
    echo "y" | ufw enable > /dev/null 2>&1
    log "INFO" "UFW is now enabled"
fi

# Display final status
log "INFO" ""
log "INFO" "UFW Configuration Complete"
log "INFO" "============================"

ufw show added || ufw status verbose

log "INFO" ""
log "INFO" "Summary of RustDesk Rules:"
log "INFO" "=========================="
log "INFO" "hbbs (Signal Server):"
log "INFO" "  - Port 21115/TCP  : Signal server listening"
log "INFO" "  - Port 21116/TCP  : TCP connection"
log "INFO" "  - Port 21116/UDP  : UDP connection"
log "INFO" "  - Port 21118/TCP  : Web console"
log "INFO" ""
log "INFO" "hbbr (Relay Server):"
log "INFO" "  - Port 21117/TCP  : Main relay (data)"
log "INFO" "  - Port 21117/UDP  : Main relay (data)"
log "INFO" "  - Port 21119/TCP  : Secondary relay"
log "INFO" ""
log "INFO" "Management:"
log "INFO" "  - Port 22/TCP     : SSH access"
log "INFO" "  - Port 80/TCP     : HTTP (future dashboard)"
log "INFO" "  - Port 443/TCP    : HTTPS (future dashboard)"
log "INFO" "  - Port 53/TCP/UDP : DNS"
log "INFO" ""

# Test connectivity
log "INFO" "Testing port listening status..."

netstat -tlnup | grep -E "(21115|21116|21117|21118|21119|22|80|443|53)" || log "WARN" "Some ports may not be listening yet"

log "INFO" "Firewall configuration complete!"
log "INFO" "To view full UFW status, run: sudo ufw status verbose"
log "INFO" "To reload rules, run: sudo ufw reload"
