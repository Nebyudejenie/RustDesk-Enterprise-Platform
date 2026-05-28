#!/usr/bin/env python3
"""
RustDesk Phase 4 - REST API Backend
FastAPI application for device registry, user management, and connection logging
"""

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.database import engine, get_db, Base
from app.config import settings
from app.routers import auth, devices, connections, heartbeat, engineers, alerts, audit

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Starting RustDesk Phase 4 REST API Backend")
    Base.metadata.create_all(bind=engine)
    yield
    logger.info("🛑 Shutting down RustDesk API")

app = FastAPI(
    title="RustDesk Enterprise API",
    description="REST API for device management, user authentication, and connection auditing",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers and monitoring"""
    return {
        "status": "healthy",
        "service": "rustdesk-api",
        "version": "1.0.0"
    }

@app.get("/api/v1/info")
async def api_info():
    """API information endpoint"""
    return {
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

app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(devices.router, prefix="/api/v1", tags=["Devices"])
app.include_router(connections.router, prefix="/api/v1", tags=["Connections"])
app.include_router(heartbeat.router, prefix="/api/v1", tags=["Heartbeat"])
app.include_router(engineers.router, prefix="/api/v1", tags=["Engineers"])
app.include_router(alerts.router, prefix="/api/v1", tags=["Alerts"])
app.include_router(audit.router, prefix="/api/v1", tags=["Audit"])

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status": exc.status_code
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )
