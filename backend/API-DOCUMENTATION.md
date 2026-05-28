# RustDesk Phase 4 - REST API Documentation

**Version:** 1.0.0  
**Base URL:** `/api/v1`  
**Authentication:** JWT Bearer Token  
**Format:** JSON  

## Table of Contents

1. [Authentication](#authentication)
2. [Devices API](#devices-api)
3. [Connections API](#connections-api)
4. [Heartbeat API](#heartbeat-api)
5. [Engineers API](#engineers-api)
6. [Alerts API](#alerts-api)
7. [Audit API](#audit-api)
8. [Error Handling](#error-handling)
9. [Rate Limiting](#rate-limiting)

---

## Authentication

All endpoints require JWT authentication except `/health` and heartbeat recording.

### Login

**Endpoint:** `POST /auth/login`

**Request:**
```json
{
  "email": "engineer@example.com",
  "password": "SecurePassword123!!"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

### Refresh Token

**Endpoint:** `POST /auth/refresh`

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:** Same as login response

### Validate Token

**Endpoint:** `POST /auth/validate-token`

**Headers:** `Authorization: Bearer {access_token}`

**Response:**
```json
{
  "valid": true,
  "engineer_id": 1
}
```

### Logout

**Endpoint:** `POST /auth/logout`

**Headers:** `Authorization: Bearer {access_token}`

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

---

## Devices API

### Create Device

**Endpoint:** `POST /devices`

**Headers:** `Authorization: Bearer {access_token}`

**Request:**
```json
{
  "device_id": "POS-ADDIS-001",
  "branch_id": 1,
  "device_type": "POS",
  "os_version": "Windows 10 Pro",
  "permanent_password": "SecureDevicePassword123!!",
  "hostname": "POS-ADDIS-001.local"
}
```

**Response:**
```json
{
  "id": 1,
  "device_id": "POS-ADDIS-001",
  "rustdesk_id": null,
  "status": "offline",
  "hostname": "POS-ADDIS-001.local",
  "ip_address": null,
  "last_seen_at": null,
  "registered_at": "2024-01-15T10:30:00",
  "device_type": "POS",
  "os_version": "Windows 10 Pro",
  "rustdesk_version": null
}
```

### List Devices

**Endpoint:** `GET /devices`

**Query Parameters:**
- `status_filter` (optional): "online", "offline", "maintenance", "error"
- `branch_id` (optional): Filter by branch
- `skip` (default: 0): Pagination offset
- `limit` (default: 100): Results per page

**Response:**
```json
[
  {
    "id": 1,
    "device_id": "POS-ADDIS-001",
    "status": "online",
    "hostname": "POS-ADDIS-001.local",
    "ip_address": "192.168.1.100",
    "last_seen_at": "2024-01-15T14:25:30",
    "registered_at": "2024-01-15T10:30:00",
    "device_type": "POS",
    "os_version": "Windows 10 Pro",
    "rustdesk_version": "1.2.7"
  }
]
```

### Get Device

**Endpoint:** `GET /devices/{device_id}`

**Response:** Single device object (see List Devices)

### Update Device

**Endpoint:** `PATCH /devices/{device_id}`

**Request:**
```json
{
  "status": "maintenance",
  "ip_address": "192.168.1.101",
  "mac_address": "00:1A:2B:3C:4D:5E",
  "maintenance_mode": true,
  "tags": {
    "location": "head-office",
    "support_level": "priority"
  }
}
```

### Delete Device

**Endpoint:** `DELETE /devices/{device_id}`

**Response:** HTTP 204 No Content

### Get Device Connections

**Endpoint:** `GET /devices/{device_id}/connections`

**Query Parameters:**
- `limit` (default: 50, max: 1000)

### Device Statistics

**Endpoint:** `GET /devices/stats/overview`

**Response:**
```json
{
  "total_devices": 150,
  "online_devices": 145,
  "offline_devices": 5,
  "maintenance_devices": 2,
  "uptime_percentage": 96.67
}
```

---

## Connections API

### Start Connection

**Endpoint:** `POST /connections/start`

**Request:**
```json
{
  "device_id": 1,
  "source_ip": "203.0.113.45",
  "source_hostname": "engineer-workstation.local",
  "session_key": "abc123def456ghi789"
}
```

**Response:**
```json
{
  "connection_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T14:30:00"
}
```

### End Connection

**Endpoint:** `POST /connections/{connection_id}/end`

**Request:**
```json
{
  "duration_seconds": 1800,
  "disconnect_reason": "normal",
  "files_transferred": 5,
  "bandwidth_used_mb": 250.5,
  "actions_performed": {
    "remote_reboot": 1,
    "software_updated": 1,
    "files_accessed": 10
  }
}
```

### List Connections

**Endpoint:** `GET /connections`

**Query Parameters:**
- `device_id` (optional): Filter by device
- `days` (default: 7): Historical data range
- `skip` (default: 0)
- `limit` (default: 100)

### Get Connection Details

**Endpoint:** `GET /connections/{connection_id}`

### Connection Statistics

**Endpoint:** `GET /connections/stats/summary`

**Query Parameters:**
- `days` (default: 7)

**Response:**
```json
{
  "total_connections": 450,
  "total_hours": 125.5,
  "unattended_connections": 350,
  "period_days": 7
}
```

---

## Heartbeat API

### Record Heartbeat

**Endpoint:** `POST /heartbeat`

**Note:** This endpoint does NOT require authentication. Uses device API key validation.

**Request:**
```json
{
  "device_id": 1,
  "cpu_percent": 45.2,
  "ram_percent": 68.5,
  "disk_percent": 72.1,
  "network_status": "connected",
  "temperature_celsius": 52.3,
  "processes_count": 185,
  "memory_available_mb": 8192,
  "disk_available_gb": 450.5,
  "rustdesk_memory_mb": 125,
  "rustdesk_cpu_percent": 2.5,
  "custom_metrics": {
    "ip_address": "192.168.1.100",
    "connected_users": 3
  }
}
```

**Response:**
```json
{
  "status": "recorded",
  "device_id": "POS-ADDIS-001",
  "timestamp": "2024-01-15T14:35:00"
}
```

### Get Latest Heartbeat

**Endpoint:** `GET /heartbeat/{device_id}/latest`

### Get Heartbeat History

**Endpoint:** `GET /heartbeat/{device_id}/history`

**Query Parameters:**
- `hours` (default: 24, max: 168)
- `limit` (default: 1000)

### Health Summary

**Endpoint:** `GET /heartbeat/stats/health-summary`

**Response:**
```json
{
  "devices_total": 150,
  "devices_online": 145,
  "online_percentage": 96.67,
  "avg_cpu_percent": 42.3,
  "avg_ram_percent": 65.2,
  "avg_disk_percent": 71.8,
  "critical_alerts": 2
}
```

---

## Engineers API

### Create Engineer

**Endpoint:** `POST /engineers` (Admin only)

**Request:**
```json
{
  "full_name": "John Doe",
  "email": "john.doe@example.com",
  "phone": "+251911234567",
  "role": "support",
  "branch_ids": [1, 2],
  "password": "SecureEngineerPassword123!!"
}
```

### List Engineers

**Endpoint:** `GET /engineers`

**Query Parameters:**
- `role_filter` (optional): "admin", "support", "auditor"
- `skip` (default: 0)
- `limit` (default: 100)

### Get Engineer

**Endpoint:** `GET /engineers/{engineer_id}`

### Update Engineer

**Endpoint:** `PATCH /engineers/{engineer_id}` (Admin only)

**Request:**
```json
{
  "full_name": "John Doe Jr",
  "phone": "+251911234568",
  "role": "manager",
  "branch_ids": [1, 2, 3],
  "is_active": true
}
```

### Deactivate Engineer

**Endpoint:** `POST /engineers/{engineer_id}/deactivate` (Admin only)

---

## Alerts API

### Create Alert

**Endpoint:** `POST /alerts`

**Request:**
```json
{
  "device_id": 1,
  "alert_type": "cpu_high",
  "severity": "critical",
  "message": "CPU usage is 95%",
  "metric_value": 95.0,
  "threshold_value": 90.0
}
```

### List Alerts

**Endpoint:** `GET /alerts`

**Query Parameters:**
- `severity` (optional): "info", "warning", "critical"
- `resolved` (optional): true/false
- `device_id` (optional)
- `hours` (default: 24)
- `skip` (default: 0)
- `limit` (default: 100)

### Get Alert

**Endpoint:** `GET /alerts/{alert_id}`

### Acknowledge Alert

**Endpoint:** `POST /alerts/{alert_id}/acknowledge`

**Request:**
```json
{
  "acknowledged": true
}
```

### Resolve Alert

**Endpoint:** `POST /alerts/{alert_id}/resolve`

**Request:**
```json
{
  "resolved": true,
  "resolution_notes": "Cleared cache and restarted service"
}
```

### Alert Statistics

**Endpoint:** `GET /alerts/stats/summary`

**Query Parameters:**
- `hours` (default: 24)

**Response:**
```json
{
  "critical": 2,
  "warning": 8,
  "info": 15,
  "total_active": 25,
  "total_resolved": 120,
  "period_hours": 24
}
```

---

## Audit API

### List Audit Logs

**Endpoint:** `GET /audit` (Admin/Auditor only)

**Query Parameters:**
- `action` (optional): "create", "update", "delete", "login", "connection_start", etc.
- `resource_type` (optional): "device", "engineer", "connection", etc.
- `actor_id` (optional): Filter by actor
- `status_filter` (optional): "success", "failure"
- `days` (default: 7)
- `skip` (default: 0)
- `limit` (default: 100)

### Get Resource Audit History

**Endpoint:** `GET /audit/resource/{resource_type}/{resource_id}`

**Example:** `GET /audit/resource/device/1`

### Get Actor Audit History

**Endpoint:** `GET /audit/actor/{actor_id}`

### Audit Statistics

**Endpoint:** `GET /audit/stats/summary`

**Response:**
```json
{
  "period_days": 7,
  "total_actions": 2450,
  "successful": 2440,
  "failed": 10,
  "actions_by_type": {
    "login": 280,
    "connection_start": 120,
    "connection_end": 120,
    "create": 45,
    "update": 380
  },
  "resources_affected": {
    "connection": 240,
    "device": 450,
    "engineer": 80,
    "session": 280
  }
}
```

### Compliance Report

**Endpoint:** `GET /audit/compliance/report`

**Query Parameters:**
- `days` (default: 30)

**Response:**
```json
{
  "report_generated": "2024-01-15T14:40:00",
  "period_days": 30,
  "login_attempts": 8400,
  "failed_login_attempts": 125,
  "configuration_changes": 450,
  "device_connections": 5400,
  "unique_actors": 25,
  "pci_dss_compliant": true,
  "audit_data_retention_days": 90
}
```

---

## System Endpoints

### Health Check

**Endpoint:** `GET /health`

**No authentication required**

**Response:**
```json
{
  "status": "healthy",
  "service": "rustdesk-api",
  "version": "1.0.0"
}
```

### API Information

**Endpoint:** `GET /api/v1/info`

**Response:**
```json
{
  "name": "RustDesk Enterprise REST API",
  "version": "1.0.0",
  "phase": "Phase 4",
  "endpoints": {
    "auth": "/api/v1/auth",
    "devices": "/api/v1/devices",
    "connections": "/api/v1/connections",
    "engineers": "/api/v1/engineers",
    "alerts": "/api/v1/alerts",
    "heartbeat": "/api/v1/heartbeat",
    "audit": "/api/v1/audit"
  }
}
```

---

## Error Handling

All errors follow standard HTTP status codes and return JSON:

```json
{
  "error": "Device not found",
  "status": 404
}
```

**Common Status Codes:**
- `200 OK` - Success
- `201 Created` - Resource created
- `204 No Content` - Success, no response body
- `400 Bad Request` - Invalid input
- `401 Unauthorized` - Authentication failed
- `403 Forbidden` - Permission denied
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource already exists
- `500 Internal Server Error` - Server error

---

## Rate Limiting

**Limits:**
- 1000 requests per minute per IP
- Heartbeat endpoint: 10,000 requests per minute

**Headers:**
- `X-RateLimit-Limit: 1000`
- `X-RateLimit-Remaining: 999`
- `X-RateLimit-Reset: 1705334400`

When rate limited:
```json
{
  "error": "Rate limit exceeded",
  "status": 429,
  "retry_after": 60
}
```

---

## OpenAPI/Swagger

Interactive API documentation is available at:

```
GET /docs (Swagger UI)
GET /redoc (ReDoc)
GET /openapi.json (OpenAPI specification)
```

---

**Generated:** 2024-01-15  
**API Version:** 1.0.0  
**Last Updated:** 2026-05-28
