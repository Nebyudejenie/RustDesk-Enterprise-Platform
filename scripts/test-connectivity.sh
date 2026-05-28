#!/bin/bash

# ============================================================================
# RustDesk Phase 1 - Connectivity & Health Test Script
# Comprehensive testing of all services and ports
# ============================================================================

set -e

RELAY_HOST="${1:-192.168.1.40}"
TEST_LOG="/tmp/rustdesk-connectivity-test-$(date +%s).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "" | tee "$TEST_LOG"
echo "╔════════════════════════════════════════════════════════════╗" | tee -a "$TEST_LOG"
echo "║   RustDesk Phase 1 - Connectivity & Health Test" | tee -a "$TEST_LOG"
echo "║   Target: $RELAY_HOST" | tee -a "$TEST_LOG"
echo "╚════════════════════════════════════════════════════════════╝" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

# Test function
test_port() {
    local host="$1"
    local port="$2"
    local service="$3"

    if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Port $port ($service) is ${GREEN}RESPONDING${NC}" | tee -a "$TEST_LOG"
        return 0
    else
        echo -e "${RED}✗${NC} Port $port ($service) is ${RED}NOT RESPONDING${NC}" | tee -a "$TEST_LOG"
        return 1
    fi
}

# Test all ports
echo "Testing RustDesk Server Connectivity:" | tee -a "$TEST_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$TEST_LOG"

PASSED=0
FAILED=0

test_port "$RELAY_HOST" 21115 "hbbs signal server" && ((PASSED++)) || ((FAILED++))
test_port "$RELAY_HOST" 21116 "hbbs connection" && ((PASSED++)) || ((FAILED++))
test_port "$RELAY_HOST" 21117 "hbbr relay (DATA)" && ((PASSED++)) || ((FAILED++))
test_port "$RELAY_HOST" 21118 "hbbs web console" && ((PASSED++)) || ((FAILED++))
test_port "$RELAY_HOST" 21119 "hbbr secondary relay" && ((PASSED++)) || ((FAILED++))

echo "" | tee -a "$TEST_LOG"
echo "Test Results:" | tee -a "$TEST_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$TEST_LOG"
echo -e "  Passed: ${GREEN}$PASSED/5${NC}" | tee -a "$TEST_LOG"
echo -e "  Failed: ${RED}$FAILED/5${NC}" | tee -a "$TEST_LOG"
echo "" | tee -a "$TEST_LOG"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED - RustDesk Server is OPERATIONAL${NC}" | tee -a "$TEST_LOG"
    echo "" | tee -a "$TEST_LOG"
    echo "Service Status:" | tee -a "$TEST_LOG"
    echo "  • hbbs (signal server) - READY for device registration" | tee -a "$TEST_LOG"
    echo "  • hbbr (relay server) - READY for data relay" | tee -a "$TEST_LOG"
    echo "  • All ports open and responding" | tee -a "$TEST_LOG"
    echo "" | tee -a "$TEST_LOG"
    echo "Ready for POS device deployment!" | tee -a "$TEST_LOG"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED - Check service status${NC}" | tee -a "$TEST_LOG"
    echo "" | tee -a "$TEST_LOG"
    echo "Troubleshooting:" | tee -a "$TEST_LOG"
    echo "  1. Check service logs: docker compose logs hbbs" | tee -a "$TEST_LOG"
    echo "  2. Verify firewall: sudo ufw status verbose" | tee -a "$TEST_LOG"
    echo "  3. Check containers: docker compose ps" | tee -a "$TEST_LOG"
    exit 1
fi
