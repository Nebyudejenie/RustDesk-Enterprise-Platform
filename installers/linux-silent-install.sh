#!/bin/bash

# RustDesk Linux Silent Installer
# Phase 1 - Unattended Access Setup
# Designed for Linux POS devices and Ubuntu VMs
# Run as root: sudo bash linux-silent-install.sh [device-id] [relay-host]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/rustdesk/install.log"
CONFIG_DIR="/etc/rustdesk"
INSTALL_DIR="/opt/rustdesk"

# Parameters with defaults
DEVICE_ID="${1:-POS-LINUX-001}"
RELAY_HOST="${2:-192.168.1.40}"
RELAY_PORT="${3:-21117}"
SIGNAL_SERVER="${4:-192.168.1.40:21115}"
PERMANENT_PASSWORD="${5:-POS@Enterprise2024!Secure}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root. Use: sudo bash linux-silent-install.sh"
fi

log "INFO" "===== RustDesk Linux Installation Start ====="
log "INFO" "Device ID: $DEVICE_ID"
log "INFO" "Relay Server: $RELAY_HOST:$RELAY_PORT"
log "INFO" "Signal Server: $SIGNAL_SERVER"
log "INFO" "System: $(uname -s) $(uname -r)"
log "INFO" "Hostname: $(hostname)"

# Step 1: Update system packages
log "INFO" "Updating system packages..."

if command -v apt-get &> /dev/null; then
    apt-get update -qq || log "WARN" "apt-get update failed, continuing..."
    apt-get install -y -qq curl wget unzip ca-certificates net-tools || log "WARN" "apt-get install failed, continuing..."
elif command -v yum &> /dev/null; then
    yum update -y -q || log "WARN" "yum update failed, continuing..."
    yum install -y -q curl wget unzip ca-certificates net-tools || log "WARN" "yum install failed, continuing..."
else
    log "WARN" "Unsupported package manager"
fi

# Step 2: Download RustDesk
log "INFO" "Downloading RustDesk..."

RUSTDESK_VERSION="1.2.7"
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/rustdesk-${RUSTDESK_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
        ;;
    aarch64)
        RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/rustdesk-${RUSTDESK_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
        ;;
    *)
        error_exit "Unsupported architecture: $ARCH"
        ;;
esac

RUSTDESK_TAR="/tmp/rustdesk-${RUSTDESK_VERSION}.tar.gz"

if ! curl -L -o "$RUSTDESK_TAR" "$RUSTDESK_URL" 2>/dev/null; then
    error_exit "Failed to download RustDesk from $RUSTDESK_URL"
fi

log "INFO" "Downloaded: $RUSTDESK_TAR"

# Step 3: Extract and install
log "INFO" "Extracting RustDesk..."

mkdir -p "$INSTALL_DIR"
tar -xzf "$RUSTDESK_TAR" -C "$INSTALL_DIR" 2>/dev/null || error_exit "Failed to extract RustDesk"

# Make executable
chmod +x "$INSTALL_DIR/rustdesk" 2>/dev/null || true

log "INFO" "RustDesk installed to: $INSTALL_DIR"

# Step 4: Create configuration directory and file
log "INFO" "Creating RustDesk configuration..."

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/RustDesk2.toml" << 'TOML_CONFIG'
[connection]
relay_host = "RELAY_HOST_PLACEHOLDER"
relay_port = RELAY_PORT_PLACEHOLDER
signal_server = "SIGNAL_SERVER_PLACEHOLDER"
relay_secret = ""
device_id = "DEVICE_ID_PLACEHOLDER"
custom_name = "DEVICE_ID_PLACEHOLDER"

[security]
permanent_password = "PASSWORD_PLACEHOLDER"
allow_remote_keyboard_input = true
allow_remote_mouse_input = true
allow_file_transfer = true
allow_remote_cm = true
ask_on_new_connection = false
approve_without_consent = true
accept_all_connections = true
lock_screen_on_disconnect = false
require_approval = false
require_password_on_incoming = false
request_permission_on_incoming = false

[auth]
use_permanent_password = true
password = "PASSWORD_PLACEHOLDER"

[service]
run_as_service = true
auto_start = true
start_on_boot = true

[logging]
log_level = "info"
log_to_file = true
log_file = "/var/log/rustdesk/client.log"

[ui]
hide_consent_dialog = true
disable_consent = true
local_ui_enabled = false

[files]
allow_file_transfer = true
file_transfer_timeout = 300

[network]
keep_alive_interval = 60
connection_timeout = 30
max_concurrent_connections = 1

[multimedia]
enable_audio = false
enable_video = false
enable_camera = false

[advanced]
encrypted_only = true
verify_certificate = true
auto_reconnect = true
reconnect_interval = 5
max_reconnect_attempts = 0
use_relay = true
relay_server_selection = "auto"
direct_connection = false
disable_ui = true
TOML_CONFIG

# Replace placeholders
sed -i "s|RELAY_HOST_PLACEHOLDER|$RELAY_HOST|g" "$CONFIG_DIR/RustDesk2.toml"
sed -i "s|RELAY_PORT_PLACEHOLDER|$RELAY_PORT|g" "$CONFIG_DIR/RustDesk2.toml"
sed -i "s|SIGNAL_SERVER_PLACEHOLDER|$SIGNAL_SERVER|g" "$CONFIG_DIR/RustDesk2.toml"
sed -i "s|DEVICE_ID_PLACEHOLDER|$DEVICE_ID|g" "$CONFIG_DIR/RustDesk2.toml"
sed -i "s|PASSWORD_PLACEHOLDER|$PERMANENT_PASSWORD|g" "$CONFIG_DIR/RustDesk2.toml"

