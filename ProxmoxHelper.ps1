#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cross-Platform Proxmox VE Helper Script

.DESCRIPTION
    This PowerShell script provides a comprehensive set of tools for managing Proxmox VE environments
    from any operating system. It includes functionality for VM management, certificate handling,
    storage validation, and network configuration.

.NOTES
    File Name      : ProxmoxHelper.ps1
    Author         : Your Name
    Prerequisite   : PowerShell Core 7.0 or higher
    License        : MIT

.LINK
    https://github.com/yourusername/proxmox-helper-script

.EXAMPLE
    # Connect to a Proxmox server
    .\ProxmoxHelper.ps1 -Connect -Server "pve.example.com" -Username "root" -PasswordFile "creds.xml"

.EXAMPLE
    # List all VMs
    .\ProxmoxHelper.ps1 -ListVMs

.EXAMPLE
    # Start a VM
    .\ProxmoxHelper.ps1 -StartVM -VMID 100
#>

#Requires -Version 7.0

[CmdletBinding(DefaultParameterSetName = "Help")]
param(
    # Connection Parameters
    [Parameter(ParameterSetName = "Connect")]
    [switch]$Connect,
    
    [Parameter(ParameterSetName = "Connect")]
    [string]$Server,
    
    [Parameter(ParameterSetName = "Connect")]
    [string]$Username,
    
    [Parameter(ParameterSetName = "Connect")]
    [string]$PasswordFile,
    
    [Parameter(ParameterSetName = "Connect")]
    [int]$Port = 8006,
    
    [Parameter(ParameterSetName = "Connect")]
    [switch]$SkipCertificateCheck,
    
    # VM Management Parameters
    [Parameter(ParameterSetName = "ListVMs")]
    [switch]$ListVMs,
    
    [Parameter(ParameterSetName = "StartVM")]
    [switch]$StartVM,
    
    [Parameter(ParameterSetName = "StopVM")]
    [switch]$StopVM,
    
    [Parameter(ParameterSetName = "RestartVM")]
    [switch]$RestartVM,
    
    [Parameter(ParameterSetName = "StartVM", Mandatory = $true)]
    [Parameter(ParameterSetName = "StopVM", Mandatory = $true)]
    [Parameter(ParameterSetName = "RestartVM", Mandatory = $true)]
    [int]$VMID,
    
    # Backup Parameters
    [Parameter(ParameterSetName = "GetBackups")]
    [switch]$GetBackups,
    
    [Parameter(ParameterSetName = "CreateBackup")]
    [switch]$CreateBackup,
    
    [Parameter(ParameterSetName = "CreateBackup", Mandatory = $true)]
    [int]$BackupVMID,
    
    [Parameter(ParameterSetName = "CreateBackup")]
    [string]$BackupStorage,
    
    # Node Status Parameters
    [Parameter(ParameterSetName = "GetNodeStatus")]
    [switch]$GetNodeStatus,
    
    [Parameter(ParameterSetName = "GetStorageStatus")]
    [switch]$GetStorageStatus,
    
    # Certificate Management
    [Parameter(ParameterSetName = "GenerateCert")]
    [switch]$GenerateCert,
    
    [Parameter(ParameterSetName = "GenerateCert", Mandatory = $true)]
    [string]$Domain,
    
    [Parameter(ParameterSetName = "GenerateCert")]
    [string]$Email,
    
    [Parameter(ParameterSetName = "GenerateCert")]
    [ValidateSet("SelfSigned", "LetsEncrypt")]
    [string]$CertType = "SelfSigned",
    
    # Global Parameters
    [Parameter(ParameterSetName = "Connect")]
    [Parameter(ParameterSetName = "ListVMs")]
    [Parameter(ParameterSetName = "StartVM")]
    [Parameter(ParameterSetName = "StopVM")]
    [Parameter(ParameterSetName = "RestartVM")]
    [Parameter(ParameterSetName = "GetBackups")]
    [Parameter(ParameterSetName = "CreateBackup")]
    [Parameter(ParameterSetName = "GetNodeStatus")]
    [Parameter(ParameterSetName = "GetStorageStatus")]
    [Parameter(ParameterSetName = "GenerateCert")]
    [string]$LogFile,
    
    [Parameter(ParameterSetName = "Connect")]
    [Parameter(ParameterSetName = "ListVMs")]
    [Parameter(ParameterSetName = "StartVM")]
    [Parameter(ParameterSetName = "StopVM")]
    [Parameter(ParameterSetName = "RestartVM")]
    [Parameter(ParameterSetName = "GetBackups")]
    [Parameter(ParameterSetName = "CreateBackup")]
    [Parameter(ParameterSetName = "GetNodeStatus")]
    [Parameter(ParameterSetName = "GetStorageStatus")]
    [Parameter(ParameterSetName = "GenerateCert")]
    [ValidateSet("Minimal", "Normal", "Detailed", "Debug")]
    [string]$Verbosity = "Normal"
)

