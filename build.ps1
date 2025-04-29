[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Build", "Test", "Package", "Publish", "Clean", "All")]
    [string]$Task = "All",

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [string]$OutputPath = "./out",

    [Parameter()]
    [switch]$Force
)

# Build configuration
$CONFIG = @{
    ModuleName = "ProxmoxHelper"
    OutputPath = $OutputPath
    SourcePath = "./src"
    TestPath = "./tests"
    DocsPath = "./docs"
}

# Helper Functions
function Write-TaskHeader($TaskName) {
    Write-Host "`n=== $TaskName ===" -ForegroundColor Cyan
}

function Initialize-BuildEnvironment {
    Write-TaskHeader "Initializing Build Environment"
    
    if (-not (Test-Path $CONFIG.OutputPath)) {
        New-Item -ItemType Directory -Path $CONFIG.OutputPath -Force | Out-Null
    }
    
    # Ensure required modules
    $requiredModules = @(
        @{ Name = "Pester"; MinimumVersion = "5.0.0" }
        @{ Name = "PSScriptAnalyzer"; MinimumVersion = "1.20.0" }
    )
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module.Name)) {
            Write-Host "Installing $($module.Name)..." -ForegroundColor Yellow
            Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -Scope CurrentUser
        }
    }
}

function Start-Build {
    Write-TaskHeader "Building Module"
    
    # Create module output directory
    $moduleOutput = Join-Path $CONFIG.OutputPath $CONFIG.ModuleName
    New-Item -ItemType Directory -Path $moduleOutput -Force | Out-Null
    
    # Copy module files
    Copy-Item -Path "*.ps*1" -Destination $moduleOutput
    Copy-Item -Path "src" -Destination $moduleOutput -Recurse
    Copy-Item -Path "README.md", "LICENSE" -Destination $moduleOutput
    
    # Update version if specified
    if ($Version) {
        $manifestPath = Join-Path $moduleOutput "$($CONFIG.ModuleName).psd1"
        Update-ModuleManifest -Path $manifestPath -ModuleVersion $Version
    }
    
    Write-Host "Module built successfully" -ForegroundColor Green
}

function Start-Tests {
    Write-TaskHeader "Running Tests"
    
    $pesterConfig = @{
        Run = @{
            Path = $CONFIG.TestPath
            PassThru = $true
        }
        CodeCoverage = @{
            Enabled = $true
            Path = "*.ps*1", "src/**/*.ps*1"
            OutputPath = Join-Path $CONFIG.OutputPath "coverage.xml"
        }
        TestResult = @{
            Enabled = $true
            OutputPath = Join-Path $CONFIG.OutputPath "testResults.xml"
        }
    }
    
    $testResults = Invoke-Pester -Configuration $pesterConfig
    
    if ($testResults.FailedCount -gt 0) {
        throw "$($testResults.FailedCount) tests failed"
    }
    
    Write-Host "All tests passed successfully" -ForegroundColor Green
}

function Start-ScriptAnalysis {
    Write-TaskHeader "Running Script Analysis"
    
    $analyzerResults = Invoke-ScriptAnalyzer -Path . -Recurse -Settings .vscode/PSScriptAnalyzerSettings.psd1
    
    if ($analyzerResults) {
        $analyzerResults | Format-Table -AutoSize
        throw "Script analysis found $($analyzerResults.Count) issues"
    }
    
    Write-Host "Script analysis completed successfully" -ForegroundColor Green
}

function Start-Package {
    Write-TaskHeader "Packaging Module"
    
    $moduleOutput = Join-Path $CONFIG.OutputPath $CONFIG.ModuleName
    $archivePath = Join-Path $CONFIG.OutputPath "$($CONFIG.ModuleName).zip"
    
    Compress-Archive -Path $moduleOutput -DestinationPath $archivePath -Force
    
    Write-Host "Module packaged successfully: $archivePath" -ForegroundColor Green
}

function Start-Publish {
    Write-TaskHeader "Publishing Module"
    
    $moduleOutput = Join-Path $CONFIG.OutputPath $CONFIG.ModuleName
    
    try {
        Publish-Module -Path $moduleOutput -NuGetApiKey $env:POWERSHELL_GALLERY_KEY -Force:$Force
        Write-Host "Module published successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to publish module: $_"
        throw
    }
}

function Start-Clean {
    Write-TaskHeader "Cleaning Build Output"
    
    if (Test-Path $CONFIG.OutputPath) {
        Remove-Item -Path $CONFIG.OutputPath -Recurse -Force
    }
    
    Write-Host "Clean completed successfully" -ForegroundColor Green
}

# Main execution
try {
    Initialize-BuildEnvironment
    
    switch ($Task) {
        "Build" {
            Start-Build
        }
        "Test" {
            Start-Tests
            Start-ScriptAnalysis
        }
        "Package" {
            Start-Build
            Start-Package
        }
        "Publish" {
            Start-Build
            Start-Tests
            Start-ScriptAnalysis
            Start-Package
            Start-Publish
        }
        "Clean" {
            Start-Clean
        }
        "All" {
            Start-Clean
            Start-Build
            Start-Tests
            Start-ScriptAnalysis
            Start-Package
        }
    }
}
catch {
    Write-Error "Build failed: $_"
    exit 1
}
