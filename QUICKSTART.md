# Quick Start Guide

## Installation

### Prerequisites
- PowerShell 7.0 or later
- Proxmox VE server access
- Administrative privileges (for certain operations)

### Install from PowerShell Gallery
```powershell
# Install the module
Install-Module -Name ProxmoxHelper -Scope CurrentUser

# Import the module
Import-Module ProxmoxHelper
```

### Install from GitHub
```powershell
# Clone the repository
git clone https://github.com/pdubbbbbs/proxmox-helper-script.git

# Navigate to the directory
cd proxmox-helper-script

# Import the module
Import-Module ./ProxmoxHelper.psd1
```

## Initial Setup

### Basic Configuration
```powershell
# Create default configuration
Set-ProxmoxConfig -Server "pve.sslgen.cam" `
                  -Port 8006 `
                  -Username "root@pam"

# Test the configuration
Test-ProxmoxConfig
```

### Connect to Proxmox
```powershell
# Connect using default configuration
Connect-ProxmoxServer

# Verify connection
Get-ProxmoxClusterStatus
```

## Common Tasks

### VM Management
```powershell
# List all VMs
Get-ProxmoxVM

# Create a new VM
New-ProxmoxVM -Name "test-vm" -Memory 2048 -Cores 2

# Start a VM
Start-ProxmoxVM -VMID 100
```

### SSL Certificate Management
```powershell
# Generate and install SSL certificate
New-ProxmoxSSLCertificate -Domain "pve.sslgen.cam" -Type SelfSigned
Install-ProxmoxSSLCertificate -Domain "pve.sslgen.cam"
```

### Monitoring
```powershell
# Check system health
Test-ProxmoxHealth -IncludeStorage -IncludeNetwork

# Monitor VM metrics
Watch-ProxmoxMetrics -VMID 100 -MetricType all
```

## Troubleshooting

### Common Issues

1. Connection Failed
```powershell
# Check server availability
Test-Connection -ComputerName "pve.sslgen.cam" -Port 8006

# Verify credentials
Test-ProxmoxConfig
```

2. SSL Certificate Issues
```powershell
# Test SSL certificate
Test-SSLCertificate -Domain "pve.sslgen.cam"
```

3. Permission Issues
```powershell
# Check if running as administrator
Test-Administrator
```

### Logging

Logs are stored in the following location:
- Windows: `$env:USERPROFILE\.proxmoxhelper\logs`
- Linux/macOS: `$HOME/.proxmoxhelper/logs`

To change log level:
```powershell
Set-ProxmoxConfig -LogLevel "Debug"
```

## Next Steps

1. Review the [examples](examples/README.md) for more advanced usage
2. Configure automated backups
3. Set up monitoring and alerts
4. Review best practices

For more detailed information, visit the [GitHub repository](https://github.com/pdubbbbbs/proxmox-helper-script).