#region Global Variables

# Script Information
$script:ScriptVersion = "1.0.0"
$script:ScriptName = "ProxmoxHelper.ps1"
$script:UserAgent = "ProxmoxHelper/$script:ScriptVersion PowerShell/$($PSVersionTable.PSVersion)"

# Session Variables
$script:ApiUrl = $null
$script:AuthToken = $null
$script:CSRFPreventionToken = $null
$script:ApiTicket = $null

# Directory Paths
$script:ScriptPath = $PSScriptRoot
if (-not $script:ScriptPath) {
    $script:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# Platform Detection
$script:IsWindows = $IsWindows -or (-not $IsLinux -and -not $IsMacOS)
$script:IsLinux = $IsLinux
$script:IsMacOS = $IsMacOS

# Set up paths based on OS
if ($script:IsWindows) {
    $script:ConfigPath = Join-Path $env:USERPROFILE ".proxmoxhelper"
    $script:CertPath = Join-Path $script:ConfigPath "certs"
    $script:LogPath = Join-Path $script:ConfigPath "logs"
} else {
    $script:ConfigPath = Join-Path $HOME ".proxmoxhelper"
    $script:CertPath = Join-Path $script:ConfigPath "certs"
    $script:LogPath = Join-Path $script:ConfigPath "logs"
}

# Create directories if they don't exist
foreach ($path in @($script:ConfigPath, $script:CertPath, $script:LogPath)) {
    if (-not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# Set default log file if not specified
if (-not $LogFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFile = Join-Path $script:LogPath "proxmoxhelper_$timestamp.log"
}

# Verbosity Levels
$script:VerbosityLevels = @{
    "Minimal" = 0
    "Normal" = 1
    "Detailed" = 2
    "Debug" = 3
}

$script:CurrentVerbosity = $script:VerbosityLevels[$Verbosity]

#endregion

#region Helper Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to a log file and optionally to the console.
    .DESCRIPTION
        This function writes a message to a log file and optionally to the console with color-coding based on severity.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The severity level of the message (Info, Warning, Error, Debug).
    .PARAMETER NoConsole
        If specified, the message will only be written to the log file and not to the console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Position = 1)]
        [ValidateSet("Info", "Warning", "Error", "Debug", "Success")]
        [string]$Level = "Info",
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    # Determine if the message should be logged based on verbosity
    $shouldLog = $false
    
    switch ($Level) {
        "Error" { $shouldLog = $true }
        "Warning" { $shouldLog = $script:CurrentVerbosity -ge 0 }
        "Info" { $shouldLog = $script:CurrentVerbosity -ge 1 }
        "Success" { $shouldLog = $script:CurrentVerbosity -ge 1 }
        "Debug" { $shouldLog = $script:CurrentVerbosity -ge 3 }
    }
    
    if (-not $shouldLog) {
        return
    }
    
    # Format the log message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Append to log file
    Add-Content -Path $LogFile -Value $logMessage
    
    # Write to console with appropriate color if not suppressed
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Debug" { "Gray" }
            "Success" { "Green" }
            default { "White" }
        }
        
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Test-Administrator {
    <#
    .SYNOPSIS
        Tests if the current user has administrator/root privileges.
    .DESCRIPTION
        This function checks if the current user has administrator privileges on Windows or is root on Linux/macOS.
    .OUTPUTS
        Returns $true if the user has administrator privileges, $false otherwise.
    #>
    
    if ($script:IsWindows) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        # Unix-like systems
        return (id -u) -eq 0
    }
}

