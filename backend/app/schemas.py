"""
Pydantic schemas for request/response validation
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, EmailStr, Field
from uuid import UUID

# ============================================================================
# Auth Schemas
# ============================================================================

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int

class TokenRefreshRequest(BaseModel):
    refresh_token: str

# ============================================================================
# Engineer Schemas
# ============================================================================

class EngineerCreate(BaseModel):
    full_name: str
    email: EmailStr
    phone: Optional[str] = None
    role: str = "support"
    branch_ids: Optional[List[int]] = []
    password: str = Field(..., min_length=14)

class EngineerUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[str] = None
    branch_ids: Optional[List[int]] = None
    is_active: Optional[bool] = None

class EngineerResponse(BaseModel):
    id: int
    engineer_id: str
    full_name: str
    email: str
    phone: Optional[str]
    role: str
    branch_ids: List[int]
    is_active: bool
    last_login: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True

# ============================================================================
# Device Schemas
# ============================================================================

class DeviceCreate(BaseModel):
    device_id: str
    branch_id: Optional[int] = None
    device_type: Optional[str] = None
    os_version: Optional[str] = None
    permanent_password: str
    hostname: Optional[str] = None

class DeviceUpdate(BaseModel):
    status: Optional[str] = None
    ip_address: Optional[str] = None
    mac_address: Optional[str] = None
    maintenance_mode: Optional[bool] = None
    tags: Optional[Dict[str, Any]] = None

class DeviceResponse(BaseModel):
    id: int
    device_id: str
    rustdesk_id: Optional[str]
    status: str
    hostname: Optional[str]
    ip_address: Optional[str]
    last_seen_at: Optional[datetime]
    registered_at: datetime
    device_type: Optional[str]
    os_version: Optional[str]
    rustdesk_version: Optional[str]

    class Config:
        from_attributes = True

# ============================================================================
# Connection Schemas
# ============================================================================

class ConnectionStart(BaseModel):
    device_id: int
    source_ip: str
    source_hostname: Optional[str] = None
    session_key: str

class ConnectionEnd(BaseModel):
    connection_id: UUID
    duration_seconds: int
    disconnect_reason: Optional[str] = None
    files_transferred: Optional[int] = 0
    bandwidth_used_mb: Optional[float] = None
    actions_performed: Optional[Dict[str, Any]] = None

class ConnectionResponse(BaseModel):
    id: int
    connection_id: UUID
    engineer_id: int
    device_id: int
    started_at: datetime
    ended_at: Optional[datetime]
    duration_seconds: Optional[int]
    was_unattended: bool
    files_transferred: int
    disconnect_reason: Optional[str]

    class Config:
        from_attributes = True

# ============================================================================
# Heartbeat Schemas
# ============================================================================

class HeartbeatData(BaseModel):
    device_id: int
    cpu_percent: Optional[float] = None
    ram_percent: Optional[float] = None
    disk_percent: Optional[float] = None
    network_status: Optional[str] = None
    temperature_celsius: Optional[float] = None
    processes_count: Optional[int] = None
    memory_available_mb: Optional[int] = None
    disk_available_gb: Optional[float] = None
    rustdesk_memory_mb: Optional[int] = None
    rustdesk_cpu_percent: Optional[float] = None
    custom_metrics: Optional[Dict[str, Any]] = None

class HeartbeatResponse(BaseModel):
    id: int
    device_id: int
    timestamp: datetime
    cpu_percent: Optional[float]
    ram_percent: Optional[float]
    disk_percent: Optional[float]
    network_status: Optional[str]

    class Config:
        from_attributes = True

# ============================================================================
# Alert Schemas
# ============================================================================

class AlertCreate(BaseModel):
    device_id: int
    alert_type: str
    severity: str
    message: str
    metric_value: Optional[float] = None
    threshold_value: Optional[float] = None

class AlertAcknowledge(BaseModel):
    acknowledged: bool = True

class AlertResolve(BaseModel):
    resolved: bool = True
    resolution_notes: Optional[str] = None

class AlertResponse(BaseModel):
    id: int
    alert_id: UUID
    device_id: int
    alert_type: str
    severity: str
    message: str
    is_resolved: bool
    is_acknowledged: bool
    triggered_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True

# ============================================================================
# Audit Log Schemas
# ============================================================================

class AuditLogResponse(BaseModel):
    id: int
    action: str
    actor_type: str
    actor_id: str
    resource_type: str
    resource_id: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

# ============================================================================
# Location & Branch Schemas
# ============================================================================

class LocationCreate(BaseModel):
    location_id: str
    name: str
    city: Optional[str] = None
    country: Optional[str] = None
    timezone: str = "UTC"

class LocationResponse(BaseModel):
    id: int
    location_id: str
    name: str
    city: Optional[str]
    country: Optional[str]
    timezone: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class BranchCreate(BaseModel):
    branch_id: str
    location_id: int
    name: str
    manager_name: Optional[str] = None
    manager_phone: Optional[str] = None
    address: Optional[str] = None

class BranchResponse(BaseModel):
    id: int
    branch_id: str
    name: str
    location_id: int
    manager_name: Optional[str]
    manager_phone: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
