# ProxmoxHelper.psm1
# Root module file for Proxmox Helper Script

#Requires -Version 7.0

# Script Information
$script:ModuleVersion = '1.0.0'
$script:ModuleName = 'ProxmoxHelper'
$script:ModulePath = $PSScriptRoot

# Initialize Script Variables
$script:ConfigPath = Join-Path (Split-Path $Profile -Parent) '.proxmoxhelper'
$script:CertPath = Join-Path $script:ConfigPath 'certs'
$script:LogPath = Join-Path $script:ConfigPath 'logs'
$script:ApiUrl = $null
$script:AuthToken = $null
$script:CSRFPreventionToken = $null
$script:ApiTicket = $null

# Create necessary directories
@($script:ConfigPath, $script:CertPath, $script:LogPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Import Required Modules
$requiredModules = @(
    @{ Name = 'Microsoft.PowerShell.SecretManagement'; MinimumVersion = '1.0.0' }
)

foreach ($module in $requiredModules) {
    try {
        if (-not (Get-Module -Name $module.Name -ListAvailable)) {
            Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -AllowClobber
        }
        Import-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force
    }
    catch {
        Write-Warning "Failed to import required module $($module.Name): $_"
    }
}

# Import Module Functions
$publicFunctions = @(
    'Connect-ProxmoxServer',
    'Disconnect-ProxmoxServer',
    'Invoke-ProxmoxAPI',
    'Write-Log',
    'Test-Administrator'
)

# Export public functions
Export-ModuleMember -Function $publicFunctions

# Module Initialization
$initScript = {
    # Initialize default configuration if it doesn't exist
    if (-not (Test-Path (Join-Path $script:ConfigPath 'configs/default.json'))) {
        $defaultConfig = @{
            Name = 'default'
            Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Settings = @{
                LogLevel = 'Normal'
                LogPath = Join-Path $script:LogPath 'proxmoxhelper.log'
            }
        }
        $configPath = Join-Path $script:ConfigPath 'configs'
        if (-not (Test-Path $configPath)) {
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
        }
        $defaultConfig | ConvertTo-Json | Set-Content (Join-Path $configPath 'default.json')
    }

    # Set up event logging
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-Log "Module unloading - cleaning up resources" -Level Info
        Disconnect-ProxmoxServer
    } | Out-Null
}

# Run initialization
. $initScript

# Module cleanup on removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Log "Module being removed - performing cleanup" -Level Info
    Disconnect-ProxmoxServer
    Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
}

# Helper Functions
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Success')]
        [string]$Level = 'Info',
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[] [] "
    
    # Get current config
    try {
        $config = Get-ProxmoxConfig
        $logPath = if ($config.Settings.LogPath) { 
            $config.Settings.LogPath 
        } else { 
            Join-Path $script:LogPath 'proxmoxhelper.log' 
        }
    }
    catch {
        $logPath = Join-Path $script:LogPath 'proxmoxhelper.log'
    }
    
    # Ensure log directory exists
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $logPath -Value $logMessage
    
    # Write to console if not suppressed
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'Info' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Debug' { 'Gray' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Test-Administrator {
    if ($IsWindows) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        return ((id -u) -eq 0)
    }
}

function Invoke-ProxmoxAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method,
        
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter()]
        [object]$Body,
        
        [Parameter()]
        [string]$ContentType = 'application/json'
    )
    
    process {
        try {
            if (-not $script:ApiUrl -or -not $script:ApiTicket) {
                throw "Not connected to Proxmox server. Run Connect-ProxmoxServer first."
            }
            
            $uri = "$script:ApiUrl/$Endpoint"
            $headers = @{
                'Cookie' = "PVEAuthCookie=$script:ApiTicket"
                'CSRFPreventionToken' = $script:CSRFPreventionToken
            }
            
            $params = @{
                Method = $Method
                Uri = $uri
                Headers = $headers
                ContentType = $ContentType
                SkipCertificateCheck = $true
            }
            
            if ($Body) {
                if ($Body -is [hashtable]) {
                    $params.Body = $Body
                }
                else {
                    $params.Body = $Body | ConvertTo-Json -Compress
                }
            }
            
            $response = Invoke-RestMethod @params
            return $response.data
        }
        catch {
            Write-Log "API Error ($Method $Endpoint): $_" -Level Error
            throw
        }
    }
}

# Export module members
Export-ModuleMember -Function * -Variable *