function Invoke-ProxmoxAPI {
    <#
    .SYNOPSIS
        Invokes the Proxmox API.
    .DESCRIPTION
        This function sends requests to the Proxmox API and handles authentication and error handling.
    .PARAMETER Method
        The HTTP method to use (GET, POST, PUT, DELETE).
    .PARAMETER Endpoint
        The API endpoint to call.
    .PARAMETER Body
        The request body for POST and PUT requests.
    .PARAMETER ContentType
        The content type of the request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method,
        
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter()]
        [object]$Body = $null,
        
        [Parameter()]
        [string]$ContentType = "application/json"
    )
    
    # Check if we're authenticated
    if (-not $script:ApiUrl -or -not $script:ApiTicket) {
        Write-Log "Not authenticated to Proxmox API. Run Connect-ProxmoxServer first." -Level Error
        throw "Not authenticated to Proxmox API"
    }
    
    $url = "$script:ApiUrl/$Endpoint"
    
    $headers = @{
        "Cookie" = "PVEAuthCookie=$($script:ApiTicket)"
        "CSRFPreventionToken" = $script:CSRFPreventionToken
        "User-Agent" = $script:UserAgent
    }
    
    $invokeParams = @{
        Method = $Method
        Uri = $url
        Headers = $headers
        ContentType = $ContentType
        UseBasicParsing = $true
        ErrorAction = "Stop"
    }
    
    if ($script:SkipCertCheck) {
        $invokeParams.Add("SkipCertificateCheck", $true)
    }
    
    if ($Body -and ($Method -eq "POST" -or $Method -eq "PUT")) {
        if ($Body -is [hashtable] -or $Body -is [System.Collections.Specialized.OrderedDictionary]) {
            $invokeParams.Body = $Body
        } else {
            $invokeParams.Body = $Body | ConvertTo-Json -Compress
        }
    }
    
    Write-Log "Invoking Proxmox API: $Method $Endpoint" -Level Debug
    
    try {
        $response = Invoke-RestMethod @invokeParams
        
        if ($response.data) {
            return $response.data
        } else {
            return $response
        }
    } catch {
        $errorDetails = if ($_.ErrorDetails.Message) {
            try {
                $_.ErrorDetails.Message | ConvertFrom-Json
            } catch {
                $_.ErrorDetails.Message
            }
        } else {
            $_.Exception.Message
        }
        
        Write-Log "API Error: $Method $Endpoint - $errorDetails" -Level Error
        throw $_
    }
}

function ConvertTo-BasicAuthHeader {
    <#
    .SYNOPSIS
        Converts username and password to a basic authentication header.
    .DESCRIPTION
        This function converts a username and password pair to a basic authentication header for use with REST APIs.
    .PARAMETER Username
        The username to use.
    .PARAMETER Password
        The password to use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    $pair = "$($Username):$($Password)"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    return "Basic $base64"
}

function Test-ProxmoxConnection {
    <#
    .SYNOPSIS
        Tests if the connection to Proxmox is valid.
    .DESCRIPTION
        This function checks if the current Proxmox API connection is valid.
    .OUTPUTS
        Returns $true if the connection is valid, $false otherwise.
    #>
    
    if (-not $script:ApiUrl -or -not $script:ApiTicket) {
        return $false
    }
    
    try {
        $result = Invoke-ProxmoxAPI -Method GET -Endpoint "version"
        return $true
    } catch {
        return $false
    }
}

