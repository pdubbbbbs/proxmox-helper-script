[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter()]
    [switch]$Draft
)

# Validate version format
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must be in format: X.Y.Z"
}

# Update version
./tools/Update-Version.ps1 -Type Custom -Version $Version

# Generate changelog entry
$changelogPath = "./CHANGELOG.md"
$date = Get-Date -Format "yyyy-MM-dd"
$entry = @"

## [$Version] - $date

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

"@

$changelog = Get-Content $changelogPath
$unreleased = $changelog.IndexOf("## [Unreleased]")
$changelog = $changelog[0..($unreleased)] + $entry + $changelog[($unreleased + 1)..($changelog.Length - 1)]
$changelog | Set-Content $changelogPath

# Run tests
./build.ps1 -Task Test

# Generate documentation
./tools/New-Documentation.ps1

if (-not $Draft) {
    git add .
    git commit -m "Prepare release $Version"
    git tag -a "v$Version" -m "Version $Version"
    git push
    git push --tags
}

Write-Host "Release $Version prepared successfully" -ForegroundColor Green
