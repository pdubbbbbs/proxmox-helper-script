# Network Management Module
# Part of Proxmox Helper Script

function Get-ProxmoxNetwork {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Interface,

        [Parameter()]
        [switch]$IncludeUsage
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $Node = $nodes[0].node
            }

            $endpoint = "nodes/$Node/network"
            if ($Interface) {
                $endpoint += "/$Interface"
            }

            $networks = Invoke-ProxmoxAPI -Method GET -Endpoint $endpoint

            if ($IncludeUsage -and $networks) {
                foreach ($net in @($networks)) {
                    try {
                        $usage = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/network/$($net.iface)/status"
                        $net | Add-Member -MemberType NoteProperty -Name 'Usage' -Value $usage -Force
                    }
                    catch {
                        Write-Log "Failed to get usage for interface $($net.iface): $_" -Level Warning
                    }
                }
            }

            return $networks
        }
        catch {
            Write-Log "Failed to get network information: $_" -Level Error
            throw
        }
    }
}

function New-ProxmoxBridge {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [string]$Ports,

        [Parameter()]
        [int]$VLAN,

        [Parameter()]
        [string]$Address,

        [Parameter()]
        [string]$Gateway,

        [Parameter()]
        [switch]$AutoStart
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $Node = $nodes[0].node
            }

            $bridgeConfig = @{
                iface = $Name
                type = 'bridge'
            }

            if ($Ports) { $bridgeConfig.bridge_ports = $Ports }
            if ($VLAN) { $bridgeConfig.vlan_aware = 1; $bridgeConfig.bridge_vlan_aware = 1 }
            if ($Address) { $bridgeConfig.address = $Address }
            if ($Gateway) { $bridgeConfig.gateway = $Gateway }
            if ($AutoStart) { $bridgeConfig.autostart = 1 }

            if ($PSCmdlet.ShouldProcess("$Node", "Create network bridge $Name")) {
                Write-Log "Creating network bridge $Name on node $Node" -Level Info
                $result = Invoke-ProxmoxAPI -Method POST -Endpoint "nodes/$Node/network" -Body $bridgeConfig
                Write-Log "Network bridge $Name created successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to create network bridge: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxBridge {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Node
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $Node = $nodes[0].node
            }

            if ($PSCmdlet.ShouldProcess("$Node", "Remove network bridge $Name")) {
                Write-Log "Removing network bridge $Name from node $Node" -Level Info
                $result = Invoke-ProxmoxAPI -Method DELETE -Endpoint "nodes/$Node/network/$Name"
                Write-Log "Network bridge $Name removed successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to remove network bridge: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxFirewallRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [int]$VMID,

        [Parameter()]
        [switch]$Cluster
    )

    process {
        try {
            if ($Cluster) {
                $endpoint = "cluster/firewall/rules"
            }
            elseif ($VMID) {
                if (-not $Node) {
                    $vm = Get-ProxmoxVM -VMID $VMID
                    $Node = $vm.node
                }
                $endpoint = "nodes/$Node/qemu/$VMID/firewall/rules"
            }
            else {
                if (-not $Node) {
                    $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                    $Node = $nodes[0].node
                }
                $endpoint = "nodes/$Node/firewall/rules"
            }

            $rules = Invoke-ProxmoxAPI -Method GET -Endpoint $endpoint
            return $rules
        }
        catch {
            Write-Log "Failed to get firewall rules: $_" -Level Error
            throw
        }
    }
}

function Add-ProxmoxFirewallRule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [int]$VMID,

        [Parameter()]
        [switch]$Cluster,

        [Parameter(Mandatory = $true)]
        [ValidateSet('IN', 'OUT')]
        [string]$Direction,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ACCEPT', 'DROP', 'REJECT')]
        [string]$Action,

        [Parameter()]
        [string]$Source,

        [Parameter()]
        [string]$Destination,

        [Parameter()]
        [string]$Protocol,

        [Parameter()]
        [string]$DPort,

        [Parameter()]
        [string]$SPort,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [switch]$Enable
    )

    process {
        try {
            if ($Cluster) {
                $endpoint = "cluster/firewall/rules"
            }
            elseif ($VMID) {
                if (-not $Node) {
                    $vm = Get-ProxmoxVM -VMID $VMID
                    $Node = $vm.node
                }
                $endpoint = "nodes/$Node/qemu/$VMID/firewall/rules"
            }
            else {
                if (-not $Node) {
                    $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                    $Node = $nodes[0].node
                }
                $endpoint = "nodes/$Node/firewall/rules"
            }

            $ruleConfig = @{
                type = $Direction.ToLower()
                action = $Action.ToLower()
                enable = if ($Enable) { 1 } else { 0 }
            }

            if ($Source) { $ruleConfig.source = $Source }
            if ($Destination) { $ruleConfig.dest = $Destination }
            if ($Protocol) { $ruleConfig.proto = $Protocol }
            if ($DPort) { $ruleConfig.dport = $DPort }
            if ($SPort) { $ruleConfig.sport = $SPort }
            if ($Comment) { $ruleConfig.comment = $Comment }

            $target = if ($VMID) { "VM $VMID" } elseif ($Cluster) { "Cluster" } else { "Node $Node" }

            if ($PSCmdlet.ShouldProcess($target, "Add firewall rule")) {
                Write-Log "Adding firewall rule to $target" -Level Info
                $result = Invoke-ProxmoxAPI -Method POST -Endpoint $endpoint -Body $ruleConfig
                Write-Log "Firewall rule added successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to add firewall rule: $_" -Level Error
            throw
        }
    }
}

function Remove-ProxmoxFirewallRule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [int]$VMID,

        [Parameter()]
        [switch]$Cluster,

        [Parameter(Mandatory = $true)]
        [string]$Pos
    )

    process {
        try {
            if ($Cluster) {
                $endpoint = "cluster/firewall/rules/$Pos"
            }
            elseif ($VMID) {
                if (-not $Node) {
                    $vm = Get-ProxmoxVM -VMID $VMID
                    $Node = $vm.node
                }
                $endpoint = "nodes/$Node/qemu/$VMID/firewall/rules/$Pos"
            }
            else {
                if (-not $Node) {
                    $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                    $Node = $nodes[0].node
                }
                $endpoint = "nodes/$Node/firewall/rules/$Pos"
            }

            $target = if ($VMID) { "VM $VMID" } elseif ($Cluster) { "Cluster" } else { "Node $Node" }

            if ($PSCmdlet.ShouldProcess($target, "Remove firewall rule at position $Pos")) {
                Write-Log "Removing firewall rule at position $Pos from $target" -Level Info
                $result = Invoke-ProxmoxAPI -Method DELETE -Endpoint $endpoint
                Write-Log "Firewall rule removed successfully" -Level Success
                return $result
            }
        }
        catch {
            Write-Log "Failed to remove firewall rule: $_" -Level Error
            throw
        }
    }
}
