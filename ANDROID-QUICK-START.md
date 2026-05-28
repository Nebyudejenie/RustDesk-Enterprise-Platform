# 📱 Android Device Setup - Quick Start Guide

**Get your Android device connected in 5 minutes!**

---

## 📋 What You'll Need

- ✅ Android device (any version)
- ✅ WiFi connection
- ✅ RustDesk Enterprise server running (192.168.1.40)
- ✅ 5 minutes of setup time

---

## ⚡ 5-Minute Setup

### Step 1: Install RustDesk (1 minute)

**On your Android device:**

```
1. Open Google Play Store
2. Search: "RustDesk"
3. Install (by RustDesk)
4. Open app
5. Grant permissions:
   - Camera access ✅
   - Microphone access ✅
   - Storage access ✅
   - Device admin ✅
```

### Step 2: Configure Server (2 minutes)

**In RustDesk app:**

```
1. Tap ⚙️ Settings
2. Tap "Network"
3. Enter Custom Relay Server:
   IP/Hostname: 192.168.1.40
   Port: 21117

4. Enter Signal Server:
   IP/Hostname: 192.168.1.40
   Port: 21115

5. Enter Permanent Password:
   Password: rustdesk
   
6. Tap "Save"
7. App automatically connects
```

**✓ Device is now registered!**

### Step 3: Verify Connection (2 minutes)

**Check in Grafana dashboard:**

```
1. On PC: http://192.168.1.40:3000
2. Login: admin / admin
3. Go to: Dashboards > Devices
4. Look for your Android device
5. Status should show: 🟢 Online
```

**✓ All set! Ready for access!**

---

## 🎮 Instant Remote Access

### Connect from PC/Laptop

**Option A: Via Grafana (Easiest)**

```
1. Go to: http://192.168.1.40:3000
2. Dashboard > Devices
3. Find your device
4. Click "Connect"
5. Choose action:
   📱 Remote Control (full screen)
   📄 File Transfer (upload/download)
   📋 Clipboard Share
6. Control device instantly!
```

**Option B: Via API Command**

```bash
# SSH to server
ssh cosmic@192.168.1.40

# Start connection
curl -X POST http://localhost:8000/api/v1/connections/start \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "device_id": 1,
    "source_ip": "YOUR_PC_IP"
  }'

# Get connection details
curl -X GET http://localhost:8000/api/v1/connections \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Option C: Via Telegram Bot (On Phone)**

```
1. Open Telegram
2. Find your RustDesk bot
3. Send: /devices
4. Select device from list
5. Send: /connect_DEVICE_NAME
6. Bot sends access link
7. Tap to control device
```

---

## 📊 Monitor Your Device

### Real-Time Metrics

**View device health:**

```
In Grafana:
1. Dashboard > Device Health
2. Select your device
3. See real-time:
   • CPU Usage: ___ %
   • RAM Usage: ___ %
   • Disk Usage: ___ %
   • Battery: ___ %
   • Temperature: ___ °C
   • Network Signal: ___
```

### Instant Alerts

**Get notified of problems:**

```
Alerts come to:
📱 Telegram (real-time)
   - Device offline
   - High CPU/Memory
   - Disk full
   - Temperature critical

📊 Grafana Dashboard
   - Shows all active alerts
   - Click for details
   - Manual action buttons
```

---

## 🔧 Device Management

### Register Multiple Devices

**For each Android device:**

```
Device 1: POS-BRANCH-001
├─ Install RustDesk
├─ Configure server (192.168.1.40:21115)
├─ Note Device ID
└─ Register in system

Device 2: POS-BRANCH-002
├─ Install RustDesk
├─ Configure server (192.168.1.40:21115)
├─ Note Device ID
└─ Register in system

Device 3: TABLET-KIOSK-001
├─ Install RustDesk
├─ Configure server (192.168.1.40:21115)
├─ Note Device ID
└─ Register in system
```

### Find Device ID

**On Android device:**

```
In RustDesk app:
1. Main screen
2. Look at top left
3. Shows: Device ID: XXXXXXXXX (9 digits)
4. Copy this number
5. Use when registering: POS-BRANCH-001
```

### Change Device Settings

**Via Grafana:**

```
1. Dashboard > Devices
2. Click device name
3. Edit settings:
   ✏️ Device name
   ✏️ Location/Branch
   ✏️ Device type
   ✏️ Priority level
4. Save
```

---

## 🚨 Troubleshooting

### Device Not Appearing

**If device doesn't show after 2 minutes:**

```bash
# 1. Check connection
adb devices
adb shell ping 192.168.1.40

# 2. Restart app
adb shell am force-stop com.rustdesk.rustdesk
adb shell am start com.rustdesk.rustdesk

# 3. Check server logs
docker logs rustdesk-hbbs | tail -20

# 4. Verify network
- Device on same WiFi?
- Server IP correct (192.168.1.40)?
- Port 21115 accessible?
```

### Can't Connect Remotely

**If getting timeout:**

```
1. Check device online:
   Grafana > Devices > Status should be 🟢 Green

