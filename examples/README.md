# Proxmox Helper Script Examples

## Basic Usage

### Connect to Proxmox Server
```powershell
# Using default configuration
Connect-ProxmoxServer -Server 'pve.sslgen.cam' -Username 'root@pam'

# Using saved configuration
Connect-ProxmoxServer -ConfigName 'example-config'
```

### VM Management
```powershell
# List all VMs
Get-ProxmoxVM

# Create new VM
New-ProxmoxVM -Name 'test-vm' -Memory 2048 -Cores 2

# Start/Stop VM
Start-ProxmoxVM -VMID 100
Stop-ProxmoxVM -VMID 100 -Force

# Create backup
New-ProxmoxBackup -VMID 100 -Storage 'local' -Compress
```

### SSL Certificate Management
```powershell
# Generate self-signed certificate
New-ProxmoxSSLCertificate -Domain 'pve.sslgen.cam' -Type SelfSigned

# Install certificate
Install-ProxmoxSSLCertificate -Domain 'pve.sslgen.cam' -CertPath './certs'
```

### Monitoring
```powershell
# Get cluster status
Get-ProxmoxClusterStatus -IncludeResources

# Monitor VM metrics
Watch-ProxmoxMetrics -VMID 100 -MetricType all -RefreshInterval 5

# Run health check
Test-ProxmoxHealth -IncludeStorage -IncludeNetwork
```

## Advanced Usage

### Custom Configuration
```powershell
# Create custom configuration
$customSettings = @{
    DefaultVMTemplate = "debian-11-template"
    BackupSchedule = "0 2 * * *"
    AutoSnapshot = $true
    SnapshotRetention = 5
}

Set-ProxmoxConfig -ConfigName "custom" `
                  -Server "pve.sslgen.cam" `
                  -Username "root@pam" `
                  -CustomSettings $customSettings

# Export configuration
Export-ProxmoxConfig -ConfigName "custom" -Path "./custom-config.json"
```

### Automated Tasks
```powershell
# Schedule daily backups
$backup = {
    Connect-ProxmoxServer -ConfigName "custom"
    Get-ProxmoxVM | ForEach-Object {
        New-ProxmoxBackup -VMID $_.vmid -Compress
    }
}

Register-ScheduledJob -Name "ProxmoxBackup" `
                     -ScriptBlock $backup `
                     -Trigger (New-JobTrigger -Daily -At "2:00 AM")
```

### Error Handling
```powershell
try {
    Connect-ProxmoxServer -Server "pve.sslgen.cam" -ErrorAction Stop
    New-ProxmoxVM -Name "test-vm" -ErrorAction Stop
}
catch {
    Write-Log "Failed to create VM: $_" -Level Error
}
finally {
    Disconnect-ProxmoxServer
}
```

## Best Practices

1. Always use configuration files for consistent settings
2. Implement proper error handling
3. Use logging for troubleshooting
4. Regular backups and snapshots
5. Monitor resource usage
6. Keep certificates up to date
7. Use secure credential storage
