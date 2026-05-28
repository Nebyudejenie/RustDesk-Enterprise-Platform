# RustDesk Phase 1 - Verification & Deployment Guide

## Pre-Deployment Checklist

### 1. Ubuntu Server Requirements
- [ ] Ubuntu 24.04 LTS installed
- [ ] SSH access: `cosmic@192.168.1.40`
- [ ] Docker installed: `docker --version`
- [ ] Docker Compose installed: `docker-compose --version`
- [ ] Minimum 2GB RAM available
- [ ] Minimum 10GB disk space available
- [ ] Network connectivity confirmed

**Verify Ubuntu setup:**
```bash
ssh cosmic@192.168.1.40
uname -a
docker --version
docker-compose --version
df -h
free -h
```

### 2. Project Structure Verification
```bash
# Verify all required files exist
ls -la /home/prophet/rustdisk/

# Expected files:
# - docker-compose.yml
# - .env
# - configs/RustDesk2.toml
# - installers/windows-silent-install.ps1
# - installers/linux-silent-install.sh
# - scripts/configure-firewall.sh
# - data/ (directories for volumes)
```

## Deployment Steps

### Step 1: Copy files to Ubuntu server

```bash
# From your local machine
scp -r /home/prophet/rustdisk cosmic@192.168.1.40:/opt/rustdesk-platform

# Or using rsync (faster for large directories)
rsync -avz --delete /home/prophet/rustdisk/ cosmic@192.168.1.40:/opt/rustdesk-platform/
```

### Step 2: SSH into the Ubuntu server

```bash
ssh cosmic@192.168.1.40
cd /opt/rustdesk-platform
```

### Step 3: Configure firewall (IMPORTANT!)

```bash
# Make firewall script executable
sudo chmod +x scripts/configure-firewall.sh

# Run firewall configuration
sudo bash scripts/configure-firewall.sh

# Verify UFW status
sudo ufw status verbose
```

**Expected output should show:**
- Port 21115/TCP allowed (hbbs signal)
- Port 21116/TCP and UDP allowed (hbbs connection)
- Port 21117/TCP and UDP allowed (hbbr relay)
- Port 21118/TCP allowed (hbbs web console)
- Port 21119/TCP allowed (hbbr secondary relay)
- Port 22/TCP allowed (SSH)

### Step 4: Create data directories

```bash
cd /opt/rustdesk-platform

# Create volume directories with proper permissions
mkdir -p data/{hbbs,hbbr}/{logs,keys}
mkdir -p data/postgres

# Set permissions
sudo chown -R 1000:1000 data/

# Verify
ls -la data/
```

### Step 5: Start Docker Compose services

```bash
# From /opt/rustdesk-platform directory
sudo docker-compose up -d

# Verify containers are running
sudo docker-compose ps

# Expected output:
# NAME           STATUS
# rustdesk-hbbs  Up X seconds (healthy)
# rustdesk-hbbr  Up X seconds (healthy)
```

### Step 6: Check service logs

```bash
# View hbbs logs
sudo docker-compose logs -f hbbs

# View hbbr logs
sudo docker-compose logs -f hbbr

# Press Ctrl+C to exit logs
```

**Expected hbbs startup logs:**
```
hbbs | [info] RustDesk Server is running...
hbbs | [info] Listening on 0.0.0.0:21115
hbbs | [info] Database initialized
```

## Post-Deployment Verification

### 1. Verify services are running

```bash
# Check Docker containers
sudo docker ps | grep rustdesk

# Check listening ports on the host
sudo netstat -tlnup | grep -E "21115|21116|21117|21118|21119"

# Alternative with ss command
sudo ss -tlnup | grep -E "21115|21116|21117|21118|21119"
```

**Expected output (ports listening):**
```
LISTEN tcp  0  0  0.0.0.0:21115    0.0.0.0:*
LISTEN tcp  0  0  0.0.0.0:21116    0.0.0.0:*
LISTEN udp  0  0  0.0.0.0:21116    0.0.0.0:*
LISTEN tcp  0  0  0.0.0.0:21117    0.0.0.0:*
LISTEN udp  0  0  0.0.0.0:21117    0.0.0.0:*
LISTEN tcp  0  0  0.0.0.0:21118    0.0.0.0:*
LISTEN tcp  0  0  0.0.0.0:21119    0.0.0.0:*
```

### 2. Test hbbs health check