2. Check firewall:
   Server should allow port 21117:
   ssh cosmic@192.168.1.40
   sudo ufw status

3. Check network:
   adb shell netstat -an | grep 21117

4. Restart services:
   docker restart rustdesk-hbbs rustdesk-hbbr

5. Wait 30 seconds and try again
```

### Slow Performance

**If remote access is laggy:**

```
1. Check WiFi signal:
   Settings > WiFi > Signal strength
   Should be 3+ bars

2. Reduce screen quality:
   RustDesk > Settings > Video Quality: Fast

3. Close background apps:
   Settings > Apps > Close unused apps

4. Restart device:
   Power off > Wait 10s > Power on

5. Check server CPU:
   ssh cosmic@192.168.1.40 'top'
   Should be < 80% CPU
```

---

## 📱 What You Can Do

### Remote Control

```
Full screen access to device:
✅ See everything on screen
✅ Tap buttons & icons
✅ Type with keyboard
✅ Swipe & scroll
✅ Open/close apps
✅ Change settings
✅ Install apps
✅ Manage files
```

### File Transfer

```
Upload files to device:
✅ Drag & drop
✅ Browse folders
✅ Create directories
✅ Delete files
✅ Download from device

Download from device:
✅ Select files
✅ Save to PC
✅ Batch transfer
✅ Resume failed transfers
```

### Monitoring

```
Real-time device stats:
✅ CPU temperature
✅ Battery percentage
✅ Storage usage
✅ Memory usage
✅ Network signal
✅ Active processes
✅ Last online time
✅ Historical trends
```

---

## 🔐 Security

### Protect Your Device

```
1. Strong Password:
   ✅ Use: a1B2c3D4e5F6g7H8!
   ❌ Don't use: 12345678

2. Limited Access:
   ✅ Only give password to trusted people
   ✅ Change password monthly
   ❌ Don't share over SMS

3. Monitor Access:
   ✅ Check Grafana for who accessed device
   ✅ Review connection logs
   ✅ Set up alerts
```

---

## 📊 Monitoring Dashboard

### Access Dashboard

```
1. Open: http://192.168.1.40:3000
2. Login: admin / admin
3. Go to: Dashboards > Device Health
4. Select your device
5. See real-time metrics
```

### Dashboard Widgets

```
Show:
📊 CPU Usage (graph)
💾 RAM Usage (gauge)
💿 Disk Usage (bar)
🌡️ Temperature (gauge)
📶 Network Signal (icon)
🔋 Battery Level (percentage)
⏰ Last Seen (time)
🟢 Status (online/offline)
```

### Create Custom Dashboard

```
1. Click "+"
2. Select "Dashboard"
3. Click "Add panel"
4. Choose metric:
   - device_cpu_percent
   - device_ram_percent
   - device_disk_percent
5. Set thresholds (colors)
6. Save dashboard
7. Share with team
```

---

## 📱 Mobile Management

### Telegram Bot Control

**Setup Telegram Bot:**

```
1. Find @BotFather on Telegram
2. Send: /newbot
3. Follow steps to create bot
4. Copy token
5. Find @userinfobot
6. Send: /start
7. Copy Chat ID

Configure on server:
export TELEGRAM_BOT_TOKEN='token'
export TELEGRAM_CHAT_ID='id'
cd /opt/rustdesk-platform/phase6
python3 telegram_bot.py
```

**Use from Phone:**

```
In Telegram chat with bot:

/devices
→ Lists all online devices

/status_POS-BRANCH-001
→ Shows device metrics

/connect_POS-BRANCH-001
→ Starts remote session
→ Sends access link

/alerts
→ Shows active alerts

/help
→ Lists all commands
```

---

## ✅ Quick Checklist

**Setup complete when:**

- [ ] RustDesk installed on Android
- [ ] Server configured (192.168.1.40:21115)
- [ ] Device appears in Grafana (🟢 Online)
- [ ] Can connect remotely from PC
- [ ] Metrics showing in dashboard
- [ ] Telegram alerts configured (optional)
- [ ] Can control device remotely

---

## 🎯 Next Steps

1. **Add more devices** - Follow same process
2. **Setup Telegram alerts** - Get notified of problems
3. **Create custom dashboards** - Monitor what matters
4. **Setup auto-fixes** - Let AI handle problems
5. **Deploy to Kubernetes** - Scale to 1000+ devices

---

## 📞 Need Help?

**Device not showing?**
→ Check server logs: `docker logs rustdesk-hbbs`

**Can't connect?**
→ Check firewall: `sudo ufw status`

**Metrics not appearing?**
→ Restart Prometheus: `docker restart rustdesk-prometheus`

**Performance slow?**
→ Check CPU: `ssh cosmic@192.168.1.40 'top'`

---

**Congratulations!** 🎉 Your Android device is now monitored and remotely accessible!

---

Generated: 2026-05-28  
Version: 1.0.0
