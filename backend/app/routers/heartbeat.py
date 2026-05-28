"""
Device heartbeat and health monitoring endpoints
"""

from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, Header
from sqlalchemy.orm import Session
from sqlalchemy import func
import logging

from app.database import get_db
from app.models import DeviceHeartbeat, Device, Alert
from app.schemas import HeartbeatData, HeartbeatResponse
from app.routers.auth import get_current_engineer_id

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/heartbeat", tags=["heartbeat"])

@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
async def record_heartbeat(
    heartbeat_data: HeartbeatData,
    db: Session = Depends(get_db),
    x_device_id: Optional[str] = Header(None)
):
    """Record device health metrics (no auth required - device API key validation)"""
    device = db.query(Device).filter(Device.id == heartbeat_data.device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    heartbeat = DeviceHeartbeat(
        device_id=heartbeat_data.device_id,
        timestamp=datetime.utcnow(),
        cpu_percent=heartbeat_data.cpu_percent,
        ram_percent=heartbeat_data.ram_percent,
        disk_percent=heartbeat_data.disk_percent,
        network_status=heartbeat_data.network_status,
        temperature_celsius=heartbeat_data.temperature_celsius,
        processes_count=heartbeat_data.processes_count,
        memory_available_mb=heartbeat_data.memory_available_mb,
        disk_available_gb=heartbeat_data.disk_available_gb,
        rustdesk_memory_mb=heartbeat_data.rustdesk_memory_mb,
        rustdesk_cpu_percent=heartbeat_data.rustdesk_cpu_percent,
        custom_metrics=heartbeat_data.custom_metrics or {}
    )

    device.status = "online"
    device.last_seen_at = datetime.utcnow()
    if heartbeat_data.custom_metrics and "ip_address" in heartbeat_data.custom_metrics:
        device.ip_address = heartbeat_data.custom_metrics["ip_address"]

    db.add(heartbeat)
    db.commit()

    check_thresholds_and_create_alerts(db, device, heartbeat_data)

    logger.info(f"Heartbeat recorded for device {device.device_id}")

    return {
        "status": "recorded",
        "device_id": device.device_id,
        "timestamp": heartbeat.timestamp.isoformat()
    }

@router.get("/{device_id}/latest", response_model=Optional[HeartbeatResponse])
async def get_latest_heartbeat(
    device_id: int,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get latest heartbeat for a device"""
    device = db.query(Device).filter(Device.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    heartbeat = db.query(DeviceHeartbeat).filter(
        DeviceHeartbeat.device_id == device_id
    ).order_by(DeviceHeartbeat.timestamp.desc()).first()

    return heartbeat

@router.get("/{device_id}/history", response_model=List[HeartbeatResponse])
async def get_heartbeat_history(
    device_id: int,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    hours: int = Query(24, ge=1, le=168),
    limit: int = Query(1000, ge=1, le=10000)
):
    """Get heartbeat history for a device"""
    device = db.query(Device).filter(Device.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    since = datetime.utcnow() - timedelta(hours=hours)
    heartbeats = db.query(DeviceHeartbeat).filter(
        DeviceHeartbeat.device_id == device_id,
        DeviceHeartbeat.timestamp >= since
    ).order_by(DeviceHeartbeat.timestamp.desc()).limit(limit).all()

    return heartbeats

@router.get("/stats/health-summary", response_model=dict)
async def get_health_summary(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get fleet-wide health summary"""
    devices = db.query(Device).filter(Device.is_active == True).all()

    if not devices:
        return {"devices_total": 0}

    online_count = 0
    avg_cpu = 0.0
    avg_ram = 0.0
    avg_disk = 0.0
    critical_alerts = 0

    for device in devices:
        if device.status == "online":
            online_count += 1

            latest_hb = db.query(DeviceHeartbeat).filter(
                DeviceHeartbeat.device_id == device.id
            ).order_by(DeviceHeartbeat.timestamp.desc()).first()

            if latest_hb:
                avg_cpu += float(latest_hb.cpu_percent or 0)
                avg_ram += float(latest_hb.ram_percent or 0)
                avg_disk += float(latest_hb.disk_percent or 0)

    device_count = len(devices)
    avg_cpu = avg_cpu / device_count if device_count > 0 else 0
    avg_ram = avg_ram / device_count if device_count > 0 else 0
    avg_disk = avg_disk / device_count if device_count > 0 else 0

    critical_alerts = db.query(func.count(Alert.id)).filter(
        Alert.severity == "critical",
        Alert.is_resolved == False
    ).scalar() or 0

    return {
        "devices_total": device_count,
        "devices_online": online_count,
        "online_percentage": round(online_count / device_count * 100, 2) if device_count > 0 else 0,
        "avg_cpu_percent": round(avg_cpu, 2),
        "avg_ram_percent": round(avg_ram, 2),
        "avg_disk_percent": round(avg_disk, 2),
        "critical_alerts": critical_alerts
    }

def check_thresholds_and_create_alerts(db: Session, device: Device, heartbeat_data: HeartbeatData):
    """Create alerts if metrics exceed thresholds"""
    thresholds = {
        "cpu_percent": 90,
        "ram_percent": 90,
        "disk_percent": 95
    }

    alert_types = {
        "cpu_percent": "cpu_high",
        "ram_percent": "ram_high",
        "disk_percent": "disk_full"
    }

    for metric, threshold in thresholds.items():
        value = getattr(heartbeat_data, metric)
        if value and float(value) > threshold:
            alert_type = alert_types[metric]

            existing_alert = db.query(Alert).filter(
                Alert.device_id == device.id,
                Alert.alert_type == alert_type,
                Alert.is_resolved == False
            ).first()

            if not existing_alert:
                alert = Alert(
                    device_id=device.id,
                    alert_type=alert_type,
                    severity="critical" if float(value) > threshold + 10 else "warning",
                    message=f"{metric.replace('_', ' ').title()} is {value}%",
                    metric_value=value,
                    threshold_value=threshold
                )
                db.add(alert)
                logger.warning(f"Alert created for {device.device_id}: {alert_type} = {value}%")

    db.commit()