```bash
# Using curl to test hbbs web console
curl -I http://192.168.1.40:21118

# Expected response: HTTP/1.1 or 200 OK
```

### 3. Check container resource usage

```bash
# Real-time monitoring
sudo docker stats rustdesk-hbbs rustdesk-hbbr

# One-time check
sudo docker ps --format="table {{.Names}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### 4. Verify volume mounts

```bash
# Check if persistent volumes contain expected files
ls -la data/hbbs/
ls -la data/hbbr/

# These should contain RustDesk generated keys and configurations
# If empty, check container logs for errors
```

### 5. Network connectivity test

```bash
# Test connection from another machine on the network
telnet 192.168.1.40 21115
telnet 192.168.1.40 21117

# For UDP, use nc (netcat)
nc -u 192.168.1.40 21116
```

## Windows POS Device Installation

### Deployment Method 1: Direct PowerShell (Recommended)

```powershell
# On Windows POS device, run as Administrator:
powershell -ExecutionPolicy Bypass -Command @"
$url = 'http://192.168.1.40:8000/installers/windows-silent-install.ps1'
$params = @{
    DeviceId = 'POS-ADDIS-001'
    RelayHost = '192.168.1.40'
    RelayPort = 21117
    SignalServer = '192.168.1.40:21115'
    PermanentPassword = 'POS@Enterprise2024!Secure'
}
Invoke-WebRequest -Uri $url -OutFile $env:TEMP\install.ps1 -UseBasicParsing
& $env:TEMP\install.ps1 @params
"@
```

### Deployment Method 2: Local file (Offline)

```powershell
# On Windows POS device, run as Administrator:
# Copy windows-silent-install.ps1 to the device, then run:
powershell -ExecutionPolicy Bypass -File "C:\Install\windows-silent-install.ps1" `
    -DeviceId "POS-ADDIS-001" `
    -RelayHost "192.168.1.40" `
    -RelayPort 21117 `
    -SignalServer "192.168.1.40:21115" `
    -PermanentPassword "POS@Enterprise2024!Secure"
```

### Verify Windows installation

```powershell
# Check if RustDesk service is running
Get-Service RustDesk | Select-Object Status, StartType

# Check if configuration file exists
Test-Path "$env:APPDATA\RustDesk\RustDesk2.toml"

# View installation log
Get-Content "C:\RustDesk\install.log"

# Check if RustDesk is listening on ports
netstat -ano | findstr "21115\|21117"

# Query Windows Registry for device ID
Get-ItemProperty -Path "HKLM:\SOFTWARE\RustDesk" | Select-Object DeviceId, RelayHost
```

## Linux POS Device Installation

### Deployment Method 1: curl | bash (Recommended)

```bash
# On Linux POS device, run as root:
curl -fsSL http://192.168.1.40:8000/installers/linux-silent-install.sh | bash -s "POS-LINUX-001" "192.168.1.40" "21117"

# Parameters:
# - Device ID: POS-LINUX-001
# - Relay Host: 192.168.1.40
# - Relay Port: 21117
```

### Deployment Method 2: Local file (Offline)

```bash
# On Linux POS device, run as root:
sudo bash linux-silent-install.sh "POS-LINUX-001" "192.168.1.40" "21117"
```

### Verify Linux installation

```bash
# Check if RustDesk service is running
sudo systemctl status rustdesk

# Check service logs
sudo journalctl -u rustdesk -f

# Verify configuration file
cat /etc/rustdesk/RustDesk2.toml

# Check device info
cat /etc/rustdesk/device.info

# Verify ports are listening
netstat -tlnup | grep -E "21115|21116|21117"

# Check if service starts on boot
sudo systemctl is-enabled rustdesk
```

## Testing Unattended Access

### Test 1: Service connectivity verification

**From the RustDesk server:**
```bash
# Check if devices are registered
sudo docker exec rustdesk-hbbs bash -c "ls /root/keys"

# Monitor active connections
sudo docker logs -f rustdesk-hbbr | grep -i "connection\|relay"
```

### Test 2: Manual connection test

**Using RustDesk client on support engineer's machine:**

1. Download RustDesk client: https://rustdesk.com/download
2. Launch RustDesk
3. Enter Device ID: `POS-ADDIS-001` (or your configured ID)
4. Click "Connect"
5. **Expected behavior:**
   - NO approval dialog on POS device
   - NO permission prompt on POS device
   - Connection established immediately
   - Full keyboard/mouse control
   - File transfer available

