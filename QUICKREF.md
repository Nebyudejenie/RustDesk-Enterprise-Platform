# RustDesk Phase 1 — Quick Reference Card

## One-Liner Deployment (on Ubuntu server)

```bash
cd /opt/rustdesk-platform && sudo bash scripts/deploy.sh deploy
```

## Essential Commands

| Command | Purpose |
|---------|---------|
| `sudo bash scripts/deploy.sh status` | Show service status |
| `sudo bash scripts/deploy.sh logs hbbs` | View hbbs logs |
| `sudo bash scripts/deploy.sh restart` | Restart services |
| `sudo bash scripts/deploy.sh verify` | Verify installation |
| `sudo docker-compose ps` | List running containers |
| `sudo ufw status verbose` | Show firewall rules |

## Port Quick Reference

| Port | Service | Protocol |
|------|---------|----------|
| 21115 | hbbs signal server | TCP |
| 21116 | hbbs connection | TCP/UDP |
| 21117 | hbbr relay ⭐ | TCP/UDP |
| 21118 | hbbs web console | TCP |
| 21119 | hbbr secondary | TCP |
| 22 | SSH | TCP |

⭐ = Most important for data transfer

## Device Installation (Copy-Paste Ready)

### Windows POS
```powershell
powershell -ExecutionPolicy Bypass -Command @"
$url = 'http://192.168.1.40:8000/installers/windows-silent-install.ps1'
Invoke-WebRequest -Uri $url -OutFile $env:TEMP\install.ps1 -UseBasicParsing
& $env:TEMP\install.ps1 -DeviceId 'POS-ADDIS-001' -RelayHost '192.168.1.40'
"@
```

### Linux POS
```bash
curl -fsSL http://192.168.1.40:8000/installers/linux-silent-install.sh | \
  bash -s "POS-LINUX-001" "192.168.1.40" "21117"
```

## Troubleshooting 5-Step Fix

### Step 1: Check containers
```bash
sudo docker-compose ps
# Should show rustdesk-hbbs and rustdesk-hbbr as "Up"
```

### Step 2: Check ports
```bash
sudo netstat -tlnup | grep -E "21115|21117"
# Should show listening ports
```

### Step 3: Check firewall
```bash
sudo ufw status verbose
# Should show Allow rules for 21115-21119
```

### Step 4: View logs
```bash
sudo docker-compose logs hbbs
sudo docker-compose logs hbbr
# Look for errors or "listening on"
```

### Step 5: Restart
```bash
sudo docker-compose restart
sleep 3
sudo docker-compose ps
```

## Critical Files

| File | Purpose | Edit? |
|------|---------|-------|
| `.env` | Configuration variables | ✏️ Yes |
| `docker-compose.yml` | Service definitions | ⚠️ Only if needed |
| `configs/RustDesk2.toml` | Client config | ✏️ Yes (for defaults) |
| `scripts/deploy.sh` | Deployment automation | ❌ No |

## Common Changes

### Change default password
```bash
# Edit .env
nano .env
# Find: RUSTDESK_PERMANENT_PASSWORD=
# Change to: RUSTDESK_PERMANENT_PASSWORD=YourNewPassword123!

# Redeploy
sudo docker-compose down
sudo docker-compose up -d
```

### Change relay server IP
```bash
# Edit .env
nano .env
# Find: RUSTDESK_RELAY_HOST=192.168.1.40
# Change to: RUSTDESK_RELAY_HOST=your-new-ip

# Update clients with new IP
```

### View real-time logs
```bash
sudo docker-compose logs -f hbbs
# Press Ctrl+C to exit
```

## Health Check

```bash
# All in one:
echo "1. Containers:" && sudo docker-compose ps && \
echo -e "\n2. Listening ports:" && sudo netstat -tlnup | grep -E "21115|21117" && \
echo -e "\n3. Recent errors:" && sudo docker-compose logs --tail=10 2>&1 | grep -i error || echo "✓ No errors"
```

## Firewall Rules

```bash
# If ports aren't open:
sudo ufw allow 21115/tcp
sudo ufw allow 21116/tcp
sudo ufw allow 21116/udp
sudo ufw allow 21117/tcp
sudo ufw allow 21117/udp
sudo ufw allow 21118/tcp
sudo ufw allow 21119/tcp
sudo ufw reload
```

## Performance Monitoring

```bash
# Live resource usage
sudo docker stats --no-stream rustdesk-hbbs rustdesk-hbbr

# Network traffic
sudo tcpdump -i any -n "port 21115 or port 21117" | head -20

# Connection count
sudo ss -tnp | grep -E "21115|21117" | wc -l
```

## Backup & Restore

```bash
# Backup everything
sudo tar -czf /backup/rustdesk-$(date +%Y%m%d).tar.gz /opt/rustdesk-platform/

# Backup keys only
sudo cp -r /opt/rustdesk-platform/data/hbbs /backup/rustdesk-hbbs-$(date +%Y%m%d)

# List backups
ls -lh /backup/rustdesk*
```

## Configuration Locations

| Item | Location |
|------|----------|
| Configuration | `/opt/rustdesk-platform/.env` |
| Client config | `/opt/rustdesk-platform/configs/RustDesk2.toml` |
| hbbs keys | `/opt/rustdesk-platform/data/hbbs/` |
| hbbr data | `/opt/rustdesk-platform/data/hbbr/` |
| Logs | `/opt/rustdesk-platform/data/*/logs/` |
| Docker compose | `/opt/rustdesk-platform/docker-compose.yml` |

## Emergency Commands

```bash
# Stop all services
sudo docker-compose down

# Start all services
sudo docker-compose up -d

# Stop single service
sudo docker-compose stop hbbs

# Restart single service
sudo docker-compose restart hbbr

# Remove all data (WARNING!)
sudo docker-compose down -v

# Clean up unused Docker resources
sudo docker system prune -a
```

## Test Connectivity

```bash
# From another machine on the network:
telnet 192.168.1.40 21115
telnet 192.168.1.40 21117

# Or with timeout:
timeout 2 bash -c 'echo >/dev/tcp/192.168.1.40/21115' && echo "Port 21115 open" || echo "Port 21115 closed"
```

## Log Location by Service

```bash
# hbbs logs
/opt/rustdesk-platform/data/hbbs/logs/

# hbbr logs
/opt/rustdesk-platform/data/hbbr/logs/

# View latest
tail -f /opt/rustdesk-platform/data/hbbs/logs/*.log
tail -f /opt/rustdesk-platform/data/hbbr/logs/*.log

# Search for errors
grep -r "ERROR\|WARN" /opt/rustdesk-platform/data/*/logs/
```

## Device Troubleshooting

### Windows POS Won't Connect
```powershell
# Check RustDesk service
Get-Service RustDesk | Select-Object Status, StartType

# Check logs
Get-Content "C:\RustDesk\install.log" | Select-Object -Last 20

# Restart service
Restart-Service RustDesk

# Check connection
netstat -ano | findstr "21117"
```

### Linux POS Won't Connect
```bash
# Check service
sudo systemctl status rustdesk

# Check logs
sudo journalctl -u rustdesk -n 20

# Restart service
sudo systemctl restart rustdesk

# Check port
sudo ss -tlnp | grep rustdesk
```

## Version Info

```bash
# Check Docker versions
docker --version
docker-compose --version

# Check RustDesk version (from container)
sudo docker exec rustdesk-hbbs rustdesk-hbbs --version || echo "Check logs"

# Check OS
lsb_release -a
uname -a
```

## Links & Resources

- RustDesk Official: https://rustdesk.com
- GitHub: https://github.com/rustdesk/rustdesk
- Docs: `docs/VERIFICATION.md` (in this repo)
- Logs: See configuration locations above

## Success Checklist ✅

- [ ] Docker containers running (`docker-compose ps`)
- [ ] All ports listening (21115-21119)
- [ ] Firewall allows RustDesk ports (`ufw status verbose`)
- [ ] Windows device connects without approval
- [ ] Linux device connects without approval
- [ ] File transfer works
- [ ] Connection duration tracked in logs
- [ ] No errors in logs

---

**Last Updated:** 2026-05-28  
**Status:** Phase 1 Complete ✅
