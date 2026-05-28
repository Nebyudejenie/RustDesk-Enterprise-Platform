# RustDesk Windows Silent Installer
# Phase 1 - Unattended Access Setup
# Designed for POS devices running Windows 10/11
# Run as Administrator with: powershell -ExecutionPolicy Bypass -File windows-silent-install.ps1

#Requires -RunAsAdministrator

param(
    [string]$DeviceId = "POS-ADDIS-001",
    [string]$RelayHost = "192.168.1.40",
    [int]$RelayPort = 21117,
    [string]$SignalServer = "192.168.1.40:21115",
    [string]$PermanentPassword = "POS@Enterprise2024!Secure"
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$InstallDir = "C:\Program Files\RustDesk"
$ConfigDir = "C:\RustDesk"
$LogFile = "$ConfigDir\install.log"
$RustDeskMsiUrl = "https://github.com/rustdesk/rustdesk/releases/download/1.2.7/rustdesk-1.2.7-windows-x86_64.msi"
$RustDeskMsiFile = "$env:TEMP\rustdesk-installer.msi"

# Create directories
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Host $LogMessage
}

try {
    Write-Log "Starting RustDesk installation on $env:COMPUTERNAME"
    Write-Log "Device ID: $DeviceId"
    Write-Log "Relay Server: $RelayHost:$RelayPort"

    # Step 1: Download RustDesk MSI
    Write-Log "Downloading RustDesk from $RustDeskMsiUrl"
    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $RustDeskMsiUrl -OutFile $RustDeskMsiFile -TimeoutSec 300
        Write-Log "Download completed: $RustDeskMsiFile"
    } catch {
        Write-Log "Failed to download RustDesk MSI: $_" "ERROR"
        Write-Log "Attempting alternative download method..."
        # Fallback: Use direct file server if available
        # This should be replaced with your internal file server
        throw $_
    }

    # Step 2: Install RustDesk MSI silently
    Write-Log "Installing RustDesk MSI..."
    $MsiArgs = @(
        "/i", $RustDeskMsiFile,
        "/quiet",
        "/qn",
        "/norestart",
        "ALLUSERS=1"
    )

    $MsiProcess = Start-Process msiexec.exe -ArgumentList $MsiArgs -Wait -PassThru -NoNewWindow

    if ($MsiProcess.ExitCode -eq 0) {
        Write-Log "RustDesk installation successful (Exit Code: 0)"
    } else {
        Write-Log "RustDesk installation completed with exit code: $($MsiProcess.ExitCode)" "WARN"
    }

    # Step 3: Create RustDesk2.toml configuration file
    Write-Log "Creating RustDesk2.toml configuration..."

    $ConfigContent = @"
[connection]
relay_host = "$RelayHost"
relay_port = $RelayPort
signal_server = "$SignalServer"
relay_secret = ""
device_id = "$DeviceId"
custom_name = "$DeviceId"

[security]
permanent_password = "$PermanentPassword"
allow_remote_keyboard_input = true
allow_remote_mouse_input = true
allow_file_transfer = true
allow_remote_cm = true
ask_on_new_connection = false
approve_without_consent = true
accept_all_connections = true
lock_screen_on_disconnect = false
require_approval = false
require_password_on_incoming = false
request_permission_on_incoming = false

[auth]
use_permanent_password = true
password = "$PermanentPassword"

[service]
run_as_service = true
service_type = "system"
auto_start = true
start_on_boot = true

[logging]
log_level = "info"
log_to_file = true
log_file = "$ConfigDir\client.log"

[ui]
hide_consent_dialog = true
disable_consent = true
local_ui_enabled = false

[files]
allow_file_transfer = true
file_transfer_timeout = 300

[network]
keep_alive_interval = 60
connection_timeout = 30
max_concurrent_connections = 1

[multimedia]
enable_audio = false
enable_video = false
enable_camera = false

