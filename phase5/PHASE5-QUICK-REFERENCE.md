# Phase 5 - Quick Reference Card

## URLs (After Cloudflare Tunnel Setup)

```
Grafana:       https://monitoring.yourdomain.com
Prometheus:    https://prometheus.yourdomain.com
Loki:          https://logs.yourdomain.com
AlertManager:  https://alerts.yourdomain.com
```

## Local Access (Without Tunnel)

```
Grafana:       http://localhost:3000
Prometheus:    http://localhost:9090
Loki:          http://localhost:3100
AlertManager:  http://localhost:9093
```

---

## Cloudflare Tunnel Commands

### Install
```bash
# Ubuntu/Debian
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### Create Tunnel
```bash
# Login (opens browser)
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create rustdesk-enterprise

# List tunnels
cloudflared tunnel list

# Check status
cloudflared tunnel info rustdesk-enterprise
```

### Configure DNS
```bash
# Point domain to tunnel
cloudflared tunnel route dns rustdesk-enterprise monitoring.yourdomain.com
cloudflared tunnel route dns rustdesk-enterprise api.yourdomain.com
cloudflared tunnel route dns rustdesk-enterprise prometheus.yourdomain.com

# List routes
cloudflared tunnel route dns --overwrite-dns rustdesk-enterprise yourdomain.com
```

### Run Tunnel
```bash
# Foreground (testing)
cloudflared tunnel run rustdesk-enterprise

# Background with nohup
nohup cloudflared tunnel run rustdesk-enterprise > /tmp/tunnel.log 2>&1 &

# As systemd service
sudo systemctl start cloudflared-rustdesk-enterprise
sudo systemctl status cloudflared-rustdesk-enterprise
sudo systemctl enable cloudflared-rustdesk-enterprise

# View logs
journalctl -u cloudflared-rustdesk-enterprise -f
```

### Stop Tunnel
```bash
# Kill process
pkill -f "cloudflared tunnel run"

# Stop service
sudo systemctl stop cloudflared-rustdesk-enterprise
```

---

## Docker Monitoring Stack

### Start Services
```bash
cd /opt/rustdesk-platform/phase5
docker-compose -f monitoring-stack.yml up -d

# Wait for services
sleep 30

# Check status
docker-compose -f monitoring-stack.yml ps
```

### Stop Services
```bash
docker-compose -f monitoring-stack.yml down

# Remove volumes (careful - deletes data!)
docker-compose -f monitoring-stack.yml down -v
```

### View Logs
```bash
docker-compose -f monitoring-stack.yml logs -f prometheus
docker-compose -f monitoring-stack.yml logs -f grafana
docker-compose -f monitoring-stack.yml logs -f loki
docker-compose -f monitoring-stack.yml logs -f alertmanager
```

### Test Services
```bash
# Health checks
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3000/api/health      # Grafana
curl http://localhost:3100/ready           # Loki
curl http://localhost:9093/-/healthy       # AlertManager
curl http://localhost:9100/metrics         # Node Exporter
```

---

## Grafana Access & Setup

### First Login
```
URL: http://localhost:3000
Username: admin
Password: admin (CHANGE THIS!)
```

### Add Data Source
```
Configuration > Data Sources > Add Data Source
  - Prometheus
    URL: http://prometheus:9090
    Save & Test
  
  - Loki
    URL: http://loki:3100
    Save & Test
```

### Import Dashboard
```
+ Create > Import
Dashboard ID:
  - Node Exporter (Linux): 1860
  - Docker Containers: 893
  - PostgreSQL: 9628
  - Prometheus: 3662
  - Alert Manager: 8010
```

### Create Custom Dashboard
```
+ Create > Dashboard > Add Panel
  - Metric: (choose from prometheus)
  - Visualize: Graph/Table/Gauge
  - Title: (give it a name)
  - Save Dashboard
