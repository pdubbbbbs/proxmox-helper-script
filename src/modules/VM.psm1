# VM Management Module
# Part of Proxmox Helper Script

function New-ProxmoxVM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [int]$Memory = 2048,

        [Parameter()]
        [int]$Cores = 2,

        [Parameter()]
        [string]$Storage = 'local-lvm',

        [Parameter()]
        [string]$NetworkBridge = 'vmbr0',

        [Parameter()]
        [string]$Template,

        [Parameter()]
        [string]$OSType = 'l26'  # Linux 2.6+ kernel
    )

    process {
        try {
            Write-Log "Creating new VM: $Name" -Level Info

            # Get next available VMID if not specified
            if (-not $VMID) {
                $VMID = Invoke-ProxmoxAPI -Method GET -Endpoint 'cluster/nextid'
            }

            # Get node if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $Node = $nodes[0].node
            }

            # Create VM configuration
            $vmConfig = @{
                vmid = $VMID
                name = $Name
                memory = $Memory
                cores = $Cores
                ostype = $OSType
                net0 = "virtio,bridge=$NetworkBridge"
            }

            # Create the VM
            $result = Invoke-ProxmoxAPI -Method POST -Endpoint "nodes/$Node/qemu" -Body $vmConfig

            Write-Log "VM $Name created successfully with ID $VMID" -Level Success
            return $result
        }
        catch {
            Write-Log "Failed to create VM: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxVM {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [switch]$Force
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            if ($Force -or $PSCmdlet.ShouldProcess("VM $VMID", "Remove")) {
                # Stop VM if running
                $status = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/status/current"
                if ($status.status -eq 'running') {
                    Write-Log "Stopping VM $VMID" -Level Info
                    Stop-ProxmoxVM -VMID $VMID -Node $Node -Force
                }

                # Remove VM
                $result = Invoke-ProxmoxAPI -Method DELETE -Endpoint "nodes/$Node/qemu/$VMID"
                Write-Log "VM $VMID removed successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to remove VM: $_" -Level Error
            throw
        }
    }
}

function Set-ProxmoxVMConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [int]$Memory,

        [Parameter()]
        [int]$Cores,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [hashtable]$AdditionalConfig
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            $config = @{}

            if ($Memory) { $config.memory = $Memory }
            if ($Cores) { $config.cores = $Cores }
            if ($Description) { $config.description = $Description }
            if ($AdditionalConfig) {
                foreach ($key in $AdditionalConfig.Keys) {
                    $config[$key] = $AdditionalConfig[$key]
                }
            }

            if ($PSCmdlet.ShouldProcess("VM $VMID", "Update configuration")) {
                $result = Invoke-ProxmoxAPI -Method PUT -Endpoint "nodes/$Node/qemu/$VMID/config" -Body $config
                Write-Log "VM $VMID configuration updated successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to update VM configuration: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxVMStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

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

            $status = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/status/current"
            return $status
        }
        catch {
            Write-Log "Failed to get VM status: $_" -Level Error
            throw
        }
    }
}

function Wait-ProxmoxVMStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter(Mandatory = $true)]
        [ValidateSet('running', 'stopped')]
        [string]$Status,

        [Parameter()]
        [int]$Timeout = 300,

        [Parameter()]
        [int]$PollingInterval = 5
    )

    process {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
                $currentStatus = Get-ProxmoxVMStatus -VMID $VMID -Node $Node
                if ($currentStatus.status -eq $Status) {
                    Write-Log "VM $VMID reached status '$Status'" -Level Success
                    return $true
                }

                Start-Sleep -Seconds $PollingInterval
            }

            Write-Log "Timeout waiting for VM $VMID to reach status '$Status'" -Level Warning
            return $false
        }
        catch {
            Write-Log "Error waiting for VM status: $_" -Level Error
            throw
        }
        finally {
            $stopwatch.Stop()
        }
    }
}
