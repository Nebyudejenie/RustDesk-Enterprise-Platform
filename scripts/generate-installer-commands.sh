#!/bin/bash

# ============================================================================
# RustDesk Phase 1 - Generate POS Device Installer Commands
# Creates copy-paste ready deployment commands for POS devices
# ============================================================================

RELAY_HOST="${1:-192.168.1.40}"
DEVICE_PREFIX="${2:-POS-ADDIS}"
NUM_DEVICES="${3:-5}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

cat << "BANNER"

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║           RustDesk Phase 1 - POS Device Installer Commands                ║
║                                                                            ║
║  Copy and paste these commands on POS devices for silent installation      ║
║  No user interaction required - devices will auto-connect to relay         ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

BANNER

echo ""
echo "Configuration:"
echo "  Relay Server: $RELAY_HOST"
echo "  Device Prefix: $DEVICE_PREFIX"
echo "  Generating: $NUM_DEVICES device IDs"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate Windows installer commands
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}WINDOWS POS DEVICES (Windows 10/11)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. On Windows POS device, open PowerShell as Administrator"
echo "2. Copy and paste ONE of the commands below"
echo "3. Press Enter and wait for installation to complete (~2-3 minutes)"
echo "4. Device will auto-connect to RustDesk relay"
echo ""

for i in $(seq 1 $NUM_DEVICES); do
    device_id=$(printf "%s-%03d" "$DEVICE_PREFIX" "$i")
    echo -e "${GREEN}Device $i: $device_id${NC}"
    cat << WINDOWS_INSTALL
powershell -ExecutionPolicy Bypass -Command @"
\$params = @{
    DeviceId = '$device_id'
    RelayHost = '$RELAY_HOST'
    RelayPort = 21117
    SignalServer = '$RELAY_HOST:21115'
    PermanentPassword = 'POS@Enterprise2024!Secure'
}
\$script = Invoke-WebRequest -Uri 'http://$RELAY_HOST:8000/installers/windows-silent-install.ps1' -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-Expression \$([scriptblock]::Create(\$script)) @params
"@
WINDOWS_INSTALL
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate Linux installer commands
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}LINUX POS DEVICES (Ubuntu/Debian-based)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. On Linux POS device, open Terminal"
echo "2. Copy and paste ONE of the commands below (as root or with sudo)"
echo "3. Press Enter and wait for installation to complete (~1-2 minutes)"
echo "4. Device will auto-connect to RustDesk relay"
echo ""

for i in $(seq 1 $NUM_DEVICES); do
    device_id=$(printf "%s-%03d" "$DEVICE_PREFIX" "$i")
    echo -e "${GREEN}Device $i: $device_id${NC}"
    cat << LINUX_INSTALL
sudo bash << 'EOF'
curl -fsSL http://$RELAY_HOST:8000/installers/linux-silent-install.sh | \\
  bash -s "$device_id" "$RELAY_HOST" "21117"
EOF
LINUX_INSTALL
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test commands
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}TESTING DEPLOYMENT (Run on support engineer's machine)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "After installing on a POS device, test with RustDesk client:"
echo ""
echo "1. Download RustDesk client: https://rustdesk.com/download"
echo "2. Launch RustDesk client"
echo "3. Enter one of these device IDs:"
echo ""

for i in $(seq 1 $NUM_DEVICES); do
    device_id=$(printf "%s-%03d" "$DEVICE_PREFIX" "$i")
    echo "   • $device_id"
done

echo ""
echo "4. Click Connect"
echo ""
echo -e "${GREEN}Expected behavior:${NC}"
echo "  ✓ NO approval dialog on POS device"
echo "  ✓ NO permission prompts"
echo "  ✓ Connection established immediately"
echo "  ✓ Full keyboard/mouse control available"
echo "  ✓ File transfer works"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Monitoring
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}MONITORING DEPLOYMENTS${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Watch installation logs in real-time:"
echo "  sudo docker compose logs -f hbbs"
echo ""
echo "Monitor relay server:"
echo "  sudo docker compose logs -f hbbr"
echo ""
echo "Check connected devices:"
echo "  sudo docker exec rustdesk-hbbs sh -c 'ls -la /root/db_v2.sqlite3'"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${GREEN}✓ Generation complete!${NC}"
echo ""
echo "Save these commands for deployment:"
echo "  • Print this output"
echo "  • Save to file: bash generate-installer-commands.sh > installer-commands.txt"
echo "  • Share with deployment team"
echo ""
