# RustDesk Enterprise Platform - Phase 1 MVP

**Production-grade, 100% working self-hosted RustDesk remote access platform for enterprise POS device management**

## Overview

This project delivers a complete Phase 1 foundation for a self-hosted RustDesk enterprise platform designed for Ethiopian retail environments with POS devices running Windows 10/11 or Linux.

### Key Features

✅ **Zero-confirmation unattended access** — Support engineers type device ID and connect instantly (no approval popups)  
✅ **Docker-based deployment** — hbbs (signal) + hbbr (relay) with persistent volumes and health checks  
✅ **Silent device installers** — Windows PowerShell & Linux Bash scripts for automated deployment  
✅ **Firewall automation** — UFW configuration for all RustDesk ports  
✅ **Production-ready logging** — JSON structured logs with rotation (100MB per file, 30 file retention)  
✅ **Automated deployment** — One-command deployment script with verification and monitoring  
✅ **Enterprise security** — Permanent passwords, encrypted connections, custom server configuration  

## Project Structure

```
rustdisk/
├── docker-compose.yml              # Complete Docker Compose setup (hbbs + hbbr)
├── .env                            # Environment variables and configuration
├── configs/
│   └── RustDesk2.toml             # Pre-configured client configuration (unattended access)
├── installers/
│   ├── windows-silent-install.ps1 # Windows POS silent installer (PowerShell)
│   └── linux-silent-install.sh    # Linux POS silent installer (Bash)
├── scripts/
│   ├── deploy.sh                  # Automated deployment and management script
│   └── configure-firewall.sh      # UFW firewall configuration script
├── data/                          # Volume mount directories (created at runtime)
│   ├── hbbs/                      # hbbs persistent storage (keys, config, logs)
│   ├── hbbr/                      # hbbr persistent storage (keys, config, logs)
│   └── postgres/                  # Future Phase 4 PostgreSQL data
├── docs/
│   ├── VERIFICATION.md            # Detailed verification and testing guide
│   └── TROUBLESHOOTING.md         # Troubleshooting and debugging
└── kubernetes/                     # (Phase 2) Kubernetes manifests
```

## Quick Start

### 1. Prerequisites

- Ubuntu 24.04 LTS VM with SSH access
- Docker and Docker Compose installed
- 2GB+ RAM available
- 10GB+ disk space
- Network access to all POS devices

### 2. Deploy to Ubuntu Server

```bash
# From your local machine, copy files to server
rsync -avz --delete ./ cosmic@192.168.1.40:/opt/rustdesk-platform/

# SSH into the server
ssh cosmic@192.168.1.40

# Navigate to project directory
cd /opt/rustdesk-platform

# Run automated deployment (requires sudo)
sudo bash scripts/deploy.sh deploy

# Verify installation
sudo bash scripts/deploy.sh verify
```

### 3. Deploy to POS Devices

**Windows POS (PowerShell as Administrator):**
```powershell
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

**Linux POS (Bash as root):**
```bash
curl -fsSL http://192.168.1.40:8000/installers/linux-silent-install.sh | \
  bash -s "POS-LINUX-001" "192.168.1.40" "21117"
