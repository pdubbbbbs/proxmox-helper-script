[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Update
)

$manifest = Import-PowerShellDataFile ./ProxmoxHelper.psd1
$requiredModules = $manifest.RequiredModules

foreach ($module in $requiredModules) {
    $name = if ($module -is [string]) { $module } else { $module.ModuleName }
    $requiredVersion = if ($module -is [string]) { $null } else { $module.ModuleVersion }
    
    $installed = Get-Module -ListAvailable -Name $name
    
    if (-not $installed) {
        Write-Host "Missing required module: $name" -ForegroundColor Red
        if ($Update) {
            Write-Host "Installing $name..." -ForegroundColor Yellow
            Install-Module -Name $name -Force -Scope CurrentUser
        }
        continue
    }
    
    if ($requiredVersion -and ($installed.Version -lt $requiredVersion)) {
        Write-Host "Module $name version $($installed.Version) is below required version $requiredVersion" -ForegroundColor Yellow
        if ($Update) {
            Write-Host "Updating $name..." -ForegroundColor Yellow
            Update-Module -Name $name -Force
        }
        continue
    }
    
    Write-Host "Module $name version $($installed.Version) is up to date" -ForegroundColor Green
}
