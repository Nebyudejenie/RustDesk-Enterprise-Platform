# RustDesk Phase 5 - Cloudflare Tunnel + Monitoring Stack

**Status:** Ready for Deployment  
**Date:** 2026-05-28  
**Version:** 1.0.0  

## Executive Summary

Phase 5 adds enterprise-grade monitoring, logging, and secure remote access to the RustDesk platform through:
- **Cloudflare Tunnel** - Zero-trust secure access without exposing IPs
- **Prometheus** - Time-series metrics collection
- **Grafana** - Rich dashboard visualization
- **Loki** - Cost-effective log aggregation
- **GitHub Actions** - Automated CI/CD deployment

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Remote Users (Internet)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                ┌────────▼─────────┐
                │ Cloudflare Tunnel│ (Zero-trust access)
                └────────┬─────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐      ┌───▼──────┐    ┌───▼───┐
   │Prometheus│      │Grafana   │    │RustDesk│
   │9090      │      │3000      │    │8000    │
   └────┬────┘      └───┬──────┘    └───┬───┘
        │                │               │
   ┌────▼────────────────▼───────────────▼────┐
   │          Loki Log Aggregator             │
   │                  3100                    │
   └──────────────────────────────────────────┘
        │
   ┌────▼──────────────────────────────────┐
   │   Docker / Kubernetes / Ubuntu Server │
   │                                       │
   │  Phase 1: hbbs/hbbr (21115-21119)    │
   │  Phase 4: FastAPI API (8000)         │
   │  Phase 5: Monitoring Stack (9090)    │
   └───────────────────────────────────────┘
```

## Phase 5 Components

### 1. Cloudflare Tunnel (Zero-Trust Access)

**What it does:**
- Creates secure tunnel to Cloudflare edge
- No need to expose ports or firewall rules
- DNS routing through Cloudflare
- Works through any network (NAT, firewalls, etc.)

**Setup:**
```bash
# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Authenticate with Cloudflare account
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create rustdesk-enterprise

# Configure routes
cloudflared tunnel route dns rustdesk-enterprise *.yourdomain.com

# Start tunnel
cloudflared tunnel run rustdesk-enterprise &

# Or as systemd service
sudo systemctl start cloudflared-rustdesk-enterprise
```

**Configuration:**
All ingress routes configured in `cloudflare/tunnel-config.yaml`:
- `rustdesk-hbbs.yourdomain.com` → TCP 21115
- `rustdesk-hbbr.yourdomain.com` → TCP 21117
- `api.yourdomain.com` → HTTP 8000 (FastAPI)
- `monitoring.yourdomain.com` → HTTP 3000 (Grafana)
- `prometheus.yourdomain.com` → HTTP 9090 (Metrics)

### 2. Prometheus (Metrics Collection)

**Metrics collected:**
- CPU, RAM, Disk, Network usage
- RustDesk API response times
- Database query performance
- Connection counts
- Docker container metrics
- Kubernetes pod metrics

**Scrape jobs:**
```yaml
- Prometheus itself (9090)
- RustDesk API (8000/metrics)
- Docker daemon (9323)
- Node Exporter (9100)
- PostgreSQL Exporter (9187)
```

**Retention:** 15 days default (configurable)

### 3. Grafana (Dashboard Visualization)

**Pre-built dashboards:**

1. **System Overview**
   - CPU usage (%)
   - Memory usage (%)
   - Disk usage (%)
   - Network traffic (Mbps)
   - Temperature sensors

2. **RustDesk API**
   - Request rate (req/sec)
   - Response time (ms)
   - Error rate (%)
   - Active connections
   - Top endpoints

3. **Database Performance**
   - Query latency (ms)
   - Connections (active/max)
   - Cache hit ratio (%)
   - Slow queries log

4. **Device Health**
   - Devices online/offline
   - Connection uptime %
   - Alert statistics
   - Device by location/branch

5. **Container Metrics**
   - Docker container CPU/Memory
   - Container restarts
   - Volume usage
   - Network I/O

**Access:**
- URL: `monitoring.yourdomain.com` (via Cloudflare Tunnel)
- Default: `http://localhost:3000`
- Credentials: `admin/admin` (change on first login)

### 4. Loki (Log Aggregation)

**What it does:**
- Centralizes logs from all services
- Queries logs alongside metrics
- Cost-efficient (label-based indexing)
- Works seamlessly with Grafana

**Log sources:**
- RustDesk API logs
- Docker container logs
- Ubuntu syslog
- Application logs
- Audit logs

**Query example:**
```
{job="rustdesk-api"} | json | status >= 500
```

### 5. GitHub Actions (CI/CD)

**Workflows:**

1. **Deploy Workflow** (on push to main)
   - SSH to server
   - Pull latest code
   - Run deploy script
   - Restart services

2. **Test Workflow** (on push/PR)
   - Install dependencies
   - Run pytest
   - Run linting
   - Check code quality

