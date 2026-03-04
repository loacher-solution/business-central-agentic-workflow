<#
.SYNOPSIS
    Downloads BC platform artifacts and extracts the headless client DLLs needed for test execution.
.DESCRIPTION
    Uses BcContainerHelper to download Business Central platform artifacts.
    Extracts Microsoft.Dynamics.Framework.UI.Client.dll and dependencies
    needed by ClientContext to run tests headlessly against an online sandbox.

    Artifacts are cached in C:\bcartifacts.cache by BcContainerHelper.
    The extracted DLLs are stored in .claude/skills/bc-test-runner/.artifacts/
.EXAMPLE
    .\.claude\skills\bc-test-runner\scripts\setup-artifacts.ps1
    .\.claude\skills\bc-test-runner\scripts\setup-artifacts.ps1 -Version "27.0"
#>
param(
    [string]$Version = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = Join-Path $skillRoot ".artifacts"

# Check if already set up
if ((Test-Path (Join-Path $artifactDir "Microsoft.Dynamics.Framework.UI.Client.dll")) -and -not $Force) {
    Write-Host "Client DLLs already cached in $artifactDir" -ForegroundColor Green
    Write-Host "Use -Force to re-download." -ForegroundColor DarkGray
    exit 0
}

# Ensure BcContainerHelper is available
if (-not (Get-Module -ListAvailable -Name BcContainerHelper)) {
    Write-Error "BcContainerHelper module not found. Install it with: Install-Module BcContainerHelper -Force"
    exit 1
}
Import-Module BcContainerHelper -DisableNameChecking

# Get artifact URL
Write-Host "Resolving BC artifact URL..." -ForegroundColor Cyan
$artifactUrlParams = @{
    type    = "Sandbox"
    country = "w1"
}
if ($Version) {
    $artifactUrlParams.version = $Version
}
$artifactUrl = Get-BCArtifactUrl @artifactUrlParams
if (-not $artifactUrl) {
    Write-Error "Could not resolve BC artifact URL."
    exit 1
}
Write-Host "  Artifact URL: $artifactUrl" -ForegroundColor DarkGray

# Download artifacts (platform only)
Write-Host "Downloading BC platform artifacts..." -ForegroundColor Cyan
$downloadedPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
$platformPath = $downloadedPaths[1]  # Second element is the platform path

if (-not $platformPath -or -not (Test-Path $platformPath)) {
    Write-Error "Platform artifacts not found after download."
    exit 1
}
Write-Host "  Platform path: $platformPath" -ForegroundColor DarkGray

# Find and copy client DLLs
Write-Host "Extracting client DLLs..." -ForegroundColor Cyan

# Create output directory
if (-not (Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

# Copy ALL DLLs from "Test Assemblies" — this contains the complete dependency set
$testAssembliesPath = Join-Path $platformPath "Test Assemblies"
if (Test-Path $testAssembliesPath) {
    $dlls = Get-ChildItem -Path $testAssembliesPath -Filter "*.dll"
    foreach ($dll in $dlls) {
        Copy-Item -Path $dll.FullName -Destination $artifactDir -Force
        Write-Host "  OK: $($dll.Name)" -ForegroundColor Green
    }
} else {
    Write-Error "Test Assemblies folder not found at $testAssembliesPath"
    exit 1
}

# Verify critical DLL
if (-not (Test-Path (Join-Path $artifactDir "Microsoft.Dynamics.Framework.UI.Client.dll"))) {
    Write-Error "Critical DLL Microsoft.Dynamics.Framework.UI.Client.dll not found."
    exit 1
}

# Also copy the ClientContext.ps1 and PsTestFunctions.ps1 from BcContainerHelper
$bcHelperPath = (Get-Module BcContainerHelper -ListAvailable | Select-Object -First 1).ModuleBase
$helperScripts = @("ClientContext.ps1", "PsTestFunctions.ps1")
foreach ($script in $helperScripts) {
    $scriptPath = Join-Path $bcHelperPath "AppHandling\$script"
    if (Test-Path $scriptPath) {
        Copy-Item -Path $scriptPath -Destination $artifactDir -Force
        Write-Host "  OK: $script" -ForegroundColor Green
    } else {
        Write-Error "$script not found at $scriptPath"
        exit 1
    }
}

Write-Host "`nSetup completed. Client DLLs cached in $artifactDir" -ForegroundColor Green