### Test 3: Verify no approval popups

```bash
# Check RustDesk2.toml on POS device for confirmation
# These values should be set:
# approve_without_consent = true
# accept_all_connections = true
# ask_on_new_connection = false
# require_approval = false
```

## Troubleshooting

### Issue: Docker containers not starting

```bash
# Check Docker daemon
sudo systemctl status docker

# View detailed error logs
sudo docker-compose logs hbbs
sudo docker-compose logs hbbr

# Restart Docker service
sudo systemctl restart docker
sudo docker-compose up -d
```

### Issue: Ports not listening

```bash
# Check if firewall is blocking ports
sudo ufw status verbose

# Allow ports if missing
sudo ufw allow 21115/tcp
sudo ufw allow 21117/tcp
sudo ufw allow 21117/udp

# Reload firewall
sudo ufw reload
```

### Issue: Device fails to connect

```bash
# On server, check hbbs logs for registration
sudo docker logs rustdesk-hbbs | grep -i "register\|error\|connected"

# On device, check network connectivity to server
ping 192.168.1.40
telnet 192.168.1.40 21115
telnet 192.168.1.40 21117
```

### Issue: High CPU/Memory usage

```bash
# Check container resource limits
sudo docker stats --no-stream rustdesk-hbbs rustdesk-hbbr

# Reduce log verbosity if needed
# Edit docker-compose.yml and change LOG_LEVEL to "warn"
```

### Issue: Permission denied errors

```bash
# Fix ownership of data directories
sudo chown -R 1000:1000 /opt/rustdesk-platform/data

# Fix ownership of files
sudo chown cosmic:cosmic /opt/rustdesk-platform/*.yml
```

## Monitoring & Maintenance

### Daily health checks

```bash
# Create a cron job for daily health monitoring
sudo crontab -e

# Add these lines:
0 8 * * * docker ps | grep rustdesk || echo "RustDesk not running" | mail -s "RustDesk Alert" admin@domain.com
0 8 * * * docker stats --no-stream | mail -s "RustDesk Stats" admin@domain.com
```

### Log rotation

```bash
# Docker automatically rotates logs based on docker-compose.yml settings
# Logs are limited to 100MB per file, max 30 files

# To manually clear old logs
sudo docker logs --tail 1000 rustdesk-hbbs > /tmp/hbbs-latest.log
sudo docker logs --tail 1000 rustdesk-hbbr > /tmp/hbbr-latest.log
```

### Backup important data

```bash
# Backup generated keys and configuration
sudo cp -r /opt/rustdesk-platform/data/hbbs/keys /backup/rustdesk-keys-$(date +%Y%m%d).backup

# Backup entire installation
tar -czf /backup/rustdesk-platform-$(date +%Y%m%d).tar.gz /opt/rustdesk-platform/
```

## Performance Tuning

### Increase relay server capacity

```bash
# Edit .env file
MAX_RELAY_CONNECTIONS=50000  # Increase from default

# Restart services
sudo docker-compose down
sudo docker-compose up -d
```

### Optimize network settings

```bash
# Edit docker-compose.yml and add to hbbr:
environment:
  MAX_RELAY_CONNECTIONS: 50000
  CONN_DEFAULT_TIMEOUT: 300
  RELAY_THREAD_COUNT: 16
```

### Monitor network traffic

```bash
# Install iftop for real-time network monitoring
sudo apt-get install iftop

# Run to see traffic by connection
sudo iftop -n

# Monitor specific ports
sudo tcpdump -i any -n "port 21115 or port 21117"
```

## Success Criteria

✅ **Installation is successful when:**

- [ ] Docker containers are running and healthy
- [ ] All RustDesk ports (21115-21119) are listening
- [ ] Windows POS device connects without approval prompts
- [ ] Linux POS device connects without approval prompts
- [ ] Support engineer can control POS device keyboard/mouse
- [ ] File transfer works from support engineer to POS device
- [ ] Device remains connected after network interruption (auto-reconnect)
- [ ] Connection log shows "unattended" status
- [ ] No popup dialogs appear on POS device during connection

---

## Next Steps

1. **Phase 2**: Deploy to Kubernetes with HA and auto-scaling
2. **Phase 3**: Add security hardening and zero-trust access
3. **Phase 4**: Deploy PostgreSQL database and REST API
4. **Phase 5**: Add Cloudflare Tunnel and monitoring stack
5. **Phase 6**: Implement AI automation layer for device management
