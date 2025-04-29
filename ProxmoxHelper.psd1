# Proxmox Helper Module Manifest
@{
    RootModule = 'ProxmoxHelper.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2960e54-0a80-4b7b-9e32-ffb792c098c0'
    Author = 'Philip S. Wright'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Philip S. Wright. All rights reserved.'
    Description = 'Cross-platform PowerShell helper script for managing Proxmox VE environments'
    PowerShellVersion = '7.0'
    
    # Modules to import as nested modules of the module specified in RootModule
    NestedModules = @(
        'src/modules/SSL.psm1',
        'src/modules/VM.psm1',
        'src/modules/Storage.psm1',
        'src/modules/Network.psm1',
        'src/modules/Monitoring.psm1',
        'src/modules/Configuration.psm1'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        # SSL Management
        'New-ProxmoxSSLCertificate',
        'Install-ProxmoxSSLCertificate',
        'Test-SSLCertificate',
        
        # VM Management
        'New-ProxmoxVM',
        'Remove-ProxmoxVM',
        'Get-ProxmoxVM',
        'Set-ProxmoxVMConfig',
        'Start-ProxmoxVM',
        'Stop-ProxmoxVM',
        'Restart-ProxmoxVM',
        
        # Storage Management
        'Get-ProxmoxStorage',
        'New-ProxmoxBackup',
        'Get-ProxmoxBackup',
        'Remove-ProxmoxBackup',
        'New-ProxmoxSnapshot',
        'Get-ProxmoxSnapshot',
        'Remove-ProxmoxSnapshot',
        
        # Network Management
        'Get-ProxmoxNetwork',
        'New-ProxmoxBridge',
        'Remove-ProxmoxBridge',
        'Get-ProxmoxFirewallRule',
        'Add-ProxmoxFirewallRule',
        'Remove-ProxmoxFirewallRule',
        
        # Monitoring
        'Get-ProxmoxClusterStatus',
        'Get-ProxmoxNodeMetrics',
        'Get-ProxmoxVMMetrics',
        'Test-ProxmoxHealth',
        'Watch-ProxmoxMetrics',
        
        # Configuration
        'Get-ProxmoxConfig',
        'Set-ProxmoxConfig',
        'Remove-ProxmoxConfig',
        'Import-ProxmoxConfig',
        'Export-ProxmoxConfig',
        'Test-ProxmoxConfig'
    )
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags = @('Proxmox', 'Virtualization', 'Management', 'SSL', 'Monitoring')
            LicenseUri = 'https://github.com/pdubbbbbs/proxmox-helper-script/blob/main/LICENSE'
            ProjectUri = 'https://github.com/pdubbbbbs/proxmox-helper-script'
            RequireLicenseAcceptance = $false
        }
    }
}
