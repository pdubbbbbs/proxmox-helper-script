# ProxmoxHelper Module
## Description
Cross-platform PowerShell helper script for managing Proxmox VE environments.

## Installation
```powershell
Install-Module -Name ProxmoxHelper -Scope CurrentUser
```

## Getting Started
1. Import the module:
```powershell
Import-Module ProxmoxHelper
```

2. Connect to your Proxmox server:
```powershell
Connect-ProxmoxServer -Server "pve.sslgen.cam" -Username "root@pam"
```

## Cmdlets
### Connection Management
- Connect-ProxmoxServer
- Disconnect-ProxmoxServer

### VM Management
- Get-ProxmoxVM
- New-ProxmoxVM
- Remove-ProxmoxVM
- Start-ProxmoxVM
- Stop-ProxmoxVM
- Restart-ProxmoxVM

### SSL Management
- New-ProxmoxSSLCertificate
- Install-ProxmoxSSLCertificate
- Test-SSLCertificate

### Storage Management
- Get-ProxmoxStorage
- New-ProxmoxBackup
- Get-ProxmoxBackup
- Remove-ProxmoxBackup

### Network Management
- Get-ProxmoxNetwork
- New-ProxmoxBridge
- Remove-ProxmoxBridge

### Monitoring
- Get-ProxmoxClusterStatus
- Get-ProxmoxNodeMetrics
- Test-ProxmoxHealth
- Watch-ProxmoxMetrics

## Examples
See the [examples](../examples/README.md) directory for detailed usage examples.

## Contributing
Please read our [Contributing Guide](../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