```

### 4. Test Unattended Access

1. Download RustDesk client: https://rustdesk.com/download
2. Enter device ID (e.g., `POS-ADDIS-001`)
3. Click Connect
4. **Expected behavior:** Connection established immediately with NO approval prompts on POS device

## Configuration Files

### .env — Environment Variables
```bash
RUSTDESK_RELAY_HOST=192.168.1.40          # Server IP
RUSTDESK_PERMANENT_PASSWORD=POS@Ent...    # Default password (CHANGE THIS!)
RELAY_SECRET_KEY=your-relay-secret-key    # Change for production
POSTGRES_PASSWORD=RustDesk@Postgres...    # Database password (Phase 4)
```

### RustDesk2.toml — Client Configuration
Pre-configured with:
- `approve_without_consent = true` — Auto-accept connections
- `ask_on_new_connection = false` — No approval dialogs
- `accept_all_connections = true` — No user confirmation
- `lock_screen_on_disconnect = false` — Device unlocks after disconnect
- Permanent password enabled
- Encrypted connections only
- Auto-reconnect on network failure

### docker-compose.yml — Service Definitions
- **hbbs** (Signal Server): Listens on 21115-21118 TCP, 21116 UDP
- **hbbr** (Relay Server): Listens on 21117 TCP/UDP, 21119 TCP
- Health checks on both services with automatic restart
- Persistent volumes for generated keys and logs
- JSON logging with 100MB rotation, 30 file retention

## Deployment Management

### View Status
```bash
sudo bash scripts/deploy.sh status
```

### Restart Services
```bash
sudo bash scripts/deploy.sh restart
```

### View Logs
```bash
sudo bash scripts/deploy.sh logs          # All logs
sudo bash scripts/deploy.sh logs hbbs     # hbbs only
sudo bash scripts/deploy.sh logs hbbr     # hbbr only
```

### Backup Configuration
```bash
sudo bash scripts/deploy.sh backup
```

### Verify Installation
```bash
sudo bash scripts/deploy.sh verify
```

## RustDesk Port Mapping

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 21115 | TCP | hbbs | Signal server (device registration) |
| 21116 | TCP/UDP | hbbs | Connection relay |
| 21117 | TCP/UDP | hbbr | Main relay (data transfer) |
| 21118 | TCP | hbbs | Web console |
| 21119 | TCP | hbbr | Secondary relay |

### Firewall Rules (UFW)
```bash
sudo ufw allow 21115/tcp    # Signal server
sudo ufw allow 21116/tcp    # Connection relay
sudo ufw allow 21116/udp    # Connection relay
sudo ufw allow 21117/tcp    # Main relay
sudo ufw allow 21117/udp    # Main relay
sudo ufw allow 21118/tcp    # Web console
sudo ufw allow 21119/tcp    # Secondary relay
sudo ufw allow 22/tcp       # SSH
sudo ufw allow 80/tcp       # HTTP (future)
sudo ufw allow 443/tcp      # HTTPS (future)
```

## Installer Scripts

### windows-silent-install.ps1
**Features:**
- Downloads and installs RustDesk MSI silently
- Injects RustDesk2.toml configuration
- Registers device with custom ID (e.g., POS-ADDIS-001)
- Configures Windows Firewall
- Installs as system service with auto-start
- Creates installation log at `C:\RustDesk\install.log`
- Self-deletes after completion

**Usage:**
```powershell
powershell -ExecutionPolicy Bypass -File windows-silent-install.ps1 `
    -DeviceId "POS-ADDIS-001" `
    -RelayHost "192.168.1.40" `
    -RelayPort 21117 `
    -SignalServer "192.168.1.40:21115" `
    -PermanentPassword "YourPassword"
```

### linux-silent-install.sh
**Features:**
- Detects and installs package dependencies
- Downloads RustDesk binary (x86_64 or aarch64)
- Creates systemd service unit
- Creates rustdesk system user with minimal privileges
- Configures UFW firewall
- Enables auto-start on boot
- Registers device information at `/etc/rustdesk/device.info`
- Self-deletes after completion

**Usage:**
```bash
sudo bash linux-silent-install.sh "POS-LINUX-001" "192.168.1.40" "21117"
```

## Verification & Testing

**See detailed verification guide:** [`docs/VERIFICATION.md`](docs/VERIFICATION.md)

### Quick Verification
```bash
# Check if services are running
sudo docker-compose ps

# Check if ports are listening
sudo netstat -tlnup | grep -E "21115|21116|21117"

# View service logs
sudo docker-compose logs -f hbbs

# Test device connection (from another machine)
telnet 192.168.1.40 21115
```

### Test Unattended Access
1. Install RustDesk on a POS device
2. Open RustDesk client on support engineer's machine
3. Enter device ID: `POS-ADDIS-001`
4. Click "Connect"
5. Verify: NO approval dialog appears on POS device
6. Connection should be established immediately

## Security Considerations

⚠️ **BEFORE PRODUCTION DEPLOYMENT:**

1. **Change default password:**
   ```bash
   # Edit .env file
   RUSTDESK_PERMANENT_PASSWORD=YourStrong@Password2024!
   
   # Redeploy
   sudo docker-compose down
   sudo docker-compose up -d
   ```

2. **Change relay secret key:**
   ```bash
   RELAY_SECRET_KEY=$(openssl rand -hex 32)
   ```

3. **Enable SSH key-only authentication**
4. **Configure IP allowlist if possible**
5. **Monitor logs regularly**
6. **Implement firewall IP restrictions for support engineers**