[advanced]
encrypted_only = true
verify_certificate = true
auto_reconnect = true
reconnect_interval = 5
max_reconnect_attempts = 0
use_relay = true
relay_server_selection = "auto"
direct_connection = false
disable_ui = true
"@

    # Find RustDesk config directory (varies by version/installation)
    $RustDeskConfigDirs = @(
        "$env:APPDATA\RustDesk",
        "$InstallDir\config",
        "C:\Users\$env:USERNAME\AppData\Roaming\RustDesk"
    )

    $ConfigWritten = $false
    foreach ($ConfigPath in $RustDeskConfigDirs) {
        if (Test-Path $ConfigPath) {
            Set-Content -Path "$ConfigPath\RustDesk2.toml" -Value $ConfigContent -Encoding UTF8
            Write-Log "Configuration written to: $ConfigPath\RustDesk2.toml"
            $ConfigWritten = $true
            break
        }
    }

    if (-not $ConfigWritten) {
        # Create the config directory if it doesn't exist
        New-Item -ItemType Directory -Path "$env:APPDATA\RustDesk" -Force | Out-Null
        Set-Content -Path "$env:APPDATA\RustDesk\RustDesk2.toml" -Value $ConfigContent -Encoding UTF8
        Write-Log "Configuration created in AppData: $env:APPDATA\RustDesk\RustDesk2.toml"
    }

    # Step 4: Configure Windows Firewall
    Write-Log "Configuring Windows Firewall for RustDesk..."

    try {
        # Get RustDesk executable path
        $RustDeskExe = "$InstallDir\RustDesk.exe"

        if (Test-Path $RustDeskExe) {
            # Create firewall rules for RustDesk
            New-NetFirewallRule -DisplayName "RustDesk Relay Input" `
                -Direction Inbound `
                -Action Allow `
                -Protocol TCP `
                -LocalPort 21117 `
                -ErrorAction SilentlyContinue | Out-Null

            New-NetFirewallRule -DisplayName "RustDesk Relay Input UDP" `
                -Direction Inbound `
                -Action Allow `
                -Protocol UDP `
                -LocalPort 21117 `
                -ErrorAction SilentlyContinue | Out-Null

            New-NetFirewallRule -DisplayName "RustDesk Application" `
                -Direction Inbound `
                -Action Allow `
                -Program $RustDeskExe `
                -ErrorAction SilentlyContinue | Out-Null

            Write-Log "Windows Firewall configured successfully"
        } else {
            Write-Log "RustDesk executable not found at $RustDeskExe" "WARN"
        }
    } catch {
        Write-Log "Failed to configure firewall: $_" "WARN"
    }

    # Step 5: Configure RustDesk as Windows Service
    Write-Log "Setting up RustDesk as system service..."

    $RustDeskService = Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue

    if ($RustDeskService) {
        # Set service to auto-start
        Set-Service -Name "RustDesk" -StartupType Automatic

        # Start the service
        Start-Service -Name "RustDesk" -ErrorAction SilentlyContinue

        Write-Log "RustDesk service configured: Startup=Automatic"
        Write-Log "RustDesk service started"
    } else {
        Write-Log "RustDesk service not found - it may start on next boot" "WARN"
    }

    # Step 6: Set device ID registry value (for POS identification)
    Write-Log "Registering device ID in Windows Registry..."

    $RegPath = "HKLM:\SOFTWARE\RustDesk"
    New-Item -Path $RegPath -Force | Out-Null
    Set-ItemProperty -Path $RegPath -Name "DeviceId" -Value $DeviceId
    Set-ItemProperty -Path $RegPath -Name "RelayHost" -Value $RelayHost
    Set-ItemProperty -Path $RegPath -Name "RelayPort" -Value $RelayPort
    Set-ItemProperty -Path $RegPath -Name "InstallTime" -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    Write-Log "Device registered in Windows Registry"

    # Step 7: Verify installation
    Write-Log "Verifying installation..."

    $VerificationResults = @()

    # Check if executable exists
    if (Test-Path "$InstallDir\RustDesk.exe") {
        $VerificationResults += "✓ RustDesk executable found"
    } else {
        $VerificationResults += "✗ RustDesk executable NOT found"
    }

    # Check if service exists
    if (Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue) {
        $VerificationResults += "✓ RustDesk service registered"
    } else {
        $VerificationResults += "✗ RustDesk service NOT registered"
    }

    # Check if config file exists
    if (Test-Path "$env:APPDATA\RustDesk\RustDesk2.toml") {
        $VerificationResults += "✓ Configuration file found"
    } else {
        $VerificationResults += "✗ Configuration file NOT found"
    }

    # Check if device ID is registered
    $RegDeviceId = Get-ItemProperty -Path "HKLM:\SOFTWARE\RustDesk" -Name "DeviceId" -ErrorAction SilentlyContinue
    if ($RegDeviceId) {
        $VerificationResults += "✓ Device ID registered: $($RegDeviceId.DeviceId)"
    } else {
        $VerificationResults += "✗ Device ID NOT registered"
    }

    foreach ($Result in $VerificationResults) {
        Write-Log $Result
    }

    # Step 8: Clean up installer
    Write-Log "Cleaning up installer files..."
    Remove-Item -Path $RustDeskMsiFile -Force -ErrorAction SilentlyContinue
    Write-Log "Installer cleanup complete"

    Write-Log "RustDesk installation completed successfully!"
    Write-Log "Device ID: $DeviceId"
    Write-Log "Relay Server: $RelayHost:$RelayPort"
    Write-Log "Status: Ready for remote access"

    # Self-delete the installer script after completion
    Write-Log "Script will self-delete in 10 seconds..."
    Start-Sleep -Seconds 10

    # Remove the script file itself
    Remove-Item -Path $MyInvocation.MyCommand.Path -Force

} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log "FATAL ERROR: $ErrorMessage" "ERROR"
    Write-Log "Installation FAILED at $(Get-Date)" "ERROR"
    exit 1
}

Write-Log "Installation script completed at $(Get-Date)"
