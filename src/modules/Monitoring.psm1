# Monitoring Module
# Part of Proxmox Helper Script

function Get-ProxmoxClusterStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeResources,

        [Parameter()]
        [switch]$IncludeServices
    )

    process {
        try {
            $status = Invoke-ProxmoxAPI -Method GET -Endpoint "cluster/status"

            if ($IncludeResources) {
                $resources = Invoke-ProxmoxAPI -Method GET -Endpoint "cluster/resources"
                $status | Add-Member -MemberType NoteProperty -Name 'Resources' -Value $resources
            }

            if ($IncludeServices) {
                $services = Invoke-ProxmoxAPI -Method GET -Endpoint "cluster/services"
                $status | Add-Member -MemberType NoteProperty -Name 'Services' -Value $services
            }

            return $status
        }
        catch {
            Write-Log "Failed to get cluster status: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxNodeMetrics {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [ValidateSet('hour', 'day', 'week', 'month', 'year')]
        [string]$TimeFrame = 'hour',

        [Parameter()]
        [ValidateSet('cpu', 'memory', 'network', 'storage', 'all')]
        [string]$MetricType = 'all'
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $nodes = Invoke-ProxmoxAPI -Method GET -Endpoint 'nodes'
                $Node = $nodes[0].node
            }

            $metrics = @{}

            switch ($MetricType) {
                'cpu' {
                    $metrics.CPU = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'cpu'
                    }
                }
                'memory' {
                    $metrics.Memory = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'memory'
                    }
                }
                'network' {
                    $metrics.Network = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'netin,netout'
                    }
                }
                'storage' {
                    $metrics.Storage = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'rootfs'
                    }
                }
                'all' {
                    $metrics = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                    }
                }
            }

            return $metrics
        }
        catch {
            Write-Log "Failed to get node metrics: $_" -Level Error
            throw
        }
    }
}

function Get-ProxmoxVMMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [ValidateSet('hour', 'day', 'week', 'month', 'year')]
        [string]$TimeFrame = 'hour',

        [Parameter()]
        [ValidateSet('cpu', 'memory', 'network', 'disk', 'all')]
        [string]$MetricType = 'all'
    )

    process {
        try {
            # Get node if not specified
            if (-not $Node) {
                $vm = Get-ProxmoxVM -VMID $VMID
                $Node = $vm.node
            }

            $metrics = @{}

            switch ($MetricType) {
                'cpu' {
                    $metrics.CPU = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'cpu'
                    }
                }
                'memory' {
                    $metrics.Memory = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'mem'
                    }
                }
                'network' {
                    $metrics.Network = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'netin,netout'
                    }
                }
                'disk' {
                    $metrics.Disk = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                        ds = 'diskread,diskwrite'
                    }
                }
                'all' {
                    $metrics = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/qemu/$VMID/rrddata" -Body @{
                        timeframe = $TimeFrame
                        cf = 'AVERAGE'
                    }
                }
            }

            return $metrics
        }
        catch {
            Write-Log "Failed to get VM metrics: $_" -Level Error
            throw
        }
    }
}