function Get-RandomPassword {
    <#
    .SYNOPSIS
        Generates a random password.
    .DESCRIPTION
        This function generates a cryptographically secure random password with specified complexity.
    .PARAMETER Length
        The length of the password (default: 16).
    .PARAMETER IncludeSpecialChars
        If specified, the password will include special characters.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Length = 16,
        
        [Parameter()]
        [switch]$IncludeSpecialChars
    )
    
    $charSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    if ($IncludeSpecialChars) {
        $charSet += "!@#$%^&*()-_=+[]{}|;:,.<>?/"
    }
    
    $secureRandom = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] $Length
    $secureRandom.GetBytes($bytes)
    
    $password = ""
    $charSetLength = $charSet.Length
    
    for ($i = 0; $i -lt $Length; $i++) {
        $index = $bytes[$i] % $charSetLength
        $password += $charSet[$index]
    }
    
    return $password
}

function Save-Credentials {
    <#
    .SYNOPSIS
        Saves credentials to a file.
    .DESCRIPTION
        This function saves credentials to an encrypted file for later use.
    .PARAMETER Credential
        The credential object to save.
    .PARAMETER FilePath
        The path to save the credential file to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        $Credential | Export-Clixml -Path $FilePath -Force
        Write-Log "Credentials saved to $FilePath" -Level Success
        return $true
    } catch {
        Write-Log "Failed to save credentials: $_" -Level Error
        return $false
    }
}

function Get-SavedCredentials {
    <#
    .SYNOPSIS
        Retrieves saved credentials from a file.
    .DESCRIPTION
        This function retrieves credentials from an encrypted file.
    .PARAMETER FilePath
        The path to the credential file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path -Path $FilePath)) {
        Write-Log "Credential file not found: $FilePath" -Level Error
        return $null
    }
    
    try {
        $Credential = Import-Clixml -Path $FilePath
        return $Credential
    } catch {
        Write-Log "Failed to load credentials: $_" -Level Error
        return $null
    }
}

#endregion

#region Proxmox Connection Functions

