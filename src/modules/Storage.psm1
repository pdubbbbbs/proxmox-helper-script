# Storage Management Module
# Part of Proxmox Helper Script

function Get-ProxmoxStorage {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$StorageId,

        [Parameter()]
        [switch]$IncludeContent,

        [Parameter()]
        [switch]$IncludeUsage
    )

    process {
        try {
            if ($StorageId) {
                # Get specific storage
                $endpoint = if ($Node) {
                    "nodes/$Node/storage/$StorageId"
                } else {
                    "storage/$StorageId"
                }
            } else {
                # Get all storage
                $endpoint = if ($Node) {
                    "nodes/$Node/storage"
                } else {
                    "storage"
                }
            }

            $storage = Invoke-ProxmoxAPI -Method GET -Endpoint $endpoint

            if ($IncludeContent -and $storage) {
                foreach ($s in @($storage)) {
                    $content = Invoke-ProxmoxAPI -Method GET -Endpoint "storage/$($s.storage)/content"
                    $s | Add-Member -MemberType NoteProperty -Name 'Content' -Value $content
                }
            }

            if ($IncludeUsage -and $storage -and $Node) {
                foreach ($s in @($storage)) {
                    $usage = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/storage/$($s.storage)/status"
                    $s | Add-Member -MemberType NoteProperty -Name 'Usage' -Value $usage
                }
            }

            return $storage
        }
        catch {
            Write-Log "Failed to get storage information: $_" -Level Error
            throw
        }
    }
}

function New-ProxmoxBackup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Storage,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$Compress,

        [Parameter()]
        [switch]$IncludeState
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            # Get default backup storage if not specified
            if (-not $Storage) {
                $storages = Get-ProxmoxStorage -Node $Node
                $Storage = ($storages | Where-Object { $_.content -contains 'backup' } | Select-Object -First 1).storage
            }

            $backupConfig = @{
                vmid = $VMID
                storage = $Storage
                mode = if ($Compress) { 'snapshot' } else { 'stop' }
                compress = if ($Compress) { 'zstd' } else { 'none' }
            }

            if ($Description) {
                $backupConfig.notes = $Description
            }

            if ($IncludeState) {
                $backupConfig.savestate = 1
            }

            if ($PSCmdlet.ShouldProcess("VM $VMID", "Create backup")) {
                Write-Log "Creating backup for VM $VMID" -Level Info
                $result = Invoke-ProxmoxAPI -Method POST -Endpoint "nodes/$Node/vzdump" -Body $backupConfig
                Write-Log "Backup creation initiated for VM $VMID" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to create backup: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxBackup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Storage,

        [Parameter()]
        [int]$VMID
    )

    process {
        try {
            # Get all nodes if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $nodeNames = $nodes.node
            } else {
                $nodeNames = @($Node)
            }

            $backups = @()
            foreach ($n in $nodeNames) {
                $endpoint = "nodes/$n/storage"
                if ($Storage) {
                    $endpoint += "/$Storage"
                }
                $endpoint += "/content"
                
                $content = Invoke-ProxmoxAPI -Method GET -Endpoint $endpoint
                $backups += $content | Where-Object { $_.volid -like '*.backup*' }
            }

            if ($VMID) {
                $backups = $backups | Where-Object { $_.vmid -eq $VMID }
            }

            return $backups
        }
        catch {
            Write-Log "Failed to get backups: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxBackup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupId,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Storage
    )

    process {
        try {
            if ($PSCmdlet.ShouldProcess("Backup $BackupId", "Remove")) {
                Write-Log "Removing backup $BackupId" -Level Info
                $endpoint = "nodes/$Node/storage/$Storage/content/$BackupId"
                $result = Invoke-ProxmoxAPI -Method DELETE -Endpoint $endpoint
                Write-Log "Backup $BackupId removed successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to remove backup: $_" -Level Error
            throw
        }
    }
}

function New-ProxmoxSnapshot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$IncludeRAM
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            $snapshotConfig = @{
                snapname = $Name
            }

            if ($Description) {
                $snapshotConfig.description = $Description
            }

            if ($IncludeRAM) {
                $snapshotConfig.vmstate = 1
            }

            if ($PSCmdlet.ShouldProcess("VM $VMID", "Create snapshot $Name")) {
                Write-Log "Creating snapshot $Name for VM $VMID" -Level Info
                $result = Invoke-ProxmoxAPI -Method POST -Endpoint "nodes/$Node/qemu/$VMID/snapshot" -Body $snapshotConfig
                Write-Log "Snapshot creation initiated for VM $VMID" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to create snapshot: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Name
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            $endpoint = "nodes/$Node/qemu/$VMID/snapshot"
            if ($Name) {
                $endpoint += "/$Name"
            }

            $snapshots = Invoke-ProxmoxAPI -Method GET -Endpoint $endpoint
            return $snapshots
        }
        catch {
            Write-Log "Failed to get snapshots: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxSnapshot {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Node
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            if ($PSCmdlet.ShouldProcess("VM $VMID", "Remove snapshot $Name")) {
                Write-Log "Removing snapshot $Name from VM $VMID" -Level Info
                $result = Invoke-ProxmoxAPI -Method DELETE -Endpoint "nodes/$Node/qemu/$VMID/snapshot/$Name"
                Write-Log "Snapshot $Name removed successfully from VM $VMID" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to remove snapshot: $_" -Level Error
            throw
        }
    }
}
