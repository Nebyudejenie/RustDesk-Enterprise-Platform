"""
Engineer management endpoints
"""

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
import logging

from app.database import get_db
from app.models import Engineer, AuditLog
from app.schemas import EngineerCreate, EngineerUpdate, EngineerResponse
from app.routers.auth import get_current_engineer_id, hash_password, log_audit

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/engineers", tags=["engineers"])

@router.post("", response_model=EngineerResponse, status_code=status.HTTP_201_CREATED)
async def create_engineer(
    engineer_data: EngineerCreate,
    db: Session = Depends(get_db),
    admin_id: int = Depends(get_current_engineer_id)
):
    """Create a new engineer (admin only)"""
    admin = db.query(Engineer).filter(Engineer.id == admin_id).first()
    if not admin or admin.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can create engineers"
        )

    existing = db.query(Engineer).filter(Engineer.email == engineer_data.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Engineer with this email already exists"
        )

    engineer = Engineer(
        engineer_id=engineer_data.email.split("@")[0],
        full_name=engineer_data.full_name,
        email=engineer_data.email,
        phone=engineer_data.phone,
        password_hash=hash_password(engineer_data.password),
        role=engineer_data.role,
        branch_ids=engineer_data.branch_ids or [],
        is_active=True
    )

    db.add(engineer)
    db.commit()
    db.refresh(engineer)

    log_audit(
        db,
        action="create",
        actor_id=str(admin_id),
        resource_type="engineer",
        resource_id=str(engineer.id),
        status="success",
        new_values={"email": engineer.email, "role": engineer.role}
    )

    logger.info(f"Engineer {engineer.email} created by {admin.email}")
    return engineer

@router.get("", response_model=List[EngineerResponse])
async def list_engineers(
    db: Session = Depends(get_db),
    admin_id: int = Depends(get_current_engineer_id),
    role_filter: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    """List all engineers"""
    query = db.query(Engineer)

    if role_filter:
        query = query.filter(Engineer.role == role_filter)

    engineers = query.order_by(Engineer.created_at.desc()).offset(skip).limit(limit).all()
    return engineers

@router.get("/{engineer_id}", response_model=EngineerResponse)
async def get_engineer(
    engineer_id: int,
    db: Session = Depends(get_db),
    current_engineer_id: int = Depends(get_current_engineer_id)
):
    """Get engineer details"""
    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()

    if not engineer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Engineer not found"
        )

    if engineer_id != current_engineer_id:
        current = db.query(Engineer).filter(Engineer.id == current_engineer_id).first()
        if current.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot view other engineers' details"
            )

    return engineer

@router.patch("/{engineer_id}", response_model=EngineerResponse)
async def update_engineer(
    engineer_id: int,
    update_data: EngineerUpdate,
    db: Session = Depends(get_db),
    admin_id: int = Depends(get_current_engineer_id)
):
    """Update engineer information (admin only)"""
    admin = db.query(Engineer).filter(Engineer.id == admin_id).first()
    if admin.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can update engineers"
        )

    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if not engineer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Engineer not found"
        )

    old_values = {
        "role": engineer.role,
        "is_active": engineer.is_active,
        "branch_ids": engineer.branch_ids
    }

    if update_data.full_name:
        engineer.full_name = update_data.full_name
    if update_data.phone:
        engineer.phone = update_data.phone
    if update_data.role:
        engineer.role = update_data.role
    if update_data.branch_ids is not None:
        engineer.branch_ids = update_data.branch_ids
    if update_data.is_active is not None:
        engineer.is_active = update_data.is_active

    engineer.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(engineer)

    log_audit(
        db,
        action="update",
        actor_id=str(admin_id),
        resource_type="engineer",
        resource_id=str(engineer.id),
        status="success",
        old_values=old_values,
        new_values=update_data.dict(exclude_unset=True)
    )

    logger.info(f"Engineer {engineer.email} updated by {admin.email}")
    return engineer

@router.post("/{engineer_id}/deactivate", response_model=dict)
async def deactivate_engineer(
    engineer_id: int,
    db: Session = Depends(get_db),
    admin_id: int = Depends(get_current_engineer_id)
):
    """Deactivate an engineer account"""
    admin = db.query(Engineer).filter(Engineer.id == admin_id).first()
    if admin.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can deactivate engineers"
        )

    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if not engineer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Engineer not found"
        )

    engineer.is_active = False
    engineer.updated_at = datetime.utcnow()
    db.commit()

    log_audit(
        db,
        action="deactivate",
        actor_id=str(admin_id),
        resource_type="engineer",
        resource_id=str(engineer.id),
        status="success"
    )

    logger.info(f"Engineer {engineer.email} deactivated by {admin.email}")

    return {"message": f"Engineer {engineer.email} has been deactivated"}
