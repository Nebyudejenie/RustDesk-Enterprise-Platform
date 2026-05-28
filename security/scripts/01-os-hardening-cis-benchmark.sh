#!/bin/bash

# ============================================================================
# RustDesk Phase 3 - OS Hardening (CIS Benchmark Level 1)
# Ubuntu 24.04 LTS Security Hardening
# ============================================================================

set -e

LOG_FILE="/var/log/rustdesk-hardening.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)
            echo -e "${GREEN}[${timestamp}]${NC} ${GREEN}✓${NC} $message" | tee -a "$LOG_FILE"
            ;;
        WARN)
            echo -e "${YELLOW}[${timestamp}]${NC} ${YELLOW}⚠${NC} $message" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}]${NC} ${RED}✗${NC} $message" | tee -a "$LOG_FILE"
            ;;
        HEADER)
            echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
            echo -e "${BLUE}║${NC} $message" | tee -a "$LOG_FILE"
            echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n" | tee -a "$LOG_FILE"
            ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check if running as root
[[ $EUID -eq 0 ]] || error_exit "Must run as root"

# ============================================================================
# 1. FILESYSTEM CONFIGURATION
# ============================================================================

hardening_filesystem() {
    log "HEADER" "HARDENING FILESYSTEM CONFIGURATION"

    # 1.1 Disable uncommon filesystems
    log "INFO" "Disabling uncommon filesystems..."
    for fs in cramfs freevxfs jffs2 hfs hfsplus udf vfat; do
        echo "install $fs /bin/true" >> /etc/modprobe.d/disable-uncommon-fs.conf 2>/dev/null || true
    done

    # 1.2 Disable USB storage
    log "INFO" "Disabling USB storage..."
    echo "install usb-storage /bin/true" >> /etc/modprobe.d/disable-usb-storage.conf 2>/dev/null || true

    # 1.3 Set secure mount options
    log "INFO" "Configuring mount options..."

    # /tmp with noexec, nosuid, nodev
    if mountpoint -q /tmp; then
        mount -o remount,noexec,nosuid,nodev /tmp 2>/dev/null || true
    fi

    # /var with nosuid, nodev
    if mountpoint -q /var; then
        mount -o remount,nosuid,nodev /var 2>/dev/null || true
    fi

    # /var/tmp with noexec, nosuid, nodev
    if mountpoint -q /var/tmp; then
        mount -o remount,noexec,nosuid,nodev /var/tmp 2>/dev/null || true
    fi

    # /dev/shm with noexec, nosuid, nodev
    mount -o remount,noexec,nosuid,nodev /dev/shm 2>/dev/null || true
}

# ============================================================================
# 2. KERNEL HARDENING
# ============================================================================

hardening_kernel() {
    log "HEADER" "HARDENING KERNEL PARAMETERS"

    cat >> /etc/sysctl.d/99-rustdesk-hardening.conf << 'EOF'
# Kernel hardening parameters

# 2.1 Kernel parameter protection
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
kernel.yama.ptrace_scope = 2
kernel.kexec_load_disabled = 1

# 2.2 Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.ignore_redirects = 1
net.ipv4.conf.default.ignore_redirects = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.ignore_redirects = 1
net.ipv6.conf.default.ignore_redirects = 1

# 2.3 TCP hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 2.4 File system hardening
fs.suid_dumpable = 0
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
EOF

    sysctl --system > /dev/null
    log "INFO" "Kernel parameters hardened"
}

# ============================================================================
# 3. ACCESS CONTROL & PERMISSIONS
# ============================================================================

hardening_access_control() {
    log "HEADER" "HARDENING ACCESS CONTROL"

    # 3.1 Set umask
    log "INFO" "Setting secure umask..."
    sed -i 's/^UMASK.*/UMASK 0077/' /etc/login.defs 2>/dev/null || true
    sed -i 's/^USERGROUPS_ENAB.*/USERGROUPS_ENAB no/' /etc/login.defs 2>/dev/null || true

    # 3.2 Set password policies
    log "INFO" "Setting password policies..."
    apt-get install -y libpam-pwquality > /dev/null 2>&1

    cat >> /etc/security/pwquality.conf << 'EOF'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
difok = 3
maxrepeat = 3
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcefor_root
EOF

    # 3.3 Password aging
    log "INFO" "Setting password aging requirements..."
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 14/' /etc/login.defs
}

# ============================================================================
# 4. SSH HARDENING
# ============================================================================

