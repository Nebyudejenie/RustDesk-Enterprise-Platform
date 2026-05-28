"""
SQLAlchemy ORM Models for RustDesk Phase 4
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Numeric, ARRAY, JSONB, INET, UUID as SQLUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.database import Base

class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True)
    location_id = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    city = Column(String(100))
    country = Column(String(100))
    latitude = Column(Numeric(10, 8))
    longitude = Column(Numeric(11, 8))
    timezone = Column(String(50), default="UTC")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    is_active = Column(Boolean, default=True, index=True)

    branches = relationship("Branch", back_populates="location")
    devices = relationship("Device", back_populates="location")

class Branch(Base):
    __tablename__ = "branches"

    id = Column(Integer, primary_key=True)
    branch_id = Column(String(50), unique=True, nullable=False, index=True)
    location_id = Column(Integer, ForeignKey("locations.id"), index=True)
    name = Column(String(255), nullable=False)
    manager_name = Column(String(255))
    manager_phone = Column(String(20))
    address = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    is_active = Column(Boolean, default=True, index=True)

    location = relationship("Location", back_populates="branches")
    devices = relationship("Device", back_populates="branch")
    device_groups = relationship("DeviceGroup", back_populates="branch")

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True)
    device_id = Column(String(100), unique=True, nullable=False, index=True)
    rustdesk_id = Column(String(255), unique=True)
    branch_id = Column(Integer, ForeignKey("branches.id"), index=True)
    location_id = Column(Integer, ForeignKey("locations.id"), index=True)
    device_type = Column(String(50))
    os_version = Column(String(100))
    rustdesk_version = Column(String(50))
    permanent_password_hash = Column(String(255))
    hostname = Column(String(255))
    ip_address = Column(INET)
    last_ip = Column(INET)
    mac_address = Column(String(17))
    status = Column(String(20), default="offline", index=True)
    last_seen_at = Column(DateTime, index=True)
    registered_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    tags = Column(JSONB, default={})
    metadata = Column(JSONB, default={})
    is_active = Column(Boolean, default=True, index=True)
    maintenance_mode = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    branch = relationship("Branch", back_populates="devices")
    location = relationship("Location", back_populates="devices")
    connections = relationship("Connection", back_populates="device")
    heartbeats = relationship("DeviceHeartbeat", back_populates="device")
    alerts = relationship("Alert", back_populates="device")

class Engineer(Base):
    __tablename__ = "engineers"

    id = Column(Integer, primary_key=True)
    engineer_id = Column(String(100), unique=True, nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    phone = Column(String(20))
    password_hash = Column(String(255))
    role = Column(String(50), default="support", index=True)
    branch_ids = Column(ARRAY(Integer), default=[])
    is_active = Column(Boolean, default=True, index=True)
    mfa_secret = Column(String(255))
    last_login = Column(DateTime)
    login_attempts = Column(Integer, default=0)
    locked_until = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    connections = relationship("Connection", back_populates="engineer")
    sessions = relationship("Session", back_populates="engineer")
    alerts_resolved = relationship("Alert", foreign_keys="Alert.resolved_by", back_populates="resolved_by_engineer")
    alerts_acknowledged = relationship("Alert", foreign_keys="Alert.acknowledged_by", back_populates="acknowledged_by_engineer")

class Connection(Base):
    __tablename__ = "connections"

    id = Column(Integer, primary_key=True)
    connection_id = Column(SQLUUID, default=uuid.uuid4, unique=True)
    engineer_id = Column(Integer, ForeignKey("engineers.id"), index=True)
    device_id = Column(Integer, ForeignKey("devices.id"), index=True)
    started_at = Column(DateTime, nullable=False, server_default=func.now(), index=True)
    ended_at = Column(DateTime)
    duration_seconds = Column(Integer)
    source_ip = Column(INET)
    source_hostname = Column(String(255))
    session_key = Column(String(255))
    disconnect_reason = Column(String(100))
    was_unattended = Column(Boolean, default=False)
    files_transferred = Column(Integer, default=0)
    actions_performed = Column(JSONB, default={})
    connection_quality = Column(String(50))
    bandwidth_used_mb = Column(Numeric(10, 2))
    created_at = Column(DateTime, server_default=func.now(), index=True)

    engineer = relationship("Engineer", back_populates="connections")
    device = relationship("Device", back_populates="connections")

class DeviceHeartbeat(Base):
    __tablename__ = "device_heartbeats"

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey("devices.id"), index=True)
    timestamp = Column(DateTime, server_default=func.now(), index=True)
    cpu_percent = Column(Numeric(5, 2))
    ram_percent = Column(Numeric(5, 2))
    disk_percent = Column(Numeric(5, 2))
    network_status = Column(String(50))
    temperature_celsius = Column(Numeric(5, 2))
    processes_count = Column(Integer)
    memory_available_mb = Column(Integer)
    disk_available_gb = Column(Numeric(10, 2))
    rustdesk_memory_mb = Column(Integer)
    rustdesk_cpu_percent = Column(Numeric(5, 2))
    custom_metrics = Column(JSONB, default={})

    device = relationship("Device", back_populates="heartbeats")

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True)
    alert_id = Column(SQLUUID, default=uuid.uuid4, unique=True)
    device_id = Column(Integer, ForeignKey("devices.id"), index=True)
    alert_type = Column(String(100))
    severity = Column(String(20), default="warning", index=True)
    message = Column(Text)
    metric_value = Column(Numeric(10, 2))
    threshold_value = Column(Numeric(10, 2))
    triggered_at = Column(DateTime, server_default=func.now(), index=True)
    resolved_at = Column(DateTime)
    resolved_by = Column(Integer, ForeignKey("engineers.id"))
    acknowledged_at = Column(DateTime)
    acknowledged_by = Column(Integer, ForeignKey("engineers.id"))
    is_resolved = Column(Boolean, default=False, index=True)
    is_acknowledged = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    device = relationship("Device", back_populates="alerts")
    resolved_by_engineer = relationship("Engineer", foreign_keys=[resolved_by])
    acknowledged_by_engineer = relationship("Engineer", foreign_keys=[acknowledged_by])

class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True)
    session_id = Column(SQLUUID, default=uuid.uuid4, unique=True)
    engineer_id = Column(Integer, ForeignKey("engineers.id"), index=True)
    access_token = Column(String(500))
    refresh_token = Column(String(500))
    token_expires_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    last_activity = Column(DateTime, server_default=func.now())
    ip_address = Column(INET)
    user_agent = Column(Text)
    is_valid = Column(Boolean, default=True, index=True)

    engineer = relationship("Engineer", back_populates="sessions")

class ApiKey(Base):
    __tablename__ = "api_keys"

    id = Column(Integer, primary_key=True)
    key_id = Column(SQLUUID, default=uuid.uuid4, unique=True)
    key_hash = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255))
    description = Column(Text)
    created_by = Column(Integer, ForeignKey("engineers.id"))
    scopes = Column(ARRAY(String), default=[])
    rate_limit = Column(Integer, default=1000)
    last_used_at = Column(DateTime)
    expires_at = Column(DateTime)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, server_default=func.now())

class AuditLog(Base):
    __tablename__ = "audit_log"

    id = Column(Integer, primary_key=True)
    action = Column(String(100), index=True)
    actor_type = Column(String(50))
    actor_id = Column(String(255), index=True)
    resource_type = Column(String(100), index=True)
    resource_id = Column(String(255), index=True)
    changes = Column(JSONB)
    old_values = Column(JSONB)
    new_values = Column(JSONB)
    ip_address = Column(INET)
    user_agent = Column(Text)
    status = Column(String(50), default="success")
    error_message = Column(Text)
    created_at = Column(DateTime, server_default=func.now(), index=True)

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True)
    notification_id = Column(SQLUUID, default=uuid.uuid4, unique=True)
    engineer_id = Column(Integer, ForeignKey("engineers.id"), index=True)
    alert_id = Column(Integer, ForeignKey("alerts.id"))
    title = Column(String(255))
    message = Column(Text)
    notification_type = Column(String(100))
    priority = Column(String(20), default="normal")
    is_read = Column(Boolean, default=False, index=True)
    read_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    expires_at = Column(DateTime)

class DeviceGroup(Base):
    __tablename__ = "device_groups"

    id = Column(Integer, primary_key=True)
    group_id = Column(String(100), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    branch_id = Column(Integer, ForeignKey("branches.id"), index=True)
    device_ids = Column(ARRAY(Integer), default=[])
    created_by = Column(Integer, ForeignKey("engineers.id"))
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    branch = relationship("Branch", back_populates="device_groups")
