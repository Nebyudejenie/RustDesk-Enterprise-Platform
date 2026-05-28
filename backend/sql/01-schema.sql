-- ============================================================================
-- RustDesk Phase 4 - PostgreSQL Schema
-- Device Registry, User Management, Audit Logging, Heartbeats
-- ============================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. LOCATIONS & BRANCHES (Multi-location hierarchy)
-- ============================================================================

CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    location_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    city VARCHAR(100),
    country VARCHAR(100),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX idx_location_id ON locations(location_id);
CREATE INDEX idx_location_active ON locations(is_active);

CREATE TABLE branches (
    id SERIAL PRIMARY KEY,
    branch_id VARCHAR(50) UNIQUE NOT NULL,
    location_id INTEGER REFERENCES locations(id),
    name VARCHAR(255) NOT NULL,
    manager_name VARCHAR(255),
    manager_phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX idx_branch_id ON branches(branch_id);
CREATE INDEX idx_branch_location ON branches(location_id);
CREATE INDEX idx_branch_active ON branches(is_active);

-- ============================================================================
-- 2. DEVICES (POS devices registry)
-- ============================================================================

CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(100) UNIQUE NOT NULL,  -- e.g., POS-ADDIS-001
    rustdesk_id VARCHAR(255) UNIQUE,         -- RustDesk internal ID
    branch_id INTEGER REFERENCES branches(id),
    location_id INTEGER REFERENCES locations(id),
    device_type VARCHAR(50),                 -- POS, Kiosk, Signage, etc.
    os_version VARCHAR(100),                 -- Windows 10, Ubuntu 24.04, etc.
    rustdesk_version VARCHAR(50),
    permanent_password_hash VARCHAR(255),    -- Bcrypt hashed
    hostname VARCHAR(255),
    ip_address INET,
    last_ip INET,
    mac_address VARCHAR(17),
    status VARCHAR(20) DEFAULT 'offline',    -- online, offline, maintenance, error
    last_seen_at TIMESTAMP,
    registered_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    tags JSONB DEFAULT '{}',                 -- Custom tags for grouping
    metadata JSONB DEFAULT '{}',             -- Additional device info
    is_active BOOLEAN DEFAULT true,
    maintenance_mode BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_device_id ON devices(device_id);
CREATE INDEX idx_rustdesk_id ON devices(rustdesk_id);
CREATE INDEX idx_device_branch ON devices(branch_id);
CREATE INDEX idx_device_location ON devices(location_id);
CREATE INDEX idx_device_status ON devices(status);
CREATE INDEX idx_device_last_seen ON devices(last_seen_at);
CREATE INDEX idx_device_active ON devices(is_active);

-- ============================================================================
-- 3. ENGINEERS (Support staff)
-- ============================================================================

CREATE TABLE engineers (
    id SERIAL PRIMARY KEY,
    engineer_id VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    password_hash VARCHAR(255),              -- Bcrypt hashed
    role VARCHAR(50) DEFAULT 'support',      -- admin, support, auditor, manager
    branch_ids INTEGER[] DEFAULT '{}',       -- Branches engineer can access
    is_active BOOLEAN DEFAULT true,
    mfa_secret VARCHAR(255),                 -- TOTP secret
    last_login TIMESTAMP,
    login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_engineer_id ON engineers(engineer_id);
CREATE INDEX idx_engineer_email ON engineers(email);
CREATE INDEX idx_engineer_role ON engineers(role);
CREATE INDEX idx_engineer_active ON engineers(is_active);

-- ============================================================================
-- 4. CONNECTIONS (Audit log of all remote access)
-- ============================================================================

CREATE TABLE connections (
    id SERIAL PRIMARY KEY,
    connection_id UUID DEFAULT gen_random_uuid() UNIQUE,
    engineer_id INTEGER REFERENCES engineers(id),
    device_id INTEGER REFERENCES devices(id),
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    source_ip INET,
    source_hostname VARCHAR(255),
    session_key VARCHAR(255),
    disconnect_reason VARCHAR(100),         -- normal, timeout, network_error, user_disconnect
    was_unattended BOOLEAN DEFAULT false,
    files_transferred INT DEFAULT 0,
    actions_performed JSONB DEFAULT '{}',   -- Log of actions taken
    connection_quality VARCHAR(50),          -- good, fair, poor
    bandwidth_used_mb DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_connection_engineer ON connections(engineer_id);
CREATE INDEX idx_connection_device ON connections(device_id);
CREATE INDEX idx_connection_started ON connections(started_at);
CREATE INDEX idx_connection_date ON connections(DATE(started_at));

-- ============================================================================
-- 5. DEVICE HEARTBEATS (Real-time device health monitoring)
-- ============================================================================

CREATE TABLE device_heartbeats (
    id SERIAL PRIMARY KEY,
    device_id INTEGER REFERENCES devices(id),
    timestamp TIMESTAMP DEFAULT NOW(),
    cpu_percent DECIMAL(5, 2),
    ram_percent DECIMAL(5, 2),
    disk_percent DECIMAL(5, 2),
    network_status VARCHAR(50),              -- connected, disconnected, poor_signal
    temperature_celsius DECIMAL(5, 2),
    processes_count INTEGER,
    memory_available_mb INTEGER,
    disk_available_gb DECIMAL(10, 2),
    rustdesk_memory_mb INTEGER,
    rustdesk_cpu_percent DECIMAL(5, 2),
    custom_metrics JSONB DEFAULT '{}'       -- Custom monitoring data
);

CREATE INDEX idx_heartbeat_device ON device_heartbeats(device_id);
CREATE INDEX idx_heartbeat_timestamp ON device_heartbeats(timestamp);
CREATE INDEX idx_heartbeat_date ON device_heartbeats(DATE(timestamp));

-- Auto-cleanup old heartbeats (keep 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_heartbeats() RETURNS void AS $$
BEGIN
    DELETE FROM device_heartbeats WHERE timestamp < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 6. ALERTS (Device health alerts)
-- ============================================================================

CREATE TABLE alerts (
    id SERIAL PRIMARY KEY,
    alert_id UUID DEFAULT gen_random_uuid() UNIQUE,
    device_id INTEGER REFERENCES devices(id),
    alert_type VARCHAR(100),                 -- cpu_high, ram_high, disk_full, offline, error
    severity VARCHAR(20) DEFAULT 'warning',  -- info, warning, critical
    message TEXT,
    metric_value DECIMAL(10, 2),
    threshold_value DECIMAL(10, 2),
    triggered_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolved_by INTEGER REFERENCES engineers(id),
    acknowledged_at TIMESTAMP,
    acknowledged_by INTEGER REFERENCES engineers(id),
    is_resolved BOOLEAN DEFAULT false,
    is_acknowledged BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_alert_device ON alerts(device_id);
CREATE INDEX idx_alert_severity ON alerts(severity);
CREATE INDEX idx_alert_triggered ON alerts(triggered_at);
CREATE INDEX idx_alert_resolved ON alerts(is_resolved);

-- ============================================================================
-- 7. SESSIONS (User login sessions for API)
-- ============================================================================

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    session_id UUID DEFAULT gen_random_uuid() UNIQUE,
    engineer_id INTEGER REFERENCES engineers(id),
    access_token VARCHAR(500),
    refresh_token VARCHAR(500),
    token_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    is_valid BOOLEAN DEFAULT true
);

CREATE INDEX idx_session_engineer ON sessions(engineer_id);
CREATE INDEX idx_session_token ON sessions(access_token);
CREATE INDEX idx_session_valid ON sessions(is_valid);

-- ============================================================================
-- 8. API KEYS (For device registration and agent API access)
-- ============================================================================

CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    key_id UUID DEFAULT gen_random_uuid() UNIQUE,
    key_hash VARCHAR(255) UNIQUE NOT NULL,  -- SHA256 hash for security
    name VARCHAR(255),
    description TEXT,
    created_by INTEGER REFERENCES engineers(id),
    scopes VARCHAR(500)[],                  -- Permissions: devices:read, devices:write, etc.
    rate_limit INT DEFAULT 1000,            -- Requests per minute
    last_used_at TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_api_key_hash ON api_keys(key_hash);
CREATE INDEX idx_api_key_active ON api_keys(is_active);

-- ============================================================================
-- 9. AUDIT LOG (All administrative actions)
-- ============================================================================

CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100),                    -- create, update, delete, login, connect, etc.
    actor_type VARCHAR(50),                 -- engineer, system, ai_agent
    actor_id VARCHAR(255),
    resource_type VARCHAR(100),             -- device, engineer, branch, etc.
    resource_id VARCHAR(255),
    changes JSONB,                          -- What changed
    old_values JSONB,                       -- Previous values
    new_values JSONB,                       -- New values
    ip_address INET,
    user_agent TEXT,
    status VARCHAR(50) DEFAULT 'success',   -- success, failure
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_action ON audit_log(action);
CREATE INDEX idx_audit_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_resource ON audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_created ON audit_log(created_at);
CREATE INDEX idx_audit_date ON audit_log(DATE(created_at));

-- ============================================================================
-- 10. NOTIFICATIONS (Alerts and messages for engineers)
-- ============================================================================

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    notification_id UUID DEFAULT gen_random_uuid() UNIQUE,
    engineer_id INTEGER REFERENCES engineers(id),
    alert_id INTEGER REFERENCES alerts(id),
    title VARCHAR(255),
    message TEXT,
    notification_type VARCHAR(100),         -- alert, connection, system, info
    priority VARCHAR(20) DEFAULT 'normal',  -- low, normal, high, critical
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '30 days'
);

CREATE INDEX idx_notification_engineer ON notifications(engineer_id);
CREATE INDEX idx_notification_read ON notifications(is_read);
CREATE INDEX idx_notification_created ON notifications(created_at);

-- ============================================================================
-- 11. DEVICE GROUPS (For organizing and managing device access)
-- ============================================================================

CREATE TABLE device_groups (
    id SERIAL PRIMARY KEY,
    group_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    branch_id INTEGER REFERENCES branches(id),
    device_ids INTEGER[] DEFAULT '{}',
    created_by INTEGER REFERENCES engineers(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_group_id ON device_groups(group_id);
CREATE INDEX idx_group_branch ON device_groups(branch_id);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Active devices summary
CREATE VIEW v_active_devices AS
SELECT
    d.device_id,
    d.hostname,
    d.ip_address,
    l.name as location,
    b.name as branch,
    d.status,
    d.last_seen_at,
    d.rustdesk_version
FROM devices d
LEFT JOIN locations l ON d.location_id = l.id
LEFT JOIN branches b ON d.branch_id = b.id
WHERE d.is_active = true
ORDER BY d.last_seen_at DESC;

-- Recent connections
CREATE VIEW v_recent_connections AS
SELECT
    c.connection_id,
    e.full_name as engineer,
    d.device_id,
    c.started_at,
    c.ended_at,
    c.duration_seconds,
    c.was_unattended,
    c.disconnect_reason
FROM connections c
JOIN engineers e ON c.engineer_id = e.id
JOIN devices d ON c.device_id = d.id
WHERE c.started_at > NOW() - INTERVAL '7 days'
ORDER BY c.started_at DESC;

-- Device health status
CREATE VIEW v_device_health AS
SELECT
    d.device_id,
    d.hostname,
    dh.cpu_percent,
    dh.ram_percent,
    dh.disk_percent,
    dh.network_status,
    dh.timestamp,
    CASE
        WHEN dh.cpu_percent > 90 THEN 'critical'
        WHEN dh.cpu_percent > 80 THEN 'warning'
        WHEN dh.ram_percent > 90 THEN 'critical'
        WHEN dh.ram_percent > 80 THEN 'warning'
        WHEN dh.disk_percent > 95 THEN 'critical'
        WHEN dh.disk_percent > 85 THEN 'warning'
        ELSE 'healthy'
    END as health_status
FROM devices d
LEFT JOIN LATERAL (
    SELECT * FROM device_heartbeats
    WHERE device_id = d.id
    ORDER BY timestamp DESC
    LIMIT 1
) dh ON true
WHERE d.is_active = true
ORDER BY dh.timestamp DESC NULLS LAST;

-- ============================================================================
-- GRANTS (Role-based database access)
-- ============================================================================

-- Create read-only role for monitoring/analytics
CREATE ROLE rustdesk_readonly;
GRANT CONNECT ON DATABASE rustdesk_db TO rustdesk_readonly;
GRANT USAGE ON SCHEMA public TO rustdesk_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rustdesk_readonly;

-- Create application role
CREATE ROLE rustdesk_app;
GRANT CONNECT ON DATABASE rustdesk_db TO rustdesk_app;
GRANT USAGE ON SCHEMA public TO rustdesk_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rustdesk_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rustdesk_app;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