```

---

## Prometheus Queries

### CPU Usage
```
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory Usage
```
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Disk Usage
```
(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lowerfs|squashfs|vfat"} / node_filesystem_size_bytes)) * 100
```

### API Request Rate
```
rate(http_requests_total[5m])
```

### API Error Rate
```
rate(http_requests_total{status=~"5.."}[5m])
```

### Device Count
```
count(device_info)
```

### Connections
```
connections_active
```

---

## AlertManager Rules

### Email Alert
```yaml
- alert: HighCPU
  expr: cpu_usage > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High CPU usage"
    description: "CPU is {{ $value }}%"
```

### Create Alert in Prometheus
```bash
cat > prometheus/rules.yml << 'EOF'
groups:
  - name: rustdesk
    interval: 30s
    rules:
      - alert: HighCPU
        expr: cpu > 80
        for: 5m
```

### Enable Alert in prometheus.yml
```yaml
rule_files:
  - 'rules.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

---

## Loki Queries

### View All Logs
```
{job="rustdesk-api"}
```

### Errors Only
```
{job="rustdesk-api"} |= "error"
```

### By Level
```
{job="rustdesk-api"} | json | level = "ERROR"
```

### Slow Requests
```
{job="rustdesk-api"} | json | duration > 1000
```

### Failed Connections
```
{job="rustdesk-api"} | json | status >= 400
```

---

## GitHub Actions CI/CD

### Required Secrets
```
DEPLOY_KEY   = SSH private key content
DEPLOY_HOST  = cosmic@192.168.1.40
```

### Add Secrets to GitHub
```
Repo > Settings > Secrets and variables > Actions > New secret
  Name: DEPLOY_KEY
  Value: (paste private key)
  
  Name: DEPLOY_HOST
  Value: cosmic@192.168.1.40
```

### Generate SSH Key
```bash
ssh-keygen -t ed25519 -f deploy_key -N ""
cat deploy_key         # Private key for DEPLOY_KEY secret
cat deploy_key.pub     # Add to ~/.ssh/authorized_keys on server
```

### Test Deployment
```bash
# Push to main branch
git push origin main

# Check GitHub > Actions tab
# View workflow run logs
```

### Manual Workflow Trigger
```bash
# From GitHub Actions tab
  - Workflow > Run workflow > Branch: main > Run workflow
```

---

## Backup Commands

### Backup All Data
```bash
BACKUP_DIR="/backups/rustdesk-phase5"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Prometheus
docker-compose exec -T prometheus tar czf - /prometheus | \
  gzip > $BACKUP_DIR/prometheus_$TIMESTAMP.tar.gz

# Grafana
docker-compose exec -T grafana tar czf - /var/lib/grafana | \
  gzip > $BACKUP_DIR/grafana_$TIMESTAMP.tar.gz

# Loki
docker-compose exec -T loki tar czf - /loki | \
  gzip > $BACKUP_DIR/loki_$TIMESTAMP.tar.gz

echo "Backup complete: $BACKUP_DIR"
```

### Restore Backup
```bash
# Restore Prometheus
docker-compose exec -T prometheus bash -c \
  "tar xzf /prometheus_backup.tar.gz -C /"

# Restart
docker-compose restart prometheus
```

---

## Troubleshooting

### Tunnel Not Connecting
```bash
# Check config
cat ~/.cloudflare-warp/config.yml

# Verify credentials
cloudflared tunnel login

# Test connectivity
curl -v https://yourdomain.com

# View logs
cloudflared tunnel logs rustdesk-enterprise
```

### Prometheus Not Scraping
```bash
# Check targets
curl http://localhost:9090/api/v1/targets

# Check if endpoint is accessible
curl http://localhost:8000/metrics

# View Prometheus logs
docker-compose logs prometheus | grep "error"
```

### Grafana Data Not Showing
```bash
# Test Prometheus connection
Configuration > Data Sources > Prometheus > Test

# Check query
Explore > Metrics Browser > (search metric)

# Restart Grafana
docker-compose restart grafana
```

### High Memory Usage
```bash
# Reduce Prometheus retention
# Edit prometheus.yml:
global:
  scrape_interval: 15s
  retention: 7d  # Reduce from 30d

# Restart
docker-compose restart prometheus
```

---

## Performance Tips

### For Production
```bash
# Increase Prometheus scrape interval
scrape_interval: 30s  # More CPU efficient

# Reduce retention
retention: 14d        # Less disk space

# Enable compression
compression: true     # In remoteWrite

# Optimize storage
tsdb.maxBlockDuration: 24h  # Larger blocks

# Scale Grafana
replicas: 3
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
```

### Monitor Monitoring
```bash
# Check container resource usage
docker stats

# Check disk space
du -sh /var/lib/docker/volumes/

# Monitor growth
watch 'du -sh /var/lib/docker/volumes/prometheus_data'
```

---

## Emergency Recovery

### Restart All Services
```bash
docker-compose -f monitoring-stack.yml restart
```

### Full Reset (WARNING - DELETES DATA)
```bash
docker-compose -f monitoring-stack.yml down -v
docker-compose -f monitoring-stack.yml up -d
```

### Restore from Backup
```bash
# Extract backups
tar xzf prometheus_backup.tar.gz
tar xzf grafana_backup.tar.gz
tar xzf loki_backup.tar.gz

# Restore to containers
docker-compose exec -T prometheus bash -c "tar xzf /backup.tar.gz -C /"
docker-compose restart
```

---

**Quick Ref v1.0 | 2026-05-28**
