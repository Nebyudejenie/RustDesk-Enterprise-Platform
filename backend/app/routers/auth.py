"""
Authentication endpoints for RustDesk API
"""

from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from passlib.context import CryptContext
import jwt
import logging

from app.database import get_db
from app.config import settings
from app.models import Engineer, Session as SessionModel, AuditLog
from app.schemas import LoginRequest, LoginResponse, TokenRefreshRequest

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(engineer_id: int, expires_delta: timedelta = None) -> str:
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS)

    to_encode = {
        "sub": str(engineer_id),
        "exp": expire,
        "iat": datetime.utcnow()
    }

    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt

@router.post("/login", response_model=LoginResponse)
async def login(
    request: Request,
    login_data: LoginRequest,
    db: Session = Depends(get_db)
):
    """Login endpoint for engineers"""
    engineer = db.query(Engineer).filter(Engineer.email == login_data.email).first()

    if not engineer or not verify_password(login_data.password, engineer.password_hash or ""):
        log_audit(
            db,
            action="login",
            actor_id=login_data.email,
            resource_type="engineer",
            status="failure",
            ip_address=request.client.host,
            error_message="Invalid credentials"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    if engineer.locked_until and engineer.locked_until > datetime.utcnow():
        log_audit(
            db,
            action="login",
            actor_id=engineer.engineer_id,
            resource_type="engineer",
            status="failure",
            ip_address=request.client.host,
            error_message="Account locked"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is locked. Try again later."
        )

    if not engineer.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Engineer account is inactive"
        )

    access_token = create_access_token(engineer.id)
    refresh_token = create_access_token(
        engineer.id,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )

    session = SessionModel(
        engineer_id=engineer.id,
        access_token=access_token,
        refresh_token=refresh_token,
        token_expires_at=datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS),
        ip_address=request.client.host,
        user_agent=request.headers.get("user-agent", ""),
        is_valid=True
    )
    db.add(session)
    engineer.last_login = datetime.utcnow()
    engineer.login_attempts = 0
    db.commit()

    log_audit(
        db,
        action="login",
        actor_id=engineer.engineer_id,
        resource_type="engineer",
        status="success",
        ip_address=request.client.host
    )

    logger.info(f"Engineer {engineer.engineer_id} logged in successfully")

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_EXPIRATION_HOURS * 3600
    )

@router.post("/refresh")
async def refresh_token(
    token_data: TokenRefreshRequest,
    db: Session = Depends(get_db)
):
    """Refresh access token"""
    try:
        payload = jwt.decode(
            token_data.refresh_token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        engineer_id = int(payload.get("sub"))
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )

    engineer = db.query(Engineer).filter(Engineer.id == engineer_id).first()
    if not engineer or not engineer.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Engineer not found or inactive"
        )

    new_access_token = create_access_token(engineer.id)
    new_refresh_token = create_access_token(
        engineer.id,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )

    session = db.query(SessionModel).filter(
        SessionModel.refresh_token == token_data.refresh_token
    ).first()
    if session:
        session.access_token = new_access_token
        session.refresh_token = new_refresh_token
        session.token_expires_at = datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS)
        db.commit()

    return LoginResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.JWT_EXPIRATION_HOURS * 3600
    )

@router.post("/logout")
async def logout(
    request: Request,
    db: Session = Depends(get_db),
    current_engineer_id: int = Depends(get_current_engineer_id)
):
    """Logout endpoint"""
    auth_header = request.headers.get("authorization", "")
    token = auth_header.replace("Bearer ", "")

    session = db.query(SessionModel).filter(
        SessionModel.access_token == token
    ).first()

    if session:
        session.is_valid = False
        db.commit()

    log_audit(
        db,
        action="logout",
        actor_id=str(current_engineer_id),
        resource_type="session",
        status="success"
    )

    return {"message": "Logged out successfully"}

@router.post("/validate-token")
async def validate_token(
    request: Request,
    db: Session = Depends(get_db)
):
    """Validate JWT token"""
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )

    token = auth_header.replace("Bearer ", "")

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        engineer_id = int(payload.get("sub"))
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

    return {"valid": True, "engineer_id": engineer_id}

def get_current_engineer_id(request: Request) -> int:
    """Extract and validate engineer ID from JWT token"""
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )

    token = auth_header.replace("Bearer ", "")

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        engineer_id = int(payload.get("sub"))
        return engineer_id
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

def log_audit(
    db: Session,
    action: str,
    actor_id: str,
    resource_type: str,
    status: str = "success",
    ip_address: str = None,
    error_message: str = None,
    resource_id: str = None,
    old_values: dict = None,
    new_values: dict = None
):
    """Helper to log audit events"""
    audit_log = AuditLog(
        action=action,
        actor_type="engineer",
        actor_id=actor_id,
        resource_type=resource_type,
        resource_id=resource_id,
        status=status,
        ip_address=ip_address,
        error_message=error_message,
        old_values=old_values,
        new_values=new_values
    )
    db.add(audit_log)
    db.commit()