function Test-ProxmoxHealth {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Node,

        [Parameter()]
        [switch]$IncludeStorage,

        [Parameter()]
        [switch]$IncludeNetwork,

        [Parameter()]
        [switch]$IncludeServices
    )

    process {
        try {
            $healthReport = @{
                Timestamp = Get-Date
                Status = 'Healthy'
                Issues = @()
                Details = @{}
            }

            # Check cluster status
            $cluster = Get-ProxmoxClusterStatus
            $healthReport.Details.Cluster = $cluster

            if ($cluster.quorum -ne 1) {
                $healthReport.Status = 'Warning'
                $healthReport.Issues += "Cluster quorum is not established"
            }

            # Check nodes
            $nodes = if ($Node) { @(Get-ProxmoxNode -Node $Node) } else { Get-ProxmoxNode }
            $healthReport.Details.Nodes = $nodes

            foreach ($n in $nodes) {
                if ($n.status -ne 'online') {
                    $healthReport.Status = 'Critical'
                    $healthReport.Issues += "Node '$($n.node)' is $($n.status)"
                }

                # Check CPU usage
                $metrics = Get-ProxmoxNodeMetrics -Node $n.node -MetricType cpu -TimeFrame hour
                $latestCPU = ($metrics.CPU | Select-Object -Last 1).cpu
                if ($latestCPU -gt 90) {
                    $healthReport.Status = 'Warning'
                    $healthReport.Issues += "Node '$($n.node)' CPU usage is high ($latestCPU%)"
                }

                # Check memory usage
                $metrics = Get-ProxmoxNodeMetrics -Node $n.node -MetricType memory -TimeFrame hour
                $latestMem = ($metrics.Memory | Select-Object -Last 1).memory
                if ($latestMem -gt 90) {
                    $healthReport.Status = 'Warning'
                    $healthReport.Issues += "Node '$($n.node)' memory usage is high ($latestMem%)"
                }
            }

            if ($IncludeStorage) {
                $storage = Get-ProxmoxStorage -IncludeUsage
                $healthReport.Details.Storage = $storage

                foreach ($s in $storage) {
                    if ($s.active -ne 1) {
                        $healthReport.Status = 'Critical'
                        $healthReport.Issues += "Storage '$($s.storage)' is not active"
                    }

                    if ($s.Usage) {
                        $usedPercent = ($s.Usage.used / $s.Usage.total) * 100
                        if ($usedPercent -gt 90) {
                            $healthReport.Status = 'Warning'
                            $healthReport.Issues += "Storage '$($s.storage)' usage is high ($([math]::Round($usedPercent, 2))%)"
                        }
                    }
                }
            }

            if ($IncludeNetwork) {
                $network = Get-ProxmoxNetwork -IncludeUsage
                $healthReport.Details.Network = $network

                foreach ($n in $network) {
                    if (-not $n.active) {
                        $healthReport.Status = 'Warning'
                        $healthReport.Issues += "Network interface '$($n.iface)' is not active"
                    }
                }
            }

            if ($IncludeServices) {
                $services = Invoke-ProxmoxAPI -Method GET -Endpoint "nodes/$Node/services"
                $healthReport.Details.Services = $services

                foreach ($s in $services) {
                    if ($s.state -ne 'running') {
                        $healthReport.Status = 'Warning'
                        $healthReport.Issues += "Service '$($s.name)' is not running"
                    }
                }
            }

            return $healthReport
        }
        catch {
            Write-Log "Failed to perform health check: $_" -Level Error
            throw
        }
    }
}

function Watch-ProxmoxMetrics {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$VMID,

        [Parameter()]
        [string]$Node,

        [Parameter()]
        [ValidateSet('cpu', 'memory', 'network', 'disk', 'all')]
        [string]$MetricType = 'all',

        [Parameter()]
        [int]$RefreshInterval = 5,

        [Parameter()]
        [int]$Duration = 300
    )

    process {
        try {
            $endTime = (Get-Date).AddSeconds($Duration)
            $iteration = 1

            while ((Get-Date) -lt $endTime) {
                Clear-Host
                Write-Host "Proxmox Metrics Monitor - Iteration $iteration" -ForegroundColor Cyan
                Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
                Write-Host "----------------------------------------" -ForegroundColor Cyan

                if ($VMID) {
                    $metrics = Get-ProxmoxVMMetrics -VMID $VMID -Node $Node -MetricType $MetricType
                    Write-Host "VM $VMID Metrics:" -ForegroundColor Green
                } else {
                    $metrics = Get-ProxmoxNodeMetrics -Node $Node -MetricType $MetricType
                    Write-Host "Node $Node Metrics:" -ForegroundColor Green
                }

                foreach ($key in $metrics.Keys) {
                    Write-Host "
$key:" -ForegroundColor Yellow
                    $latest = $metrics[$key] | Select-Object -Last 1
                    foreach ($prop in $latest.PSObject.Properties) {
                        Write-Host "  $($prop.Name): $($prop.Value)" -ForegroundColor White
                    }
                }

                Write-Host "
Next update in $RefreshInterval seconds..." -ForegroundColor Gray
                Start-Sleep -Seconds $RefreshInterval
                $iteration++
            }
        }
        catch {
            Write-Log "Failed to monitor metrics: $_" -Level Error
            throw
        }
    }
}
