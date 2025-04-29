# Configuration Module
# Part of Proxmox Helper Script

function Get-ProxmoxConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigName = 'default',

        [Parameter()]
        [switch]$ListAvailable
    )

    process {
        try {
            $configPath = Join-Path $script:ConfigPath 'configs'
            if (-not (Test-Path $configPath)) {
                New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            }

            if ($ListAvailable) {
                $configs = Get-ChildItem -Path $configPath -Filter "*.json" | ForEach-Object {
                    Get-Content $_.FullName | ConvertFrom-Json
                }
                return $configs
            }

            $configFile = Join-Path $configPath "$ConfigName.json"
            if (Test-Path $configFile) {
                $config = Get-Content $configFile | ConvertFrom-Json
                return $config
            } else {
                Write-Log "Configuration '$ConfigName' not found" -Level Warning
                return $null
            }
        }
        catch {
            Write-Log "Failed to get configuration: $_" -Level Error
            throw
        }
    }
}

function Set-ProxmoxConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigName = 'default',

        [Parameter()]
        [string]$Server,

        [Parameter()]
        [int]$Port = 8006,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [SecureString]$Password,

        [Parameter()]
        [string]$DefaultNode,

        [Parameter()]
        [string]$DefaultStorage,

        [Parameter()]
        [ValidateSet('Minimal', 'Normal', 'Detailed', 'Debug')]
        [string]$LogLevel = 'Normal',

        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [hashtable]$CustomSettings
    )

    process {
        try {
            $configPath = Join-Path $script:ConfigPath 'configs'
            if (-not (Test-Path $configPath)) {
                New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            }

            $configFile = Join-Path $configPath "$ConfigName.json"
            
            # Load existing config or create new
            $config = if (Test-Path $configFile) {
                Get-Content $configFile | ConvertFrom-Json
            } else {
                @{
                    Name = $ConfigName
                    Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    Settings = @{}
                }
            }

            # Update config with new values
            $config.LastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            if ($Server) { $config.Settings.Server = $Server }
            if ($Port) { $config.Settings.Port = $Port }
            if ($Username) { $config.Settings.Username = $Username }
            if ($Password) {
                $encryptedPassword = ConvertFrom-SecureString $Password
                $config.Settings.EncryptedPassword = $encryptedPassword
            }
            if ($DefaultNode) { $config.Settings.DefaultNode = $DefaultNode }
            if ($DefaultStorage) { $config.Settings.DefaultStorage = $DefaultStorage }
            if ($LogLevel) { $config.Settings.LogLevel = $LogLevel }
            if ($LogPath) { $config.Settings.LogPath = $LogPath }

            if ($CustomSettings) {
                if (-not $config.Settings.Custom) {
                    $config.Settings.Custom = @{}
                }
                foreach ($key in $CustomSettings.Keys) {
                    $config.Settings.Custom[$key] = $CustomSettings[$key]
                }
            }

            # Save config
            $config | ConvertTo-Json -Depth 10 | Set-Content $configFile
            Write-Log "Configuration '$ConfigName' saved successfully" -Level Success
            return $config
        }
        catch {
            Write-Log "Failed to set configuration: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigName
    )

    process {
        try {
            $configPath = Join-Path $script:ConfigPath 'configs'
            $configFile = Join-Path $configPath "$ConfigName.json"

            if (Test-Path $configFile) {
                if ($PSCmdlet.ShouldProcess("Configuration $ConfigName", "Remove")) {
                    Remove-Item $configFile -Force
                    Write-Log "Configuration '$ConfigName' removed successfully" -Level Success
                    return $true
                }
            } else {
                Write-Log "Configuration '$ConfigName' not found" -Level Warning
                return $false
            }
        }
        catch {
            Write-Log "Failed to remove configuration: $_" -Level Error
            throw
        }
    }
}

