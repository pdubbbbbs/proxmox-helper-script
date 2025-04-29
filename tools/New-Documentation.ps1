[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "./docs",

    [Parameter()]
    [switch]$GeneratePlatyPS
)

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Generate markdown documentation
if ($GeneratePlatyPS) {
    if (-not (Get-Module -ListAvailable -Name platyPS)) {
        Install-Module -Name platyPS -Force -Scope CurrentUser
    }
    Import-Module ./ProxmoxHelper.psd1 -Force
    New-MarkdownHelp -Module ProxmoxHelper -OutputFolder $OutputPath -Force
}

# Generate function list
$functions = Get-Command -Module ProxmoxHelper
$functionDocs = foreach ($function in $functions) {
    $help = Get-Help $function.Name
    [PSCustomObject]@{
        Name = $function.Name
        Synopsis = $help.Synopsis
        Description = $help.Description.Text
    }
}

$functionDocs | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputPath/functions.json"

# Generate module info
$manifest = Import-PowerShellDataFile ./ProxmoxHelper.psd1
$moduleInfo = [PSCustomObject]@{
    Name = $manifest.RootModule
    Version = $manifest.ModuleVersion
    Description = $manifest.Description
    Author = $manifest.Author
    Functions = $manifest.FunctionsToExport
}

$moduleInfo | ConvertTo-Json -Depth 3 | Set-Content -Path "$OutputPath/module-info.json"

Write-Host "Documentation generated in $OutputPath" -ForegroundColor Green
