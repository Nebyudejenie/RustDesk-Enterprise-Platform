"""
Alert management endpoints
"""

from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from uuid import UUID
import logging

from app.database import get_db
from app.models import Alert, Device, Engineer
from app.schemas import AlertCreate, AlertAcknowledge, AlertResolve, AlertResponse
from app.routers.auth import get_current_engineer_id, log_audit

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/alerts", tags=["alerts"])

@router.post("", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
async def create_alert(
    alert_data: AlertCreate,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Create a new alert"""
    device = db.query(Device).filter(Device.id == alert_data.device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    alert = Alert(
        device_id=alert_data.device_id,
        alert_type=alert_data.alert_type,
        severity=alert_data.severity,
        message=alert_data.message,
        metric_value=alert_data.metric_value,
        threshold_value=alert_data.threshold_value
    )

    db.add(alert)
    db.commit()
    db.refresh(alert)

    log_audit(
        db,
        action="create",
        actor_id=str(engineer_id),
        resource_type="alert",
        resource_id=str(alert.id),
        status="success"
    )

    return alert

@router.get("", response_model=List[AlertResponse])
async def list_alerts(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    severity: Optional[str] = Query(None),
    resolved: Optional[bool] = Query(None),
    device_id: Optional[int] = Query(None),
    hours: int = Query(24, ge=1, le=720),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    """List alerts with filtering"""
    query = db.query(Alert)

    if severity:
        query = query.filter(Alert.severity == severity)

    if resolved is not None:
        query = query.filter(Alert.is_resolved == resolved)

    if device_id:
        query = query.filter(Alert.device_id == device_id)

    since = datetime.utcnow() - timedelta(hours=hours)
    query = query.filter(Alert.triggered_at >= since)

    alerts = query.order_by(Alert.triggered_at.desc()).offset(skip).limit(limit).all()
    return alerts

@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(
    alert_id: UUID,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get alert details"""
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )

    return alert

@router.post("/{alert_id}/acknowledge", response_model=AlertResponse)
async def acknowledge_alert(
    alert_id: UUID,
    ack_data: AlertAcknowledge,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Acknowledge an alert"""
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )

    alert.is_acknowledged = True
    alert.acknowledged_at = datetime.utcnow()
    alert.acknowledged_by = engineer_id

    db.commit()
    db.refresh(alert)

    log_audit(
        db,
        action="acknowledge",
        actor_id=str(engineer_id),
        resource_type="alert",
        resource_id=str(alert.id),
        status="success"
    )

    logger.info(f"Alert {alert.alert_id} acknowledged by engineer {engineer_id}")
    return alert

@router.post("/{alert_id}/resolve", response_model=AlertResponse)
async def resolve_alert(
    alert_id: UUID,
    resolve_data: AlertResolve,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Resolve an alert"""
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )

    alert.is_resolved = True
    alert.resolved_at = datetime.utcnow()
    alert.resolved_by = engineer_id

    db.commit()
    db.refresh(alert)

    log_audit(
        db,
        action="resolve",
        actor_id=str(engineer_id),
        resource_type="alert",
        resource_id=str(alert.id),
        status="success"
    )

    logger.info(f"Alert {alert.alert_id} resolved by engineer {engineer_id}")
    return alert

@router.get("/stats/summary", response_model=dict)
async def get_alert_stats(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    hours: int = Query(24, ge=1, le=720)
):
    """Get alert statistics"""
    since = datetime.utcnow() - timedelta(hours=hours)

    critical = db.query(func.count(Alert.id)).filter(
        Alert.severity == "critical",
        Alert.triggered_at >= since,
        Alert.is_resolved == False
    ).scalar() or 0

    warning = db.query(func.count(Alert.id)).filter(
        Alert.severity == "warning",
        Alert.triggered_at >= since,
        Alert.is_resolved == False
    ).scalar() or 0

    info = db.query(func.count(Alert.id)).filter(
        Alert.severity == "info",
        Alert.triggered_at >= since,
        Alert.is_resolved == False
    ).scalar() or 0

    total_resolved = db.query(func.count(Alert.id)).filter(
        Alert.triggered_at >= since,
        Alert.is_resolved == True
    ).scalar() or 0

    return {
        "critical": critical,
        "warning": warning,
        "info": info,
        "total_active": critical + warning + info,
        "total_resolved": total_resolved,
        "period_hours": hours
    }
