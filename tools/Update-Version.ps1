[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Major", "Minor", "Patch")]
    [string]$Type,

    [Parameter()]
    [switch]$Commit
)

$manifestPath = "./ProxmoxHelper.psd1"
$manifest = Import-PowerShellDataFile $manifestPath
$currentVersion = [Version]$manifest.ModuleVersion
$newVersion = switch ($Type) {
    "Major" { [Version]::new($currentVersion.Major + 1, 0, 0) }
    "Minor" { [Version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0) }
    "Patch" { [Version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1) }
}

Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion

if ($Commit) {
    git add $manifestPath
    git commit -m "Bump version to $newVersion"
    git tag -a "v$newVersion" -m "Version $newVersion"
    git push
    git push --tags
}

Write-Host "Version bumped to $newVersion" -ForegroundColor Green
