<#
.SYNOPSIS
    Installs @microsoft/bc-replay and Playwright browsers for E2E page script testing.
.DESCRIPTION
    One-time setup: installs the bc-replay npm package and Playwright Chromium browser.
    Cached in .claude/skills/bc-page-scripting/node_modules/ after first run.
.EXAMPLE
    pwsh -File .claude/skills/bc-page-scripting/scripts/setup-replay.ps1
    pwsh -File .claude/skills/bc-page-scripting/scripts/setup-replay.ps1 -Force
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot

# Check Node.js
$nodeVersion = & node --version 2>$null
if (-not $nodeVersion) {
    Write-Error "Node.js not found. Install Node.js 16+ from https://nodejs.org"
    exit 1
}
Write-Host "Node.js: $nodeVersion" -ForegroundColor DarkGray

# Check if already installed
$replayDir = Join-Path $skillRoot "node_modules/@microsoft/bc-replay"
if ((Test-Path $replayDir) -and -not $Force) {
    Write-Host "bc-replay already installed in $skillRoot" -ForegroundColor Green
    Write-Host "Use -Force to reinstall." -ForegroundColor DarkGray
    exit 0
}

# Install bc-replay
Write-Host "Installing @microsoft/bc-replay..." -ForegroundColor Cyan
Push-Location $skillRoot
try {
    # Initialize package.json if needed
    if (-not (Test-Path (Join-Path $skillRoot "package.json"))) {
        & npm init -y 2>$null | Out-Null
    }
    & npm install @microsoft/bc-replay --save
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install @microsoft/bc-replay"
        exit 1
    }
} finally {
    Pop-Location
}

# Install Playwright Chromium
Write-Host "Installing Playwright Chromium browser..." -ForegroundColor Cyan
Push-Location $skillRoot
try {
    & npx playwright install chromium
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Playwright browsers"
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host "`nSetup completed. bc-replay ready in $skillRoot" -ForegroundColor Green