function Connect-ProxmoxServer {
    <#
    .SYNOPSIS
        Connects to a Proxmox server.
    .DESCRIPTION
        This function establishes a connection to a Proxmox server and authenticates the user.
    .PARAMETER Server
        The hostname or IP address of the Proxmox server.
    .PARAMETER Port
        The port number of the Proxmox API (default: 8006).
    .PARAMETER Username
        The username to authenticate with.
    .PARAMETER Password
        The password to authenticate with.
    .PARAMETER PasswordFile
        The path to a saved credential file.
    .PARAMETER Credential
        A PSCredential object containing the username and password.
    .PARAMETER SkipCertificateCheck
        If specified, certificate validation will be skipped.
    #>
    [CmdletBinding(DefaultParameterSetName = "Password")]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        
        [Parameter()]
        [int]$Port = 8006,
        
        [Parameter(ParameterSetName = "Password", Mandatory = $true)]
        [Parameter(ParameterSetName = "PasswordFile")]
        [string]$Username,
        
        [Parameter(ParameterSetName = "Password", Mandatory = $true)]
        [securestring]$Password,
        
        [Parameter(ParameterSetName = "PasswordFile", Mandatory = $true)]
        [string]$PasswordFile,
        
        [Parameter(ParameterSetName = "Credential", Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [switch]$SkipCertificateCheck
    )
    
    # Parse credentials
    switch ($PSCmdlet.ParameterSetName) {
        "Password" {
            $Credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        }
        "PasswordFile" {
            if ($Username) {
                # Username provided separately, just get the password from file
                $savedCred = Get-SavedCredentials -FilePath $PasswordFile
                if (-not $savedCred) {
                    Write-Log "Failed to load credentials from $PasswordFile" -Level Error
                    return $false
                }
                $Credential = New-Object System.Management.Automation.PSCredential($Username, $savedCred.Password)
            } else {
                # Get both username and password from file
                $Credential = Get-SavedCredentials -FilePath $PasswordFile
                if (-not $Credential) {
                    Write-Log "Failed to load credentials from $PasswordFile" -Level Error
                    return $false
                }
            }
        }
    }
    
    # Set Proxmox API URL
    $script:ApiUrl = "https://$Server`:$Port/api2/json"
    $script:SkipCertCheck = $SkipCertificateCheck
    
    Write-Log "Connecting to Proxmox server at $Server`:$Port as $($Credential.UserName)" -Level Info
    
    # Format credentials correctly for Proxmox
    $username = $Credential.UserName
    if (-not $username.Contains('@')) {
        $username = "$username@pam"
    }
    
    $passwordPlain = $Credential.GetNetworkCredential().Password
    
    # Build authentication request
    $authUrl = "$script:ApiUrl/access/ticket"
    $authBody = @{
        username = $username
        password = $passwordPlain
    }
    
    $authParams = @{
        Method = "POST"
        Uri = $authUrl
        Body = $authBody
        ContentType = "application/x-www-form-urlencoded"
        ErrorAction = "Stop"
    }
    
    if ($SkipCertificateCheck) {
        $authParams.Add("SkipCertificateCheck", $true)
    }
    
    try {
        $authResponse = Invoke-RestMethod @authParams
        
        if ($authResponse.data) {
            $script:ApiTicket = $authResponse.data.ticket
            $script:CSRFPreventionToken = $authResponse.data.CSRFPreventionToken
            Write-Log "Successfully authenticated to Proxmox server" -Level Success
            
            # Test connection
            $versionInfo = Invoke-ProxmoxAPI -Method GET -Endpoint "version"
            Write-Log "Connected to Proxmox VE $($versionInfo.version) (API version $($versionInfo.apiversion))" -Level Info
            
            return $true
        } else {
            Write-Log "Authentication failed: Invalid response from server" -Level Error
            return $false
        }
    } catch {
        Write-Log "Authentication failed: $_" -Level Error
        return $false
    }
}

function Disconnect-ProxmoxServer {
    <#
    .SYNOPSIS
        Disconnects from a Proxmox server.
    .DESCRIPTION
        This function terminates the connection to a Proxmox server and clears authentication tokens.
    #>
    
    $script:ApiUrl = $null
    $script:AuthToken = $null
    $script:CSRFPreventionToken = $null
    $script:ApiTicket = $null
    
    Write-Log "Disconnected from Proxmox server" -Level Info
    return $true
}

#endregion

#region VM Management Functions

function Get-ProxmoxVM {
    <#
    .SYNOPSIS
        Gets a list of VMs from the Proxmox server.
    .DESCRIPTION
        This function retrieves a list of all VMs from the Proxmox server.
    .PARAMETER Node
        The node to get VMs from. If not specified, VMs from all nodes are returned.
    .PARAMETER VMID
        The ID of a specific VM to get information for.
    .PARAMETER IncludeConfig
        If specified, includes the VM configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,
        
        [Parameter()]
        [int]$VMID,
        
        [Parameter()]
        [switch]$IncludeConfig
    )
    
    # First check if we're connected
    if (-not (Test-ProxmoxConnection)) {
        Write-Log "Not connected to Proxmox server. Run Connect-ProxmoxServer first." -Level Error
        return
    }
    
    # Different API endpoints based on parameters
    try {
        if ($VMID) {
            # Get a specific VM
            $nodeEndpoint = $Node ? "nodes/$Node" : "cluster/resources"
            $vms = Invoke-ProxmoxAPI -Method GET -Endpoint "$nodeEndpoint"
            $vms = $vms | Where-Object { $_.type -eq "qemu" -and $_.vmid -eq $VMID }
            
            if ($vms -and $IncludeConfig) {
                foreach ($vm in $vms) {
                    $node = $vm.node
                    $config = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$node/qemu/$VMID/config"
                    $vm | Add-Member -MemberType NoteProperty -Name "config" -Value $config
                }
            }
        } else {
            # Get all VMs
            if ($Node) {
                # Get VMs from a specific node
                $vms = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu"
            } else {
                # Get VMs from all nodes
                $vms = Invoke-ProxmoxAPI -Method GET -Endpoint "cluster/resources" | Where-Object { $_.type -eq "qemu" }
            }
            
            if ($vms -and $IncludeConfig) {
                foreach ($vm in $vms) {
                    $node = $vm.node
                    $vmid = $vm.vmid
                    $config = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$node/qemu/$vmid/config"
                    $vm | Add-Member -MemberType NoteProperty -Name "config" -Value $config
                }
            }
        }
        
        return $vms
    } catch {
        Write-Log "Failed to get VMs: $_" -Level Error
        throw $_
    }
}

