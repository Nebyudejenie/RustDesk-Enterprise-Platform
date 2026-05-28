# RustDesk Phase 4 - API Quick Reference

## Base URL
```
http://localhost:8000/api/v1
```

## Authentication
All requests require: `Authorization: Bearer {access_token}`

### Get Access Token
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "engineer@example.com",
    "password": "Password123!!"
  }'
```

---

## Devices Endpoints

### Register Device
```bash
curl -X POST http://localhost:8000/api/v1/devices \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "device_id": "POS-001",
    "branch_id": 1,
    "os_version": "Windows 10 Pro",
    "permanent_password": "DevicePass123!!",
    "hostname": "pos-001.local"
  }'
```

### List Devices
```bash
curl -X GET "http://localhost:8000/api/v1/devices?status_filter=online&limit=50" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Device Details
```bash
curl -X GET http://localhost:8000/api/v1/devices/POS-001 \
  -H "Authorization: Bearer $TOKEN"
```

### Update Device
```bash
curl -X PATCH http://localhost:8000/api/v1/devices/POS-001 \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "status": "maintenance",
    "ip_address": "192.168.1.100"
  }'
```

### Delete Device
```bash
curl -X DELETE http://localhost:8000/api/v1/devices/POS-001 \
  -H "Authorization: Bearer $TOKEN"
```

### Device Statistics
```bash
curl -X GET http://localhost:8000/api/v1/devices/stats/overview \
  -H "Authorization: Bearer $TOKEN"
```

---

## Connection Endpoints

### Start Connection
```bash
curl -X POST http://localhost:8000/api/v1/connections/start \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "device_id": 1,
    "source_ip": "203.0.113.45",
    "source_hostname": "engineer.local",
    "session_key": "abc123def456"
  }'
```

### End Connection
```bash
curl -X POST "http://localhost:8000/api/v1/connections/{connection_id}/end" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "duration_seconds": 1800,
    "disconnect_reason": "normal",
    "files_transferred": 5
  }'
```

### List Connections
```bash
curl -X GET "http://localhost:8000/api/v1/connections?device_id=1&days=7&limit=100" \
  -H "Authorization: Bearer $TOKEN"
```

### Connection Statistics
```bash
curl -X GET "http://localhost:8000/api/v1/connections/stats/summary?days=7" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Heartbeat Endpoints

### Record Heartbeat (No Auth Required)
```bash
curl -X POST http://localhost:8000/api/v1/heartbeat \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": 1,
    "cpu_percent": 45.2,
    "ram_percent": 68.5,
    "disk_percent": 72.1,
    "network_status": "connected",
    "rustdesk_memory_mb": 125,
    "rustdesk_cpu_percent": 2.5
  }'
```

### Get Latest Heartbeat
```bash
curl -X GET http://localhost:8000/api/v1/heartbeat/1/latest \
  -H "Authorization: Bearer $TOKEN"
```

### Get Heartbeat History
```bash
curl -X GET "http://localhost:8000/api/v1/heartbeat/1/history?hours=24&limit=1000" \
  -H "Authorization: Bearer $TOKEN"
```

### Health Summary
```bash
curl -X GET http://localhost:8000/api/v1/heartbeat/stats/health-summary \
  -H "Authorization: Bearer $TOKEN"
```

---

## Alert Endpoints

### Create Alert
```bash
curl -X POST http://localhost:8000/api/v1/alerts \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "device_id": 1,
    "alert_type": "cpu_high",
    "severity": "critical",
    "message": "CPU usage is 95%",
    "metric_value": 95.0,
    "threshold_value": 90.0
  }'
```

### List Alerts
```bash
curl -X GET "http://localhost:8000/api/v1/alerts?severity=critical&resolved=false&hours=24" \
  -H "Authorization: Bearer $TOKEN"
```

### Acknowledge Alert
```bash
curl -X POST "http://localhost:8000/api/v1/alerts/{alert_id}/acknowledge" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"acknowledged": true}'
```

### Resolve Alert
```bash
curl -X POST "http://localhost:8000/api/v1/alerts/{alert_id}/resolve" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"resolved": true}'
```

### Alert Statistics
```bash
curl -X GET "http://localhost:8000/api/v1/alerts/stats/summary?hours=24" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Engineer Endpoints

### Create Engineer (Admin Only)
```bash
curl -X POST http://localhost:8000/api/v1/engineers \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "full_name": "John Doe",
    "email": "john@example.com",
    "password": "SecurePass123!!",
    "role": "support",
    "branch_ids": [1, 2]
  }'
```

### List Engineers
```bash
curl -X GET "http://localhost:8000/api/v1/engineers?role_filter=support&limit=100" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Engineer Details
```bash
curl -X GET http://localhost:8000/api/v1/engineers/1 \
  -H "Authorization: Bearer $TOKEN"
```

### Update Engineer (Admin Only)
```bash
curl -X PATCH http://localhost:8000/api/v1/engineers/1 \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "role": "manager",
    "branch_ids": [1, 2, 3]
  }'
