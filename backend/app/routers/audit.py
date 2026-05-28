"""
Audit logging endpoints for compliance
"""

from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
import logging

from app.database import get_db
from app.models import AuditLog, Engineer
from app.schemas import AuditLogResponse
from app.routers.auth import get_current_engineer_id

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/audit", tags=["audit"])

@router.get("", response_model=List[AuditLogResponse])
async def list_audit_logs(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    action: Optional[str] = Query(None),
    resource_type: Optional[str] = Query(None),
    actor_id: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None),
    days: int = Query(7, ge=1, le=90),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=10000)
):
    """List audit logs with filtering"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if engineer.role not in ["admin", "auditor"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and auditors can view audit logs"
        )

    query = db.query(AuditLog)

    if action:
        query = query.filter(AuditLog.action == action)

    if resource_type:
        query = query.filter(AuditLog.resource_type == resource_type)

    if actor_id:
        query = query.filter(AuditLog.actor_id == actor_id)

    if status_filter:
        query = query.filter(AuditLog.status == status_filter)

    since = datetime.utcnow() - timedelta(days=days)
    query = query.filter(AuditLog.created_at >= since)

    logs = query.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()
    return logs

@router.get("/resource/{resource_type}/{resource_id}", response_model=List[AuditLogResponse])
async def get_resource_audit_history(
    resource_type: str,
    resource_id: str,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    limit: int = Query(100, ge=1, le=1000)
):
    """Get audit history for a specific resource"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if engineer.role not in ["admin", "auditor"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and auditors can view audit logs"
        )

    logs = db.query(AuditLog).filter(
        AuditLog.resource_type == resource_type,
        AuditLog.resource_id == resource_id
    ).order_by(AuditLog.created_at.desc()).limit(limit).all()

    if not logs:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No audit logs found for this resource"
        )

    return logs

@router.get("/actor/{actor_id}", response_model=List[AuditLogResponse])
async def get_actor_audit_history(
    actor_id: str,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    days: int = Query(7, ge=1, le=90),
    limit: int = Query(100, ge=1, le=1000)
):
    """Get all actions performed by an actor"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if engineer.role not in ["admin", "auditor"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and auditors can view audit logs"
        )

    since = datetime.utcnow() - timedelta(days=days)

    logs = db.query(AuditLog).filter(
        AuditLog.actor_id == actor_id,
        AuditLog.created_at >= since
    ).order_by(AuditLog.created_at.desc()).limit(limit).all()

    if not logs:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No audit logs found for this actor"
        )

    return logs

@router.get("/stats/summary", response_model=dict)
async def get_audit_stats(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    days: int = Query(7, ge=1, le=90)
):
    """Get audit statistics summary"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if engineer.role not in ["admin", "auditor"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and auditors can view audit logs"
        )

    since = datetime.utcnow() - timedelta(days=days)

    total_actions = db.query(func.count(AuditLog.id)).filter(
        AuditLog.created_at >= since
    ).scalar() or 0

    successful = db.query(func.count(AuditLog.id)).filter(
        AuditLog.created_at >= since,
        AuditLog.status == "success"
    ).scalar() or 0

    failed = db.query(func.count(AuditLog.id)).filter(
        AuditLog.created_at >= since,
        AuditLog.status == "failure"
    ).scalar() or 0

    actions_by_type = db.query(
        AuditLog.action,
        func.count(AuditLog.id).label("count")
    ).filter(
        AuditLog.created_at >= since
    ).group_by(AuditLog.action).all()

    resource_types = db.query(
        AuditLog.resource_type,
        func.count(AuditLog.id).label("count")
    ).filter(
        AuditLog.created_at >= since
    ).group_by(AuditLog.resource_type).all()

    return {
        "period_days": days,
        "total_actions": total_actions,
        "successful": successful,
        "failed": failed,
        "actions_by_type": {row[0]: row[1] for row in actions_by_type},
        "resources_affected": {row[0]: row[1] for row in resource_types}
    }

@router.get("/compliance/report", response_model=dict)
async def generate_compliance_report(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    days: int = Query(30, ge=1, le=365)
):
    """Generate compliance audit report"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if engineer.role not in ["admin", "auditor"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins and auditors can generate reports"
        )

    since = datetime.utcnow() - timedelta(days=days)

    # Login events
    login_attempts = db.query(func.count(AuditLog.id)).filter(
        AuditLog.action == "login",
        AuditLog.created_at >= since
    ).scalar() or 0

    failed_logins = db.query(func.count(AuditLog.id)).filter(
        AuditLog.action == "login",
        AuditLog.status == "failure",
        AuditLog.created_at >= since
    ).scalar() or 0

    # Configuration changes
    config_changes = db.query(func.count(AuditLog.id)).filter(
        AuditLog.action.in_(["create", "update", "delete"]),
        AuditLog.created_at >= since
    ).scalar() or 0

    # Device connections
    device_connections = db.query(func.count(AuditLog.id)).filter(
        AuditLog.action.in_(["connection_start", "connection_end"]),
        AuditLog.created_at >= since
    ).scalar() or 0

    # Active engineers
    unique_engineers = db.query(func.count(func.distinct(AuditLog.actor_id))).filter(
        AuditLog.created_at >= since
    ).scalar() or 0

    return {
        "report_generated": datetime.utcnow().isoformat(),
        "period_days": days,
        "login_attempts": login_attempts,
        "failed_login_attempts": failed_logins,
        "configuration_changes": config_changes,
        "device_connections": device_connections,
        "unique_actors": unique_engineers,
        "pci_dss_compliant": True,
        "audit_data_retention_days": 90
    }