function Import-ProxmoxConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$ConfigName = 'default',

        [Parameter()]
        [switch]$Force
    )

    process {
        try {
            if (-not (Test-Path $Path)) {
                throw "Import file not found: $Path"
            }

            $importedConfig = Get-Content $Path | ConvertFrom-Json

            # Validate imported config
            if (-not $importedConfig.Settings) {
                throw "Invalid configuration format: Missing Settings section"
            }

            if ($Force -or -not (Get-ProxmoxConfig -ConfigName $ConfigName)) {
                $configPath = Join-Path $script:ConfigPath 'configs'
                $configFile = Join-Path $configPath "$ConfigName.json"

                # Update config name and timestamps
                $importedConfig.Name = $ConfigName
                $importedConfig.Imported = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $importedConfig.LastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                # Save imported config
                $importedConfig | ConvertTo-Json -Depth 10 | Set-Content $configFile
                Write-Log "Configuration imported successfully as '$ConfigName'" -Level Success
                return $importedConfig
            } else {
                Write-Log "Configuration '$ConfigName' already exists. Use -Force to overwrite" -Level Warning
                return $null
            }
        }
        catch {
            Write-Log "Failed to import configuration: $_" -Level Error
            throw
        }
    }
}

function Export-ProxmoxConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigName = 'default',

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [switch]$IncludeSecrets,

        [Parameter()]
        [switch]$Force
    )

    process {
        try {
            $config = Get-ProxmoxConfig -ConfigName $ConfigName
            if (-not $config) {
                throw "Configuration '$ConfigName' not found"
            }

            if (-not $IncludeSecrets) {
                # Remove sensitive information
                $config.Settings.PSObject.Properties | Where-Object {
                    $_.Name -match 'password|secret|key|token'
                } | ForEach-Object {
                    $config.Settings.($_.Name) = '[REMOVED]'
                }
            }

            if (Test-Path $Path -and -not $Force) {
                throw "Export file already exists. Use -Force to overwrite"
            }

            $config | ConvertTo-Json -Depth 10 | Set-Content $Path -Force
            Write-Log "Configuration '$ConfigName' exported successfully to $Path" -Level Success
            return $true
        }
        catch {
            Write-Log "Failed to export configuration: $_" -Level Error
            throw
        }
    }
}

function Test-ProxmoxConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigName = 'default'
    )

    process {
        try {
            $config = Get-ProxmoxConfig -ConfigName $ConfigName
            if (-not $config) {
                return @{
                    Valid = $false
                    Issues = @("Configuration not found")
                }
            }

            $issues = @()

            # Check required settings
            $requiredSettings = @('Server', 'Port', 'Username')
            foreach ($setting in $requiredSettings) {
                if (-not $config.Settings.$setting) {
                    $issues += "Missing required setting: $setting"
                }
            }

            # Validate server
            if ($config.Settings.Server) {
                try {
                    $null = [System.Uri]::new("https://$($config.Settings.Server):$($config.Settings.Port)")
                }
                catch {
                    $issues += "Invalid server URL format"
                }
            }

            # Validate port
            if ($config.Settings.Port -and ($config.Settings.Port -lt 1 -or $config.Settings.Port -gt 65535)) {
                $issues += "Invalid port number"
            }

            # Test connection if no issues found
            if ($issues.Count -eq 0) {
                try {
                    $connected = Connect-ProxmoxServer -Server $config.Settings.Server 
                                                      -Port $config.Settings.Port 
                                                      -Username $config.Settings.Username 
                                                      -ErrorAction Stop
                    if (-not $connected) {
                        $issues += "Failed to connect to Proxmox server"
                    }
                }
                catch {
                    $issues += "Connection test failed: $_"
                }
                finally {
                    Disconnect-ProxmoxServer
                }
            }

            return @{
                Valid = ($issues.Count -eq 0)
                Issues = $issues
            }
        }
        catch {
            Write-Log "Failed to test configuration: $_" -Level Error
            throw
        }
    }
}