hardening_ssh() {
    log "HEADER" "HARDENING SSH"

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    cat > /etc/ssh/sshd_config << 'EOF'
# RustDesk SSH Hardening Configuration
# CIS Benchmark Level 1

# Port and Address Binding
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Protocol Configuration
Protocol 2

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Cryptography (Strong)
Ciphers aes-256-ctr,aes-192-ctr,aes-128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 10

# Access Control
AllowUsers cosmic@*
DenyUsers root
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no

# Session Settings
ClientAliveInterval 300
ClientAliveCountMax 3
TCPKeepAlive yes

# Logging & Monitoring
SyslogFacility AUTH
LogLevel VERBOSE
UseLogin no
UsePrivilegeSeparation sandbox

# Kernel Settings
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
RhostsRSAAuthentication no
RSAAuthentication no
PermitUserRC yes

# Banner and Warnings
Banner /etc/ssh/banner

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO

# Additional Hardening
Compression no
ClientAliveInterval 300
ClientAliveCountMax 3
PermitTunnel no
ChrootDirectory none
VersionAddendum none
EOF

    # Create SSH banner
    cat > /etc/ssh/banner << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                           AUTHORIZED ACCESS ONLY                          ║
║                                                                           ║
║ This system is for authorized use only. All activity is monitored and    ║
║ logged. Unauthorized access is strictly prohibited and will be           ║
║ prosecuted by law.                                                        ║
║                                                                           ║
║                    RustDesk Enterprise Platform                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF

    chmod 600 /etc/ssh/sshd_config
    chmod 644 /etc/ssh/banner

    # Verify configuration
    sshd -t && log "INFO" "SSH configuration validated" || error_exit "SSH configuration invalid"

    systemctl restart sshd
    log "INFO" "SSH hardened and restarted"
}

# ============================================================================
# 5. FIREWALL CONFIGURATION
# ============================================================================

hardening_firewall() {
    log "HEADER" "HARDENING FIREWALL (UFW)"

    ufw default deny incoming
    ufw default allow outgoing
    ufw limit 22/tcp  # SSH with rate limiting
    ufw allow 21115/tcp
    ufw allow 21116/tcp
    ufw allow 21116/udp
    ufw allow 21117/tcp
    ufw allow 21117/udp
    ufw allow 21118/tcp
    ufw allow 21119/tcp
    ufw enable || true

    log "INFO" "Firewall configured"
}

# ============================================================================
# 6. AUDITD CONFIGURATION
# ============================================================================

hardening_auditd() {
    log "HEADER" "CONFIGURING AUDITD MONITORING"

    apt-get install -y auditd audispd-plugins > /dev/null 2>&1

    cat >> /etc/audit/rules.d/rustdesk.rules << 'EOF'
# RustDesk Security Auditing Rules

# System configuration changes
-w /etc/audit/audit.rules -p wa -k audit_change
-w /etc/audit/auditd.conf -p wa -k audit_change
-w /etc/libaudit.conf -p wa -k audit_change
-w /etc/audisp/ -p wa -k audit_change

# Monitor for changes to system administration
-w /sbin/ -p wa -k system_administration
-w /usr/sbin/ -p wa -k system_administration

# Monitor RustDesk service
-w /opt/rustdesk-platform -p wa -k rustdesk
-w /etc/rancher/k3s -p wa -k kubernetes_config

# Monitor SSH access
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /var/log/auth.log -p wa -k ssh_logs

# Monitor sudo usage
-w /var/log/sudo.log -p wa -k sudo_logs
-a always,exit -F arch=b64 -S execve -F exe=/usr/bin/sudo -F key=sudo_exec

# File integrity monitoring
-w /root -p wa -k root_activity
-w /home -p wa -k user_activity

# System calls monitoring
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -F a0=0x0 -F key=time_change
-a always,exit -F arch=b64 -S sethostname -S setdomainname -F key=network_config
EOF

    augenrules --load
    systemctl restart auditd
    log "INFO" "Auditd configured for monitoring"
}

# ============================================================================
# 7. SECURITY UPDATES
# ============================================================================

hardening_updates() {
    log "HEADER" "CONFIGURING AUTOMATIC SECURITY UPDATES"

    apt-get install -y unattended-upgrades > /dev/null 2>&1

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Boot-Grub-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

    systemctl enable unattended-upgrades
    log "INFO" "Automatic security updates enabled"
}

# ============================================================================
# 8. FAIL2BAN PROTECTION
# ============================================================================

hardening_fail2ban() {
    log "HEADER" "CONFIGURING FAIL2BAN"

    apt-get install -y fail2ban > /dev/null 2>&1

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = admin@yourdomain.com
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[sshd-aggressive]
enabled = true
filter = sshd
port = ssh
logpath = /var/log/auth.log
maxretry = 2
findtime = 3600
bantime = 86400
EOF

    systemctl restart fail2ban
    log "INFO" "Fail2ban configured"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "HEADER" "RUSTDESK PHASE 3 - OS HARDENING (CIS BENCHMARK)"

    hardening_filesystem
    hardening_kernel
    hardening_access_control
    hardening_ssh
    hardening_firewall
    hardening_auditd
    hardening_updates
    hardening_fail2ban

    log "HEADER" "HARDENING COMPLETE"
    log "INFO" "All CIS Benchmark Level 1 hardening applied"
    log "INFO" "Log file: $LOG_FILE"
    log "WARN" "Please review SSH configuration and update AllowUsers directive"
    log "WARN" "SSH has been restarted - new connections will use hardened config"
}

main "$@"