## Troubleshooting

### Containers not starting
```bash
# Check Docker daemon
sudo systemctl status docker

# View detailed logs
sudo docker-compose logs hbbs
sudo docker-compose logs hbbr

# Restart Docker
sudo systemctl restart docker
sudo docker-compose up -d
```

### Ports not listening
```bash
# Check UFW firewall
sudo ufw status verbose

# Check if containers are running
sudo docker-compose ps

# Reload firewall
sudo ufw reload
```

### Device fails to connect
```bash
# Test network connectivity from device
ping 192.168.1.40
telnet 192.168.1.40 21115

# Check server logs for registration
sudo docker logs rustdesk-hbbs | grep -i "register\|connected"
```

**Full troubleshooting guide:** See `docs/TROUBLESHOOTING.md` (coming in Phase 2)

## Monitoring

### Check resource usage
```bash
sudo docker stats --no-stream rustdesk-hbbs rustdesk-hbbr
```

### View real-time logs
```bash
sudo docker-compose logs -f
```

### Monitor network connections
```bash
sudo tcpdump -i any -n "port 21115 or port 21117"
```

## Backing Up Configuration

```bash
# Backup keys and configuration
sudo bash scripts/deploy.sh backup

# Manual backup
tar -czf rustdesk-backup-$(date +%Y%m%d).tar.gz /opt/rustdesk-platform/data/
```

## Environment Settings

All configuration is managed through `.env` file:

```bash
# Server addresses
RUSTDESK_RELAY_HOST=192.168.1.40
RUSTDESK_SIGNAL_SERVER=192.168.1.40:21115
RUSTDESK_RELAY_SERVER=192.168.1.40:21117

# Unattended access settings
RUSTDESK_PERMANENT_PASSWORD=POS@Enterprise2024!Secure
DISABLE_APPROVAL_PROMPTS=true
DISABLE_PERMISSION_DIALOGS=true
AUTO_ACCEPT_CONNECTIONS=true

# Security
RELAY_SECRET_KEY=your-relay-secret-key-change-this-in-production

# Logging
LOG_LEVEL=info
LOG_ROTATION_SIZE=100M
LOG_RETENTION_DAYS=30
```

## What's Included in Phase 1

✅ Docker Compose setup with hbbs and hbbr  
✅ RustDesk2.toml pre-configured for unattended access  
✅ Windows silent installer (PowerShell)  
✅ Linux silent installer (Bash)  
✅ UFW firewall configuration  
✅ Automated deployment script  
✅ Health checks and auto-restart  
✅ JSON structured logging with rotation  
✅ Verification checklist  

## What's Coming in Future Phases

**Phase 2 — Kubernetes Production Deployment**
- Kubernetes manifests (Deployment, Service, PVC, HPA)
- MetalLB for load balancing
- Helm chart for parameterized deployment
- AKS migration path

**Phase 3 — Security Hardening**
- OS hardening (CIS Benchmark)
- RBAC and access control
- Network policies
- Compliance (PCI-DSS for POS)

**Phase 4 — PostgreSQL + REST API**
- FastAPI backend
- PostgreSQL database
- Device registry and audit logs
- Heartbeat monitoring

**Phase 5 — Cloudflare Tunnel + Monitoring**
- Cloudflare Tunnel integration
- Prometheus + Grafana monitoring
- Loki logging stack
- CI/CD pipeline (GitHub Actions)

**Phase 6 — AI Automation**
- Autonomous device diagnostics
- Anomaly detection
- Predictive maintenance
- Natural language dashboard queries
- Telegram bot notifications

## Support & Troubleshooting

For detailed troubleshooting, see:
- **Deployment Guide:** [`docs/VERIFICATION.md`](docs/VERIFICATION.md)
- **Port Configuration:** See `docker-compose.yml` port mappings
- **Logs:** Check `/opt/rustdesk-platform/data/*/logs/`

## License & Attribution

RustDesk: https://github.com/rustdesk/rustdesk  
Deployment: Production-grade configuration for Ethiopian enterprise POS environments

---

**Status:** ✅ Phase 1 Complete (MVP Docker Core)  
**Last Updated:** 2026-05-28  
**Tested on:** Ubuntu 24.04 LTS, Docker 24.0+, Docker Compose 2.20+  
