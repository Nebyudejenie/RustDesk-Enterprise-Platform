"""
Device management endpoints
"""

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
import logging

from app.database import get_db
from app.models import Device, Branch, Location, AuditLog, Connection
from app.schemas import DeviceCreate, DeviceUpdate, DeviceResponse
from app.routers.auth import get_current_engineer_id, hash_password, log_audit

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/devices", tags=["devices"])

@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def create_device(
    device_data: DeviceCreate,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Register a new device"""
    existing = db.query(Device).filter(Device.device_id == device_data.device_id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Device already registered"
        )

    device = Device(
        device_id=device_data.device_id,
        branch_id=device_data.branch_id,
        device_type=device_data.device_type,
        os_version=device_data.os_version,
        permanent_password_hash=hash_password(device_data.permanent_password),
        hostname=device_data.hostname,
        status="offline",
        is_active=True
    )

    db.add(device)
    db.commit()
    db.refresh(device)

    log_audit(
        db,
        action="create",
        actor_id=str(engineer_id),
        resource_type="device",
        resource_id=str(device.id),
        status="success",
        new_values={"device_id": device.device_id}
    )

    logger.info(f"Device {device.device_id} registered by engineer {engineer_id}")
    return device

@router.get("", response_model=List[DeviceResponse])
async def list_devices(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    status_filter: Optional[str] = Query(None),
    branch_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    """List all devices (filtered by status or branch)"""
    query = db.query(Device).filter(Device.is_active == True)

    if status_filter:
        query = query.filter(Device.status == status_filter)

    if branch_id:
        query = query.filter(Device.branch_id == branch_id)

    devices = query.order_by(Device.last_seen_at.desc()).offset(skip).limit(limit).all()
    return devices

@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get device details"""
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    return device

@router.patch("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: str,
    update_data: DeviceUpdate,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Update device information"""
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    old_values = {
        "status": device.status,
        "ip_address": str(device.ip_address) if device.ip_address else None,
        "maintenance_mode": device.maintenance_mode
    }

    if update_data.status:
        device.status = update_data.status
    if update_data.ip_address:
        device.ip_address = update_data.ip_address
    if update_data.mac_address:
        device.mac_address = update_data.mac_address
    if update_data.maintenance_mode is not None:
        device.maintenance_mode = update_data.maintenance_mode
    if update_data.tags:
        device.tags = update_data.tags

    device.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(device)

    log_audit(
        db,
        action="update",
        actor_id=str(engineer_id),
        resource_type="device",
        resource_id=str(device.id),
        status="success",
        old_values=old_values,
        new_values=update_data.dict(exclude_unset=True)
    )

    return device

@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: str,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Deactivate a device"""
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    device.is_active = False
    device.updated_at = datetime.utcnow()
    db.commit()

    log_audit(
        db,
        action="delete",
        actor_id=str(engineer_id),
        resource_type="device",
        resource_id=str(device.id),
        status="success"
    )

    logger.info(f"Device {device_id} deactivated by engineer {engineer_id}")

@router.get("/{device_id}/connections", response_model=List[dict])
async def get_device_connections(
    device_id: str,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    limit: int = Query(50, ge=1, le=1000)
):
    """Get connection history for a device"""
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    connections = db.query(Connection).filter(
        Connection.device_id == device.id
    ).order_by(Connection.started_at.desc()).limit(limit).all()

    return [
        {
            "connection_id": str(c.connection_id),
            "engineer": c.engineer.full_name if c.engineer else "Unknown",
            "started_at": c.started_at,
            "ended_at": c.ended_at,
            "duration_seconds": c.duration_seconds,
            "was_unattended": c.was_unattended,
            "disconnect_reason": c.disconnect_reason
        }
        for c in connections
    ]

@router.get("/stats/overview", response_model=dict)
async def get_device_stats(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get device statistics overview"""
    total_devices = db.query(Device).filter(Device.is_active == True).count()
    online_devices = db.query(Device).filter(Device.status == "online").count()
    offline_devices = db.query(Device).filter(Device.status == "offline").count()
    maintenance_devices = db.query(Device).filter(Device.maintenance_mode == True).count()

    return {
        "total_devices": total_devices,
        "online_devices": online_devices,
        "offline_devices": offline_devices,
        "maintenance_devices": maintenance_devices,
        "uptime_percentage": (online_devices / total_devices * 100) if total_devices > 0 else 0
    }