```

### Deactivate Engineer (Admin Only)
```bash
curl -X POST http://localhost:8000/api/v1/engineers/1/deactivate \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## Audit Endpoints

### List Audit Logs (Admin/Auditor Only)
```bash
curl -X GET "http://localhost:8000/api/v1/audit?action=login&days=7&limit=100" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Resource Audit History
```bash
curl -X GET "http://localhost:8000/api/v1/audit/resource/device/1" \
  -H "Authorization: Bearer $TOKEN"
```

### Get Actor Audit History
```bash
curl -X GET "http://localhost:8000/api/v1/audit/actor/engineer@example.com?days=30" \
  -H "Authorization: Bearer $TOKEN"
```

### Audit Statistics
```bash
curl -X GET "http://localhost:8000/api/v1/audit/stats/summary?days=7" \
  -H "Authorization: Bearer $TOKEN"
```

### Compliance Report
```bash
curl -X GET "http://localhost:8000/api/v1/audit/compliance/report?days=30" \
  -H "Authorization: Bearer $TOKEN"
```

---

## System Endpoints

### Health Check (No Auth)
```bash
curl http://localhost:8000/health
```

### API Information (No Auth)
```bash
curl http://localhost:8000/api/v1/info
```

### Token Validation
```bash
curl -X POST http://localhost:8000/api/v1/auth/validate-token \
  -H "Authorization: Bearer $TOKEN"
```

### Refresh Token
```bash
curl -X POST http://localhost:8000/api/v1/auth/refresh \
  -d '{"refresh_token": "..."}'
```

### Logout
```bash
curl -X POST http://localhost:8000/api/v1/auth/logout \
  -H "Authorization: Bearer $TOKEN"
```

---

## Database Queries

### Connect to PostgreSQL
```bash
# Docker Compose
docker-compose exec postgres psql -U rustdesk_app -d rustdesk_db

# Kubernetes
kubectl exec -it postgres-0 -n rustdesk-system -- \
  psql -U rustdesk_app -d rustdesk_db
```

### Count Active Devices
```sql
SELECT COUNT(*) FROM devices WHERE is_active = true;
```

### List Recent Connections
```sql
SELECT * FROM v_recent_connections LIMIT 10;
```

### Device Health Status
```sql
SELECT * FROM v_device_health WHERE health_status != 'healthy';
```

### Audit Log by Action
```sql
SELECT action, COUNT(*) FROM audit_log 
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY action;
```

### Engineer Login Attempts
```sql
SELECT full_name, last_login, login_attempts 
FROM engineers WHERE login_attempts > 0;
```

---

## Docker Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f api        # API logs
docker-compose logs -f postgres   # Database logs

# Execute command in container
docker-compose exec api python -c "print('hello')"
docker-compose exec postgres psql -U rustdesk_app -d rustdesk_db

# Scale replicas
docker-compose up -d --scale api=5

# Stop services
docker-compose down

# Cleanup with volumes
docker-compose down -v
```

---

## Kubernetes Commands

```bash
# Check pod status
kubectl get pods -n rustdesk-system

# View logs
kubectl logs -f deployment/rustdesk-api -n rustdesk-system
kubectl logs -f statefulset/postgres -n rustdesk-system

# Exec into pod
kubectl exec -it postgres-0 -n rustdesk-system -- psql -U rustdesk_app -d rustdesk_db

# Port forward
kubectl port-forward svc/rustdesk-api 8000:80 -n rustdesk-system

# Scale deployment
kubectl scale deployment rustdesk-api --replicas=5 -n rustdesk-system

# Check resource usage
kubectl top pod -n rustdesk-system

# Describe resource
kubectl describe statefulset postgres -n rustdesk-system
```

---

## Common Curl Options

```bash
# Pretty print JSON
| jq '.'

# Save to file
--output filename.json

# Show headers
-i

# Verbose output
-v

# Set content type
-H "Content-Type: application/json"

# Include authentication
-H "Authorization: Bearer $TOKEN"

# POST with data
-d '{"key": "value"}'

# Custom method
-X PATCH
-X DELETE
```

---

## Endpoint Status Codes

```
200 OK - Success
201 Created - Resource created
204 No Content - Success, empty response
400 Bad Request - Invalid input
401 Unauthorized - Auth failed
403 Forbidden - Permission denied
404 Not Found - Resource not found
409 Conflict - Resource exists
500 Server Error - Internal error
```

---

## Rate Limits

```
Default: 1000 req/minute per IP
Heartbeat: 10,000 req/minute per IP
```

Headers returned:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705334400
```

---

## Interactive Documentation

```
Swagger UI:  http://localhost:8000/docs
ReDoc:       http://localhost:8000/redoc
OpenAPI:     http://localhost:8000/openapi.json
```

---

**Quick Reference v1.0.0 | 2026-05-28**