function Start-ProxmoxVM {
    <#
    .SYNOPSIS
        Starts a VM on the Proxmox server.
    .DESCRIPTION
        This function starts a VM on the Proxmox server.
    .PARAMETER VMID
        The ID of the VM to start.
    .PARAMETER Node
        The node where the VM is located. If not specified, the node will be determined automatically.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,
        
        [Parameter()]
        [string]$Node
    )
    
    # First check if we're connected
    if (-not (Test-ProxmoxConnection)) {
        Write-Log "Not connected to Proxmox server. Run Connect-ProxmoxServer first." -Level Error
        return $false
    }
    
    try {
        # If node is not specified, find it
        if (-not $Node) {
            $vm = Get-ProxmoxVM -VMID $VMID
            if (-not $vm) {
                Write-Log "VM with ID $VMID not found" -Level Error
                return $false
            }
            $Node = $vm.node
        }
        
        # Start the VM
        Write-Log "Starting VM $VMID on node $Node" -Level Info
        $result = Invoke-ProxmoxAPI -Method POST -Endpoint "nodes/$Node/qemu/$VMID/status/start"
        
        Write-Log "VM $VMID start operation initiated successfully" -Level Success
        return $true
    } catch {
        Write-Log "Failed to start VM $VMID: $_" -Level Error
        return $false
    }
}

function Stop-ProxmoxVM {
    <#
    .SYNOPSIS
        Stops a VM on the Proxmox server.
    .DESCRIPTION
        This function stops a VM on the Proxmox server.
    .PARAMETER VMID
        The ID of the VM to stop.
    .PARAMETER Node
        The node where the VM is located. If not specified, the node will be determined automatically.
    .PARAMETER Force
        If specified, the VM will be forcefully stopped (equivalent to pulling the power cord).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,
        
        [Parameter()]
        [string]$Node,
        
        [Parameter()]
        [switch]$Force
    )
    
    # First check if we're connected
    if (-not (Test-ProxmoxConnection)) {
        Write-Log "Not connected to Proxmox server. Run Connect-ProxmoxServer first." -Level Error
        return $false
    }
    
    try {
        # If node is not specified, find it
        if (-not $Node) {
            $vm = Get-ProxmoxVM -VMID $VMID
            if (-not $vm) {
                Write-Log "VM with ID $VMID not found" -Level Error
                return $false
            }
            $Node = $vm.node
        }
        
        # Stop the VM
        $endpoint = "nodes/$Node/qemu/$VMID/status/" + ($Force ? "stop" : "shutdown")
        Write-Log "Stopping VM $VMID on node $Node" + ($Force ? " (forced)" : "") -Level Info
        $result = Invoke-ProxmoxAPI -Method POST -Endpoint $endpoint
        
        Write-Log "VM $VMID stop operation initiated successfully" -Level Success
        return $true
    } catch {
        Write-Log "Failed to stop VM $VMID: $_" -Level Error
        return $false
    }
}

function Restart-ProxmoxVM {
    <#
    .

