# ProxmoxHelper PowerShell Module

## about_ProxmoxHelper

# SHORT DESCRIPTION
Cross-platform PowerShell helper script for managing Proxmox VE environments.

# LONG DESCRIPTION
The ProxmoxHelper module provides a comprehensive set of tools for managing Proxmox VE environments from any operating system. It includes functionality for VM management, SSL certificate handling, storage management, network configuration, and monitoring.

# EXAMPLES
```powershell
# Connect to Proxmox server
Connect-ProxmoxServer -Server "pve.sslgen.cam" -Username "root@pam"

# List all VMs
Get-ProxmoxVM

# Create new VM
New-ProxmoxVM -Name "test-vm" -Memory 2048 -Cores 2
```

# KEYWORDS
- Proxmox
- Virtualization
- VM Management
- SSL Certificates
- Storage Management
- Network Configuration
- Monitoring

# SEE ALSO
Online documentation: https://github.com/pdubbbbbs/proxmox-helper-script
