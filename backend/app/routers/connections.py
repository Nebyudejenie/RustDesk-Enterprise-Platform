"""
Connection logging and audit endpoints
"""

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from uuid import UUID
import logging

from app.database import get_db
from app.models import Connection, Device, Engineer, AuditLog
from app.schemas import ConnectionStart, ConnectionEnd, ConnectionResponse
from app.routers.auth import get_current_engineer_id, log_audit

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/connections", tags=["connections"])

@router.post("/start", response_model=dict, status_code=status.HTTP_201_CREATED)
async def start_connection(
    conn_data: ConnectionStart,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Log the start of a remote connection"""
    device = db.query(Device).filter(Device.id == conn_data.device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )

    connection = Connection(
        engineer_id=engineer_id,
        device_id=conn_data.device_id,
        started_at=datetime.utcnow(),
        source_ip=conn_data.source_ip,
        source_hostname=conn_data.source_hostname,
        session_key=conn_data.session_key
    )

    db.add(connection)
    db.commit()
    db.refresh(connection)

    log_audit(
        db,
        action="connection_start",
        actor_id=str(engineer_id),
        resource_type="connection",
        resource_id=str(connection.id),
        status="success"
    )

    return {
        "connection_id": str(connection.connection_id),
        "timestamp": connection.started_at.isoformat()
    }

@router.post("/{connection_id}/end", response_model=dict)
async def end_connection(
    connection_id: UUID,
    conn_data: ConnectionEnd,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Log the end of a remote connection"""
    connection = db.query(Connection).filter(
        Connection.connection_id == connection_id
    ).first()

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found"
        )

    if connection.engineer_id != engineer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot modify another engineer's connection"
        )

    connection.ended_at = datetime.utcnow()
    connection.duration_seconds = conn_data.duration_seconds
    connection.disconnect_reason = conn_data.disconnect_reason
    connection.files_transferred = conn_data.files_transferred or 0
    connection.bandwidth_used_mb = conn_data.bandwidth_used_mb
    connection.actions_performed = conn_data.actions_performed or {}

    db.commit()

    log_audit(
        db,
        action="connection_end",
        actor_id=str(engineer_id),
        resource_type="connection",
        resource_id=str(connection.id),
        status="success",
        new_values={
            "duration_seconds": conn_data.duration_seconds,
            "disconnect_reason": conn_data.disconnect_reason
        }
    )

    return {
        "connection_id": str(connection.connection_id),
        "duration_seconds": connection.duration_seconds,
        "ended_at": connection.ended_at.isoformat()
    }

@router.get("", response_model=List[ConnectionResponse])
async def list_connections(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    device_id: Optional[int] = Query(None),
    days: int = Query(7, ge=1, le=90),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    """List recent connections"""
    query = db.query(Connection)

    if device_id:
        query = query.filter(Connection.device_id == device_id)

    from datetime import timedelta
    since = datetime.utcnow() - timedelta(days=days)
    query = query.filter(Connection.started_at >= since)

    connections = query.order_by(Connection.started_at.desc()).offset(skip).limit(limit).all()
    return connections

@router.get("/{connection_id}", response_model=ConnectionResponse)
async def get_connection(
    connection_id: UUID,
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id)
):
    """Get connection details"""
    connection = db.query(Connection).filter(
        Connection.connection_id == connection_id
    ).first()

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found"
        )

    return connection

@router.get("/stats/summary", response_model=dict)
async def get_connection_stats(
    db: Session = Depends(get_db),
    engineer_id: int = Depends(get_current_engineer_id),
    days: int = Query(7, ge=1, le=365)
):
    """Get connection statistics"""
    from datetime import timedelta
    from sqlalchemy import func

    since = datetime.utcnow() - timedelta(days=days)

    total_connections = db.query(func.count(Connection.id)).filter(
        Connection.started_at >= since
    ).scalar()

    total_duration = db.query(func.sum(Connection.duration_seconds)).filter(
        Connection.started_at >= since,
        Connection.duration_seconds.isnot(None)
    ).scalar()

    unattended_connections = db.query(func.count(Connection.id)).filter(
        Connection.started_at >= since,
        Connection.was_unattended == True
    ).scalar()

    return {
        "total_connections": total_connections or 0,
        "total_hours": round((total_duration or 0) / 3600, 2),
        "unattended_connections": unattended_connections or 0,
        "period_days": days
    }