**Secrets required:**
- `DEPLOY_KEY`: SSH private key
- `DEPLOY_HOST`: user@hostname

**Setup:**
```bash
# Generate SSH key (if not exists)
ssh-keygen -t rsa -N "" -f ~/.ssh/deploy_key

# Add public key to Ubuntu server authorized_keys
cat ~/.ssh/deploy_key.pub >> ~/.ssh/authorized_keys

# Add secrets to GitHub repo settings
Settings > Secrets and variables > Actions
  - DEPLOY_KEY: (paste private key)
  - DEPLOY_HOST: cosmic@192.168.1.40
```

---

## Deployment Options

### Option 1: Docker Compose (Local/Staging)

**Prerequisites:**
- Docker and Docker Compose
- Cloudflare account
- GitHub account (for CI/CD)

**Installation:**
```bash
# Download monitoring stack
cd /opt/rustdesk-platform/phase5
docker-compose -f monitoring-stack.yml up -d

# Wait for services
sleep 30

# Verify
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health
curl http://localhost:3100/ready

# Access dashboards
echo "Grafana:    http://localhost:3000"
echo "Prometheus: http://localhost:9090"
echo "Loki:       http://localhost:3100"
```

### Option 2: Kubernetes (Production)

**Manifests:**
- Prometheus Deployment
- Grafana Deployment
- Loki Deployment
- AlertManager
- ServiceMonitor

**Installation:**
```bash
kubectl apply -f phase5/kubernetes/00-namespace.yaml
kubectl apply -f phase5/kubernetes/01-prometheus.yaml
kubectl apply -f phase5/kubernetes/02-grafana.yaml
kubectl apply -f phase5/kubernetes/03-loki.yaml

# Port forward for testing
kubectl port-forward svc/grafana 3000:80 -n monitoring
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
```

### Option 3: Hybrid (Kubernetes + Tunnel)

Deploy monitoring on Kubernetes, expose via Cloudflare Tunnel:
```bash
# Tunnel routes to Kubernetes services
- hostname: monitoring.yourdomain.com
  service: http://kubernetes-service:3000
```

---

## Configuration

### Cloudflare Tunnel Setup

**Step 1: Cloudflare Account**
1. Create account at https://dash.cloudflare.com
2. Add domain to Cloudflare
3. Update nameservers at registrar

**Step 2: Create Tunnel**
```bash
# Login (opens browser)
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create rustdesk-enterprise

# Get tunnel UUID
cloudflared tunnel list

# Update config
nano ~/.cloudflare-warp/config.yml
```

**Step 3: DNS Routing**
```bash
# Point DNS to tunnel
cloudflared tunnel route dns rustdesk-enterprise api.yourdomain.com
cloudflared tunnel route dns rustdesk-enterprise monitoring.yourdomain.com
cloudflared tunnel route dns rustdesk-enterprise prometheus.yourdomain.com
```

**Step 4: Start Tunnel**
```bash
# Foreground (testing)
cloudflared tunnel run rustdesk-enterprise

# Background with systemd
sudo systemctl start cloudflared-rustdesk-enterprise
sudo systemctl enable cloudflared-rustdesk-enterprise
```

### Grafana Setup

**First Login:**
1. Go to http://monitoring.yourdomain.com
2. Login: admin/admin
3. Change password immediately
4. Add data sources:
   - Prometheus: http://prometheus:9090
   - Loki: http://loki:3100

**Create Dashboard:**
```bash
# Import community dashboards
Home > + Create > Import
- Node Exporter: 1860
- Docker: 893
- PostgreSQL: 9628
```

### GitHub Actions Setup

**1. Generate Deploy Key**
```bash
ssh-keygen -t ed25519 -f deploy_key -N ""
```

**2. Add to server**
```bash
cat deploy_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**3. Add to GitHub**
- Repo Settings > Secrets and variables > Actions
- New secret:
  - Name: `DEPLOY_KEY`
  - Value: (contents of deploy_key)
  - Name: `DEPLOY_HOST`
  - Value: `cosmic@192.168.1.40`

**4. Test workflow**
```bash
# Push to main branch
git push origin main

# Check GitHub Actions tab for workflow run
```

---

## Monitoring & Alerts

### Prometheus Alerts

Pre-configured alerts:
- CPU usage > 80%
- Memory usage > 90%
- Disk usage > 95%
- API error rate > 5%
- Database connection pool full
- Service down/unhealthy

### AlertManager

Routes alerts to:
- Email
- PagerDuty
- Slack
- Custom webhooks

**Configuration:**
```yaml
route:
  receiver: 'email'
  group_by: ['alertname', 'severity']

receivers:
  - name: 'email'
    email_configs:
      - to: 'alerts@yourdomain.com'
        from: 'prometheus@yourdomain.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@gmail.com'
        auth_password: 'app-password'
```

### Grafana Notifications

Create alerts in Grafana:
1. Dashboard > Alert > Create alert
2. Set condition (e.g., CPU > 80%)
3. Set notification channel
4. Save alert

---

## Performance Tuning

### Prometheus

```yaml
global:
  scrape_interval: 15s      # Lower for more granular data
  evaluation_interval: 15s  # Lower for faster alerts
  external_labels:
    cluster: 'production'

storage:
  tsdb:
    retention:
      time: 30d             # Longer retention = more disk
```

### Grafana

- Increase refresh rate: Dashboard > Settings > General > Refresh interval
- Adjust time range: Top right time picker
- Add caching for dashboards

### Loki

```yaml
ingester:
  chunk_idle_period: 3m     # Lower = smaller chunks
  max_chunk_age: 1h
  chunk_retain_period: 1m

limits_config:
  max_streams_per_user: 1000  # Increase if needed
```

---

## Backup & Recovery

### Backup Strategy

**What to backup:**
- Prometheus TSDB: `/var/lib/prometheus/data`
- Grafana database: `/var/lib/grafana`
- Loki chunks: `/loki/chunks`
- Cloudflare Tunnel credentials: `~/.cloudflare-warp/cert.pem`

**Backup script:**
```bash
#!/bin/bash
BACKUP_DIR="/backups/rustdesk"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup Prometheus
docker exec prometheus tar czf - /prometheus > $BACKUP_DIR/prometheus_$TIMESTAMP.tar.gz

# Backup Grafana
docker exec grafana tar czf - /var/lib/grafana > $BACKUP_DIR/grafana_$TIMESTAMP.tar.gz

# Backup Loki
docker exec loki tar czf - /loki > $BACKUP_DIR/loki_$TIMESTAMP.tar.gz

# Cleanup old backups (30 days)
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR"
```

### Recovery

```bash
# Restore Prometheus
docker cp prometheus_backup.tar.gz prometheus:/
docker exec prometheus tar xzf /prometheus_backup.tar.gz -C /

# Restart service
docker-compose restart prometheus
```

---

## Troubleshooting

### Cloudflare Tunnel Issues

```bash
# Check tunnel status
cloudflared tunnel info rustdesk-enterprise

# Check logs
cloudflared tunnel logs rustdesk-enterprise

# Verify connectivity
curl -v https://rustdesk-enterprise.cfargotunnel.com

# Re-authenticate
cloudflared tunnel login
```

### Prometheus Not Scraping

```bash
# Check targets
curl http://localhost:9090/api/v1/targets

# Check logs
docker logs prometheus | grep "error"

# Test scrape endpoint
curl http://localhost:8000/metrics
```

### Grafana Dashboard Not Loading

```bash
# Check data source
Grafana > Configuration > Data Sources > Test

# Check Prometheus connectivity
curl http://prometheus:9090/api/v1/targets

# Restart Grafana
docker-compose restart grafana
```

### GitHub Actions Deployment Failed

```bash
# Check logs
GitHub > Actions > Workflow runs > View logs

# Common issues:
1. DEPLOY_KEY not set (check Secrets)
2. SSH key permissions (chmod 600)
3. Server firewall (check port 22)
4. User not in sudoers (check sudo access)
```

---

## Security Hardening

### Cloudflare Tunnel

✅ Zero-trust access (no IP exposure)  
✅ DDoS protection built-in  
✅ TLS encryption end-to-end  
✅ Access controls and authentication  

**Enable 2FA on Cloudflare account:**
```
Cloudflare > Account > Manage Account > Security
  - Enable Two-Factor Authentication
  - Use Authenticator app
```

### Prometheus

⚠️ No authentication by default - protect with:
- Firewall rules (internal only)
- Reverse proxy (nginx with auth)
- VPN tunnel

**Example nginx proxy:**
```nginx
server {
  listen 9090;
  auth_basic "Prometheus";
  auth_basic_user_file /etc/nginx/.htpasswd;
  
  location / {
    proxy_pass http://localhost:9090;
  }
}
```

### Grafana

✅ Built-in authentication  
✅ LDAP/OAuth2 support  
✅ RBAC (role-based access control)  

**Security checklist:**
- [ ] Change default admin password
- [ ] Enable login requirement
- [ ] Set session timeout
- [ ] Audit user access logs
- [ ] Regular backup of dashboards

---

## Success Criteria

✅ Cloudflare Tunnel running  
✅ Tunnel accessible from internet  
✅ Prometheus scraping metrics  
✅ Grafana dashboards displaying data  
✅ Loki collecting logs  
✅ GitHub Actions deploying on push  
✅ Alerts configured and working  
✅ Backups automated daily  

---

## Next Steps

**After Phase 5:**
- Monitor metrics for 1 week
- Tune alert thresholds
- Create runbooks for common alerts
- Document monitoring procedures

**Phase 6 (Final):**
- AI Automation Layer
- Autonomous diagnostics
- Anomaly detection
- Predictive maintenance
- Telegram bot notifications

---

**Generated:** 2026-05-28  
**Version:** 1.0.0  
**Status:** Production Ready
