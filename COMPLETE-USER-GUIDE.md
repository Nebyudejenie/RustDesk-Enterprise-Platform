# 📖 RustDesk Enterprise Platform - Complete User Guide

**Version:** 1.0.0  
**Date:** 2026-05-28  
**Status:** Production Ready  

---

## Table of Contents

1. [System Overview](#system-overview)
2. [How It Works](#how-it-works)
3. [Quick Start](#quick-start)
4. [Setup Android Devices](#setup-android-devices)
5. [Instant Access](#instant-access)
6. [Monitoring Dashboard](#monitoring-dashboard)
7. [Managing Devices](#managing-devices)
8. [Alerts & Auto-Fix](#alerts--auto-fix)
9. [Troubleshooting](#troubleshooting)

---

## System Overview

### What is RustDesk Enterprise?

RustDesk Enterprise is a **complete remote access and device management platform** with:

```
┌─────────────────────────────────────────────────────────┐
│          Your Devices (Windows/Linux/Android)           │
│        Running RustDesk Agent (automatic access)        │
└────────────────────┬────────────────────────────────────┘
                     │
                ┌────▼─────────────────────────┐
                │   Cloud/VPN Connection       │
                │  (Secure encrypted tunnel)   │
                └────┬────────────────────────┬┘
                     │                        │
        ┌────────────▼──────┐        ┌───────▼──────────┐
        │  Signal Server    │        │  Relay Server    │
        │  (Port 21115)     │        │  (Port 21117)    │
        │  Coordinates      │        │  Routes traffic  │
        │  connections      │        │  between devices │
        └────────┬──────────┘        └────────┬─────────┘
                 │                            │
        ┌────────▼────────────────────────────▼──────────┐
        │           REST API Backend (Port 8000)          │
        │  Device Management • User Auth • Logging        │
        │         PostgreSQL Database                     │
        └────────────────┬─────────────────────────────────┘
                         │
        ┌────────────────▼──────────────────────────┐
        │   Real-Time Monitoring & Alerts           │
        │  Prometheus (9090) | Grafana (3000)      │
        │  Loki (3100) | AlertManager (9093)       │
        └────────────────┬──────────────────────────┘
                         │
        ┌────────────────▼──────────────────────────┐
        │      AI Automation Layer                  │
        │  Anomaly Detection | Auto-Fix | Telegram │
        └───────────────────────────────────────────┘
```

### System Layers

| Layer | Component | Purpose |
|-------|-----------|---------|
| **1. Devices** | Android/Windows/Linux | Monitored and controlled |
| **2. Access** | hbbs/hbbr servers | Secure remote access |
| **3. Management** | REST API | Device & user management |
| **4. Monitoring** | Prometheus/Grafana | Real-time dashboards |
| **5. Intelligence** | AI Service | Anomaly detection & auto-fix |

---

## How It Works

### 1. Device Registration & Connection

**Step 1: Device Agent Installation**
```
Device (Android/Windows/Linux)
    ↓
Install RustDesk Agent
    ↓
Agent connects to hbbs Signal Server (21115)
    ↓
Device gets unique ID (e.g., "POS-ADDIS-001")
    ↓
Agent registers in database
    ↓
Device appears in Grafana dashboard
```

**Step 2: Secure Connection**
```
Support Engineer (You)
    ↓
Login to API (Port 8000) with credentials
    ↓
Get list of available devices
    ↓
Select device to access
    ↓
Signal Server coordinates connection
    ↓
Relay Server routes traffic
    ↓
Encrypted session established
    ↓
Remote control active!
```

### 2. Real-Time Monitoring

**Metrics Collection:**
```
Device sends heartbeat every 60 seconds
    ↓
CPU, RAM, Disk, Network, Temperature
    ↓
Prometheus scrapes metrics
    ↓
Grafana displays in dashboards
    ↓
AI analyzes for anomalies
    ↓
Alerts sent if issues detected
```

### 3. Intelligent Alert System

```
Device metric goes abnormal
    ↓
AI Anomaly Detector identifies pattern
    ↓
Predictive Maintenance checks for failures
    ↓
Autonomous Diagnostics finds root cause
    ↓
Auto-Remediation attempts automatic fix
    ↓
Telegram sends alert to your phone
    ↓
Dashboard shows remediation result
```

---

## Quick Start

### Accessing Your System

**On your PC/laptop:**

```bash
# 1. Open browser
http://192.168.1.40:3000          # Grafana Dashboards
http://192.168.1.40:8000/docs     # API Documentation
http://192.168.1.40:9090          # Prometheus Metrics
```

**Credentials:**
```
Grafana:   admin / admin
API:       engineer@yourdomain.com / your_password
```

### First Time Setup

**5-minute quick start:**

```bash
# 1. SSH into Ubuntu server
ssh cosmic@192.168.1.40

# 2. Check services running
docker ps                          # See all containers
systemctl status rustdesk-api     # Check API
ps aux | grep python3             # Check Phase 6

# 3. Access Grafana
# Open: http://192.168.1.40:3000
# Login: admin/admin
# Change password on first login

# 4. Register first device
# Continue reading below...
```

---

## Setup Android Devices

### Step-by-Step Android Setup

#### Option 1: Download & Configure (Easiest)

**Step 1: Download RustDesk Android App**

```
1. Open Google Play Store on Android device
2. Search for "RustDesk"
3. Install app by RustDesk
4. Open app
```

**Step 2: Configure Connection**

```
In RustDesk Android app:

1. Tap "Settings" (⚙️)
2. Tap "Network"
3. Set Custom Relay Server:
   - IP: 192.168.1.40 (your Ubuntu server)
   - Port: 21117
4. Set Signal Server:
   - IP: 192.168.1.40
   - Port: 21115
5. Set Permanent Password:
   - (from RustDesk2.toml on server)
   - Default: "rustdesk"
6. Tap "Save"
7. App will show Device ID
```

**Step 3: Register Device**

```
Device ID appears as: "XXXXXXXXX" (random 9-digit number)

1. SSH into Ubuntu server:
   ssh cosmic@192.168.1.40

2. Register device via API:
   curl -X POST http://localhost:8000/api/v1/devices \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "device_id": "POS-ANDROID-001",
       "device_type": "Android",
       "rustdesk_id": "XXXXXXXXX",
       "os_version": "Android 13",
       "permanent_password": "rustdesk",
       "hostname": "Android-Device-Name"
     }'

3. Or use Grafana UI:
   - Go to Dashboard > Add Device
   - Enter device info
```

**Step 4: Verify Connection**

```
In Grafana (http://192.168.1.40:3000):

1. Go to Devices dashboard
2. Look for "POS-ANDROID-001"
3. Check status: 🟢 Online
4. Check last seen: Should be recent
```

#### Option 2: Silent Installation Script (For POS Terminals)

**For unattended Android deployment:**

```bash
# SSH into Android device (if possible) or use ADB:

adb shell "am start -n com.rustdesk.rustdesk/.MainActivity \
  --es custom_server 192.168.1.40:21117 \
  --es custom_signal 192.168.1.40:21115 \
  --es permanent_pwd rustdesk"
```

### Android Device Monitoring

**What gets monitored on Android:**

```
CPU Usage          → Real-time CPU load
RAM Usage          → Memory consumption
Battery Level      → Battery percentage
Temperature        → Device temperature
Network Signal     → WiFi/Mobile signal strength
App Usage          → Running processes
Storage            → Internal storage usage
Last Seen          → Last connection time
Status             → Online/Offline
```

**View in Grafana:**

```
1. Go to: Dashboards > Device Health
2. Select your Android device
3. See real-time metrics
4. View alerts if any issues
```

---

## Instant Access

### How to Access Android Device Instantly

#### Method 1: Direct Connection (Fastest)

**From Browser:**

```
1. Go to Grafana: http://192.168.1.40:3000
2. Dashboard > Devices
3. Find "POS-ANDROID-001"
4. Click device name
5. Click "Connect" button
6. Choose connection type:
   - Remote Control (mouse/keyboard)
   - File Transfer
   - Clipboard Sharing
```

#### Method 2: API Call

**Via Command Line:**

```bash
# Get device list
curl -X GET http://localhost:8000/api/v1/devices \
  -H "Authorization: Bearer YOUR_TOKEN"

# Start connection
curl -X POST http://localhost:8000/api/v1/connections/start \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "device_id": 1,
    "source_ip": "192.168.1.100",
    "session_key": "auto"
  }'

# Response includes connection_id and session info
```

#### Method 3: Telegram Bot (Fastest Mobile Access)

**On your phone:**

```
1. Open Telegram
2. Find your RustDesk bot
3. Send: /devices
4. Bot lists all online devices
5. Send: /connect_POS-ANDROID-001
6. Bot establishes connection
7. Access session link appears
```

### Connection Types

#### 1. Remote Control (Full Screen)

```
What you can do:
✅ See device screen in real-time
✅ Control with mouse/keyboard
✅ Navigate Android menus
✅ Tap buttons & icons
✅ Open/close apps
✅ View all data

Use for:
- Troubleshooting issues
- Installing apps
- Changing settings
- Testing features
```

#### 2. File Transfer

```
What you can do:
✅ Upload files to device
✅ Download files from device
✅ Manage directories
✅ Backup data
✅ Restore configurations

Use for:
- Push updates
- Backup POS data
- Restore settings
- Transfer documents
```

#### 3. Clipboard Sharing

```
What you can do:
✅ Share text between device and PC
✅ Copy passwords securely
✅ Share URLs
✅ Paste commands

Use for:
- Quick data sharing
- Configuration values
- Account details
```

### Access Speed Optimization

**For instant access:**

```bash
# 1. Use local network (faster than internet)
# 2. Keep relay server on same network
# 3. Use wired connection for Ubuntu server
# 4. Enable hardware acceleration in RustDesk settings

# Typical connection times:
Local Network:     < 1 second
Same City:         1-3 seconds
Different Region:  3-5 seconds
International:     5-10 seconds
```

---

## Monitoring Dashboard

### Grafana Dashboards Overview

**Access:** http://192.168.1.40:3000

**Default Login:** admin/admin

### Dashboard 1: Device Overview

```
Shows:
├── Total Devices: 150
├── Online Devices: 145 (96.7%)
├── Offline Devices: 5
├── Status Indicator:
│   ├── 🟢 Green = Online
│   ├── 🟡 Yellow = Degraded
│   └── 🔴 Red = Offline
└── Last Updated: Real-time
```

### Dashboard 2: Device Health

```
For each device:
├── CPU Usage: 45% (graph)
├── RAM Usage: 68% (gauge)
├── Disk Usage: 72% (bar)
├── Temperature: 52°C (gauge)
├── Network Signal: Excellent
├── Battery Level: 85%
├── Last Seen: 2 minutes ago
└── Health Status: Healthy
```

### Dashboard 3: Real-Time Alerts

```
Alerts show:
├── Alert Type
│   ├── 🔴 CRITICAL (CPU > 90%)
│   ├── 🟠 HIGH (Memory leak)
│   ├── 🟡 MEDIUM (Disk > 80%)
│   └── 🟢 INFO (Device registered)
├── Device Affected
├── Triggered Time
├── Severity Level
├── Auto-Remediation Status
└── Manual Actions Available
```

### Dashboard 4: Connection Activity

```
Shows:
├── Active Connections: 12
├── Total Today: 156
├── Busiest Hour: 10 AM
├── Connection Types:
│   ├── Remote Control: 120
│   ├── File Transfer: 30
│   └── Monitoring: 6
├── Top Connected Devices:
│   ├── 1. POS-ADDIS-001 (45 connections)
│   ├── 2. POS-DIRE-001 (38 connections)
│   └── 3. POS-HAWASSA-001 (23 connections)
└── Geographic Distribution: [Map]
```

### Dashboard 5: Performance Trends

```
Shows 24-hour trends:
├── CPU Average: 42%
├── Memory Average: 65%
├── Disk Growth: +5GB/day
├── Network Traffic: 500 MB/day
├── Peak Hours: 9-11 AM, 3-5 PM
├── Slowest Device: POS-DIRE-005
└── Most Reliable: POS-ADDIS-002
```

### Custom Dashboard Creation

**Create your own dashboard:**

```
1. Click "+" in sidebar
2. Select "Dashboard"
3. Click "Add panel"
4. Choose visualization type:
   - Graph (line chart)
   - Gauge (speedometer)
   - Table (data table)
   - Bar chart
   - Stat (single number)
5. Select metrics from Prometheus
6. Configure colors, thresholds
7. Save dashboard
8. Share with team
```

---

## Managing Devices

### Add New Device

**Via API:**

```bash
curl -X POST http://localhost:8000/api/v1/devices \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "POS-BRANCH-001",
    "branch_id": 1,
    "device_type": "POS Terminal",
    "os_version": "Android 13",
    "permanent_password": "YourPassword123!!",
    "hostname": "Branch-POS-01"
  }'
```

**Via Grafana UI:**

```
1. Dashboard > Devices
2. Click "Add Device"
3. Fill in:
   - Device ID: POS-BRANCH-001
   - Device Type: POS Terminal
   - OS Version: Android 13
   - Password: Set permanent password
4. Click "Register"
5. Device appears in list
6. Shows "Offline" until agent connects
```

### Monitor Device Health

**Check device status:**

```bash
curl -X GET http://localhost:8000/api/v1/devices/POS-ANDROID-001 \
  -H "Authorization: Bearer $TOKEN"

Response includes:
{
  "device_id": "POS-ANDROID-001",
  "status": "online",
  "ip_address": "192.168.1.100",
  "last_seen_at": "2026-05-28T17:45:30",
  "cpu_percent": 45.2,
  "ram_percent": 68.5,
  "disk_percent": 72.1,
  "temperature": 52.3,
  "is_active": true
}
```

### Update Device Settings

```bash
curl -X PATCH http://localhost:8000/api/v1/devices/POS-ANDROID-001 \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "status": "maintenance",
    "maintenance_mode": true,
    "tags": {
      "location": "branch-1",
      "support_level": "high-priority"
    }
  }'
```

### Deactivate Device

```bash
curl -X DELETE http://localhost:8000/api/v1/devices/POS-ANDROID-001 \
  -H "Authorization: Bearer $TOKEN"

# Device marked inactive
# No longer shown in active list
# Historical data preserved
```

---

## Alerts & Auto-Fix

### Alert Types

#### 1. CPU Spike (🟠 High)

```
Trigger: CPU > 80% for 5 minutes
Message: "CPU usage spiked to 95%"
Auto-Fix: 
  1. Identify runaway process
  2. Terminate if safe
  3. Monitor CPU after fix
Notification: Telegram + Dashboard
```

#### 2. Memory Leak (🟠 High)

```
Trigger: RAM > 85% consistently
Message: "Memory usage trending up"
Auto-Fix:
  1. Clear cache
  2. Restart high-memory apps
  3. If still high, restart device
Notification: Telegram + Dashboard
```

#### 3. Disk Full (🔴 Critical)

```
Trigger: Disk > 95%
Message: "Disk space critical"
Auto-Fix:
  1. Delete old logs
  2. Clear temporary files
  3. Archive old backups
Notification: Telegram + Dashboard (URGENT)
```

#### 4. Device Offline (🔴 Critical)

```
Trigger: No heartbeat for 5 minutes
Message: "Device offline"
Auto-Fix: 
  1. Attempt automatic restart
  2. Alert support engineer
  3. Escalate if offline > 30 mins
Notification: Telegram + Dashboard
```

#### 5. High Temperature (🟠 High)

```
Trigger: Temperature > 80°C
Message: "Device overheating"
Auto-Fix:
  1. Reduce workload
  2. Stop non-essential processes
  3. Enable cooling
Notification: Telegram + Dashboard
```

### Receiving Alerts

#### Via Telegram

```
Setup:
1. Message @BotFather on Telegram
2. Create bot: /newbot
3. Copy token
4. Message @userinfobot
5. Get your Chat ID
6. Export on server:
   export TELEGRAM_BOT_TOKEN='token'
   export TELEGRAM_CHAT_ID='id'
7. Start bot: python3 telegram_bot.py

Alert format:
🔴 RustDesk Alert
Device: POS-ANDROID-001
Severity: CRITICAL
Time: 2026-05-28 17:45:00 UTC

Message: Disk usage critical at 97%
Recommendation: Clear old files immediately

[Acknowledge] [Remediate] [Details]
```

#### Via Dashboard

```
1. Open Grafana: http://192.168.1.40:3000
2. Go to: Dashboards > Real-Time Alerts
3. See all active alerts
4. Click alert for details
5. View remediation status
6. Manually execute fix if needed
```

### Manual Alert Actions

**Acknowledge Alert:**

```bash
curl -X POST http://localhost:8000/api/v1/alerts/{alert_id}/acknowledge \
  -H "Authorization: Bearer $TOKEN"

# Alert marked as acknowledged
# Still showing but less urgent
```

**Resolve Alert:**

```bash
curl -X POST http://localhost:8000/api/v1/alerts/{alert_id}/resolve \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "resolved": true,
    "resolution_notes": "Cleared log files, freed 5GB"
  }'

# Alert closed
# Remediation details saved
# Historical record preserved
```

---

## Troubleshooting

### Android Device Not Appearing

**Problem:** Device registered but not showing in dashboard

**Solution:**

```bash
# 1. Check device registration
curl -X GET http://localhost:8000/api/v1/devices \
  -H "Authorization: Bearer $TOKEN" | grep POS-ANDROID-001

# 2. Verify RustDesk agent running on device
adb shell ps | grep rustdesk

# 3. Check network connectivity
adb shell ping 192.168.1.40

# 4. Verify server is listening
ssh cosmic@192.168.1.40 'ss -tlnup | grep 21115'

# 5. Restart agent on device
adb shell am force-stop com.rustdesk.rustdesk
adb shell am start com.rustdesk.rustdesk
```

### Connection Timeout

**Problem:** Can't connect to device (timeout error)

**Solution:**

```
1. Check device is online:
   - Dashboard should show 🟢 Online
   - Last seen < 1 minute

2. Check firewall:
   - Port 21115 open? ssh test
   - Port 21117 open? telnet test

3. Check network:
   - Device on same network?
   - WiFi connected?
   - Signal strong?

4. Restart services:
   ssh cosmic@192.168.1.40
   docker restart rustdesk-hbbs rustdesk-hbbr

5. Check logs:
   docker logs rustdesk-hbbs | tail -50
```

### Alerts Not Sending to Telegram

**Problem:** No notifications received

**Solution:**

```bash
# 1. Check Telegram credentials
echo $TELEGRAM_BOT_TOKEN
echo $TELEGRAM_CHAT_ID

# 2. Test bot directly
cd /opt/rustdesk-platform/phase6
source venv/bin/activate
python3 telegram_bot.py

# 3. Check AI service running
ps aux | grep ai_service

# 4. Check logs
tail -f /var/log/rustdesk-ai.log

# 5. Verify token valid
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe"

# Should return your bot info
```

### Grafana Dashboard Blank

**Problem:** Dashboard shows no data

**Solution:**

```bash
# 1. Check Prometheus is running
curl http://192.168.1.40:9090/api/v1/targets

# 2. Check metrics are being scraped
curl http://192.168.1.40:9090/api/v1/query?query=up

# 3. Check API is sending heartbeats
curl -X GET http://localhost:8000/api/v1/heartbeat/1/latest \
  -H "Authorization: Bearer $TOKEN"

# 4. Restart Prometheus
docker restart rustdesk-prometheus

# 5. Wait 2 minutes for data to appear
```

### Slow Connection

**Problem:** Remote access is laggy

**Solution:**

```
1. Check network:
   - WiFi signal: Should be > 3 bars
   - Latency: ping < 50ms
   - Bandwidth: > 5 Mbps

2. Reduce screen quality:
   - In RustDesk settings
   - Lower resolution
   - Reduce color depth

3. Check device CPU:
   - Should be < 60%
   - Kill background apps
   - Restart device if needed

4. Use wired connection:
   - Connect with USB Ethernet
   - Much faster than WiFi

5. Check server load:
   ssh cosmic@192.168.1.40 'top -b -n 1 | head -20'
   - Should be < 80% CPU
```

---

## API Reference

### Authentication

**Get Token:**

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "engineer@yourdomain.com",
    "password": "YourPassword123!!"
  }'

Response:
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

**Use Token:**

```bash
# Add to every request header:
-H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

### Common API Calls

**List all devices:**

```bash
curl -X GET http://localhost:8000/api/v1/devices \
  -H "Authorization: Bearer $TOKEN"
```

**Start connection:**

```bash
curl -X POST http://localhost:8000/api/v1/connections/start \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"device_id": 1, "source_ip": "YOUR_IP"}'
```

**Get device metrics:**

```bash
curl -X GET http://localhost:8000/api/v1/heartbeat/1/latest \
  -H "Authorization: Bearer $TOKEN"
```

**Get active alerts:**

```bash
curl -X GET "http://localhost:8000/api/v1/alerts?resolved=false" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Performance Tips

### Optimize Connection Speed

```
1. Local Network Only:
   - Use WiFi on same LAN
   - Avoid public internet
   - Latency: < 10ms

2. Reduce Screen Quality:
   - Settings > Video quality
   - Choose "Fast"
   - Resolution: 720p or lower

3. Disable Unnecessary Features:
   - Clipboard sharing: Off
   - File transfer: Only when needed
   - Audio: Off if not needed

4. Server Optimization:
   - Run on same network as devices
   - Use wired Ethernet for server
   - No VPN between server and device
```

### Battery Conservation (Android)

```
In RustDesk settings:

1. Power Saving:
   - Enable power saving mode
   - Reduce refresh rate
   - Disable animations

2. Connection Settings:
   - Connection type: TCP only
   - Compression: Maximum
   - Codec: H264 (lower power)

3. Monitoring:
   - Heartbeat interval: 120s (default 60s)
   - Disable always-on
   - Allow sleep mode
```

---

## Security Best Practices

### Device Security

```
1. Use Strong Passwords:
   ✅ Minimum 14 characters
   ✅ Mix uppercase & lowercase
   ✅ Include numbers & symbols
   ❌ Don't reuse passwords

2. Network Security:
   ✅ Keep firewall enabled
   ✅ Use WiFi encryption (WPA3)
   ✅ Use VPN for public networks
   ❌ Don't use public WiFi for sensitive access

3. Access Control:
   ✅ Rotate passwords monthly
   ✅ Use API tokens instead of passwords
   ✅ Enable 2FA on accounts
   ❌ Don't share credentials
```

### Server Security

```
1. SSH Security:
   ✅ Key-based authentication only
   ✅ No root login
   ✅ Firewall SSH to specific IPs

2. API Security:
   ✅ Use HTTPS (when deployed)
   ✅ Rate limiting enabled
   ✅ CORS configured

3. Database Security:
   ✅ Strong password
   ✅ Regular backups
   ✅ Encrypted storage
```

---

## FAQ

**Q: Can I access Android device from public internet?**

A: Yes, with Cloudflare Tunnel (Phase 5). Use:
```bash
cloudflared tunnel create rustdesk-enterprise
# Then access from anywhere securely
```

**Q: How many devices can I manage?**

A: Theoretically unlimited. Current setup handles 1,000+ devices comfortably.

**Q: What's the latency?**

A: Local network: <1s, Same city: 1-3s, Different region: 5-10s

**Q: Can I control multiple devices simultaneously?**

A: Yes, open multiple browser tabs/windows for different devices.

**Q: How often are backups taken?**

A: Daily at 2 AM UTC. Retention: 30 days.

**Q: What if device goes offline?**

A: Alert sent within 5 minutes. Auto-restart attempted. Escalation after 30 mins.

**Q: Can I schedule maintenance windows?**

A: Yes, set `maintenance_mode: true` on device to suppress alerts.

---

## Summary

You now have a **complete remote access and monitoring platform** with:

✅ Instant access to Android & other devices  
✅ Real-time monitoring dashboards  
✅ Automatic anomaly detection  
✅ Self-healing capabilities  
✅ Mobile alerts via Telegram  
✅ Complete audit logging  
✅ Enterprise security  

**Start by:**
1. Opening Grafana: http://192.168.1.40:3000
2. Adding your first Android device
3. Testing remote access
4. Setting up Telegram alerts
5. Monitoring your devices!

---

**Questions?** Check the API docs or troubleshooting section above!

**Ready to scale?** Deploy to Kubernetes when you're ready!

Generated: 2026-05-28  
Version: 1.0.0