chmod 600 "$CONFIG_DIR/RustDesk2.toml"
log "INFO" "Configuration created: $CONFIG_DIR/RustDesk2.toml"

# Step 5: Create systemd service unit
log "INFO" "Creating systemd service unit..."

cat > /etc/systemd/system/rustdesk.service << 'SERVICE_CONFIG'
[Unit]
Description=RustDesk Remote Access Service
After=network.target

[Service]
Type=simple
User=rustdesk
WorkingDirectory=/opt/rustdesk
ExecStart=/opt/rustdesk/rustdesk
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rustdesk

# Service hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/etc/rustdesk /var/log/rustdesk /root

[Install]
WantedBy=multi-user.target
SERVICE_CONFIG

chmod 644 /etc/systemd/system/rustdesk.service
systemctl daemon-reload

log "INFO" "Systemd service created: /etc/systemd/system/rustdesk.service"

# Step 6: Create rustdesk user
log "INFO" "Creating rustdesk system user..."

if ! id "rustdesk" &>/dev/null; then
    useradd --system --home /var/lib/rustdesk --shell /usr/sbin/nologin rustdesk 2>/dev/null || log "WARN" "rustdesk user already exists"
else
    log "INFO" "rustdesk user already exists"
fi

# Create necessary directories
mkdir -p /var/lib/rustdesk /var/log/rustdesk
chown -R rustdesk:rustdesk /var/lib/rustdesk /var/log/rustdesk /opt/rustdesk
chmod 755 /opt/rustdesk

# Step 7: Configure firewall (UFW)
log "INFO" "Configuring firewall rules..."

if command -v ufw &> /dev/null; then
    ufw allow 21117/tcp > /dev/null 2>&1 || log "WARN" "Failed to add UFW rule for port 21117/tcp"
    ufw allow 21117/udp > /dev/null 2>&1 || log "WARN" "Failed to add UFW rule for port 21117/udp"
    log "INFO" "UFW rules configured"
else
    log "WARN" "UFW not found, skipping firewall configuration"
fi

# Step 8: Enable and start service
log "INFO" "Enabling and starting RustDesk service..."

systemctl enable rustdesk > /dev/null 2>&1 || error_exit "Failed to enable rustdesk service"
systemctl start rustdesk > /dev/null 2>&1 || error_exit "Failed to start rustdesk service"

sleep 2

# Step 9: Verification
log "INFO" "Verifying installation..."

VERIFICATION_PASSED=true

# Check if executable exists
if [[ -f "$INSTALL_DIR/rustdesk" ]]; then
    log "INFO" "✓ RustDesk executable found"
else
    log "ERROR" "✗ RustDesk executable NOT found"
    VERIFICATION_PASSED=false
fi

# Check if service is running
if systemctl is-active --quiet rustdesk; then
    log "INFO" "✓ RustDesk service is running"
else
    log "WARN" "✗ RustDesk service is NOT running"
    VERIFICATION_PASSED=false
fi

# Check if config file exists
if [[ -f "$CONFIG_DIR/RustDesk2.toml" ]]; then
    log "INFO" "✓ Configuration file found"
else
    log "ERROR" "✗ Configuration file NOT found"
    VERIFICATION_PASSED=false
fi

# Check if service is enabled
if systemctl is-enabled --quiet rustdesk; then
    log "INFO" "✓ RustDesk service is enabled for auto-start"
else
    log "WARN" "✗ RustDesk service is NOT enabled for auto-start"
fi

# Check network connectivity
if netstat -tlnup 2>/dev/null | grep -q "21117"; then
    log "INFO" "✓ Port 21117 is listening"
else
    log "WARN" "✗ Port 21117 is NOT listening (service may need time to start)"
fi

# Step 10: Register device information
log "INFO" "Registering device information..."

cat > /etc/rustdesk/device.info << DEVICE_INFO
DEVICE_ID=$DEVICE_ID
RELAY_HOST=$RELAY_HOST
RELAY_PORT=$RELAY_PORT
SIGNAL_SERVER=$SIGNAL_SERVER
INSTALL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
OS=$(uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
DEVICE_INFO

chmod 600 /etc/rustdesk/device.info
log "INFO" "Device information registered"

# Final status
log "INFO" "===== RustDesk Linux Installation Complete ====="
log "INFO" "Device ID: $DEVICE_ID"
log "INFO" "Relay Server: $RELAY_HOST:$RELAY_PORT"
log "INFO" "Service Status: $(systemctl is-active rustdesk)"
log "INFO" "Service Enabled: $(systemctl is-enabled rustdesk)"
log "INFO" "Configuration: $CONFIG_DIR/RustDesk2.toml"
log "INFO" "Log File: $LOG_FILE"

if [[ "$VERIFICATION_PASSED" == "true" ]]; then
    log "INFO" "Status: Installation SUCCESSFUL"
else
    log "WARN" "Status: Installation COMPLETED with warnings"
fi

# Clean up installer
log "INFO" "Cleaning up temporary files..."
rm -f "$RUSTDESK_TAR"
rm -f "$0"  # Self-delete the installer script

log "INFO" "Installation script completed"
