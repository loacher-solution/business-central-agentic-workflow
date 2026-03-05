<#
.SYNOPSIS
    Runs BC page scripts (YAML) headlessly against a BC Online Sandbox.
.DESCRIPTION
    Uses @microsoft/bc-replay to execute page script recordings via Playwright.
    Authenticates via AAD with username/password from .env.
.EXAMPLE
    pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/*.yml"
    pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/test-customer.yml" -Headed
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [string]$ResultDir = "",
    [switch]$Headed,
    [string]$StartAddress = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$skillRoot = Split-Path -Parent $PSScriptRoot
$buildPublishSkill = Join-Path $repoRoot ".claude/skills/bc-build-and-publish"

# --- Ensure bc-replay is installed ---
$replayDir = Join-Path $skillRoot "node_modules/@microsoft/bc-replay"
if (-not (Test-Path $replayDir)) {
    Write-Host "bc-replay not found. Running setup..." -ForegroundColor Yellow
    & pwsh -File (Join-Path $PSScriptRoot "setup-replay.ps1")
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Load .env ---
$envFile = Join-Path $buildPublishSkill ".env"
if (-not (Test-Path $envFile)) {
    Write-Error @"
Config not found: $envFile
Run .claude/skills/bc-build-and-publish/scripts/bc-login.ps1 first, then add BC_E2E_USERNAME and BC_E2E_PASSWORD.
"@
    exit 1
}
Get-Content $envFile | Where-Object { $_ -match '^\w+=.+' } | ForEach-Object {
    $key, $val = $_ -split '=', 2
    Set-Variable -Name $key -Value $val
}

# Validate E2E credentials
if ([string]::IsNullOrWhiteSpace($BC_E2E_USERNAME) -or [string]::IsNullOrWhiteSpace($BC_E2E_PASSWORD)) {
    Write-Error @"
E2E credentials missing in .env. Add these lines to $envFile`:
BC_E2E_USERNAME=test.automation@yourdomain.com
BC_E2E_PASSWORD=your-password
"@
    exit 1
}

# --- Build StartAddress ---
if (-not $StartAddress) {
    if ([string]::IsNullOrWhiteSpace($BC_TENANT_ID) -or [string]::IsNullOrWhiteSpace($BC_ENVIRONMENT)) {
        Write-Error "BC_TENANT_ID and BC_ENVIRONMENT must be set in .env"
        exit 1
    }
    $StartAddress = "https://businesscentral.dynamics.com/$BC_TENANT_ID/$BC_ENVIRONMENT"
}
Write-Host "Target: $StartAddress" -ForegroundColor Cyan

# --- Resolve script path ---
if (-not [System.IO.Path]::IsPathRooted($ScriptPath)) {
    $ScriptPath = Join-Path $repoRoot $ScriptPath
}

# --- Set result directory ---
if (-not $ResultDir) {
    $ResultDir = Join-Path $repoRoot "e2e/results"
}
if (-not [System.IO.Path]::IsPathRooted($ResultDir)) {
    $ResultDir = Join-Path $repoRoot $ResultDir
}
if (-not (Test-Path $ResultDir)) {
    New-Item -ItemType Directory -Path $ResultDir -Force | Out-Null
}

# --- Set credentials as env vars ---
$env:BC_E2E_USERNAME = $BC_E2E_USERNAME
$env:BC_E2E_PASSWORD = $BC_E2E_PASSWORD

# --- Run bc-replay ---
Write-Host "`n=== Running Page Scripts ===" -ForegroundColor Cyan
Write-Host "Scripts: $ScriptPath" -ForegroundColor DarkGray
Write-Host "Results: $ResultDir" -ForegroundColor DarkGray
Write-Host ""

$replayArgs = @(
    "replay"
    $ScriptPath
    "-StartAddress", $StartAddress
    "-Authentication", "AAD"
    "-UserNameKey", "BC_E2E_USERNAME"
    "-PasswordKey", "BC_E2E_PASSWORD"
    "-ResultDir", $ResultDir
)
if ($Headed) {
    $replayArgs += "-Headed"
}

Push-Location $skillRoot
try {
    & npx @replayArgs
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    # Clean up env vars
    Remove-Item Env:BC_E2E_USERNAME -ErrorAction SilentlyContinue
    Remove-Item Env:BC_E2E_PASSWORD -ErrorAction SilentlyContinue
}

# --- Summary ---
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "=== ALL PAGE SCRIPTS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== PAGE SCRIPTS FAILED ===" -ForegroundColor Red
    Write-Host "View report: npx playwright show-report $ResultDir/playwright-report" -ForegroundColor Yellow
}
exit $exitCode
