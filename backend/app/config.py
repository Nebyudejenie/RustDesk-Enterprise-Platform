"""
Configuration management for RustDesk Phase 4 API
"""

import os
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://rustdesk_app:rustdesk_password@localhost:5432/rustdesk_db"
    )

    # API Configuration
    API_TITLE: str = "RustDesk Enterprise REST API"
    API_VERSION: str = "1.0.0"
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # JWT Configuration
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24

    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000"
    ]

    # Password security
    PASSWORD_MIN_LENGTH: int = 14
    PASSWORD_REQUIRE_UPPERCASE: bool = True
    PASSWORD_REQUIRE_LOWERCASE: bool = True
    PASSWORD_REQUIRE_DIGITS: bool = True
    PASSWORD_REQUIRE_SPECIAL: bool = True

    # Session
    SESSION_TIMEOUT_MINUTES: int = 30
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_DURATION_MINUTES: int = 15

    # Rate limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_REQUESTS: int = 1000
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    # Heartbeat
    HEARTBEAT_INTERVAL_SECONDS: int = 60
    HEARTBEAT_TIMEOUT_SECONDS: int = 120
    HEARTBEAT_RETENTION_DAYS: int = 30

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "/var/log/rustdesk-api.log"

    # RustDesk Integration
    HBBS_HOST: str = os.getenv("HBBS_HOST", "localhost")
    HBBS_PORT: int = int(os.getenv("HBBS_PORT", "21115"))
    HBBR_HOST: str = os.getenv("HBBR_HOST", "localhost")
    HBBR_PORT: int = int(os.getenv("HBBR_PORT", "21119"))

    # Feature flags
    FEATURE_MFA: bool = True
    FEATURE_AUDIT_LOGGING: bool = True
    FEATURE_DEVICE_HEARTBEAT: bool = True
    FEATURE_ALERTS: bool = True

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
