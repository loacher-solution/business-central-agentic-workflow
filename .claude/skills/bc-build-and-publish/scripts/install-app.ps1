<#
.SYNOPSIS
    Installs an AppSource app into a BC cloud sandbox via Admin Center API.
.DESCRIPTION
    Generic script to install any AppSource app by its ID. Uses the Admin Center
    API install endpoint with EULA acceptance and automatic dependency installation.
    If the app is already installed, exits 0 immediately (no overhead).
.EXAMPLE
    .\install-app.ps1 -AppId "23de40a6-dfe8-4f80-80db-d70f83ce8caf" -AppName "Test Runner"
    .\install-app.ps1 -AppId "5d86850b-0d76-4eca-bd7b-951ad998e997" -AppName "Tests-TestLibraries"
    .\install-app.ps1 -AppId "23de40a6-dfe8-4f80-80db-d70f83ce8caf" -AppName "Test Runner" -Force
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    [string]$AppName = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot

if ($AppName) {
    $displayName = "'$AppName' ($AppId)"
} else {
    $displayName = $AppId
}

# --- Ensure BcContainerHelper ---
if (-not (Get-Module -ListAvailable -Name BcContainerHelper)) {
    Write-Error "BcContainerHelper module not found. Install: Install-Module BcContainerHelper -Force"
    exit 1
}
Import-Module BcContainerHelper -DisableNameChecking

# --- Load .env ---
$envFile = Join-Path $skillRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "Config not found: $envFile`nRun bc-login.ps1 first."
    exit 1
}
Get-Content $envFile | Where-Object { $_ -match '^\w+=.+' } | ForEach-Object {
    $key, $val = $_ -split '=', 2
    Set-Variable -Name $key -Value $val
}
if ([string]::IsNullOrWhiteSpace($BC_REFRESH_TOKEN)) {
    Write-Error "Refresh token missing. Run bc-login.ps1."
    exit 1
}

# --- Authenticate ---
Write-Host "Authenticating..." -ForegroundColor Cyan
$authContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $BC_REFRESH_TOKEN

if (-not $authContext -or -not $authContext.AccessToken) {
    Write-Error "Authentication failed. Run bc-login.ps1 to re-authenticate."
    exit 1
}

# Save renewed refresh token
if ($authContext.RefreshToken -and $authContext.RefreshToken -ne $BC_REFRESH_TOKEN) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "BC_REFRESH_TOKEN=.*", "BC_REFRESH_TOKEN=$($authContext.RefreshToken)"
    $envContent | Set-Content $envFile -NoNewline
}

# --- Check current installation ---
$baseApiUrl = "https://api.businesscentral.dynamics.com/admin/v2.21/applications/businesscentral/environments/$BC_ENVIRONMENT"
$headers = @{ "Authorization" = "Bearer $($authContext.AccessToken)" }

Write-Host "Checking if $displayName is installed..." -ForegroundColor Cyan
try {
    $installedApps = Invoke-RestMethod -Method Get -Uri "$baseApiUrl/apps" -Headers $headers
    $existingApp = $installedApps.value | Where-Object { $_.id -eq $AppId }
} catch {
    Write-Error "Failed to query installed apps: $($_.Exception.Message)"
    exit 1
}

if ($existingApp -and -not $Force) {
    Write-Host "$displayName is already installed (v$($existingApp.version))." -ForegroundColor Green
    exit 0
}

if ($existingApp -and $Force) {
    Write-Host "$displayName is installed (v$($existingApp.version)) but -Force specified. Reinstalling..." -ForegroundColor Yellow
}

# --- Install ---
Write-Host "Installing $displayName from AppSource..." -ForegroundColor Yellow
$installBody = @{
    acceptIsvEula = $true
    installOrUpdateNeededDependencies = $true
} | ConvertTo-Json

$installUri = "$baseApiUrl/apps/$AppId/install"
Write-Host "  POST $installUri" -ForegroundColor DarkGray
try {
    $null = Invoke-RestMethod -Method Post `
        -Uri $installUri `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $installBody
    Write-Host "  Install request accepted. Waiting for completion..." -ForegroundColor Yellow
} catch {
    $errMsg = $_.Exception.Message
    # Try to extract response body for more details
    $responseBody = ""
    try {
        $response = $_.Exception.Response
        if ($response) {
            $stream = $response.GetResponseStream()
            $stream.Position = 0
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
        }
    } catch {}
    if ($errMsg -match "already installed" -or $responseBody -match "already installed") {
        Write-Host "$displayName is already installed." -ForegroundColor Green
        exit 0
    }
    Write-Error "Install request failed: $errMsg"
    if ($responseBody) {
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

# --- Poll for completion ---
$maxWait = 300
$elapsed = 0
$interval = 10
$installed = $false

while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds $interval
    $elapsed += $interval

    $authContext = Renew-BcAuthContext $authContext
    $headers = @{ "Authorization" = "Bearer $($authContext.AccessToken)" }

    try {
        $apps = Invoke-RestMethod -Method Get -Uri "$baseApiUrl/apps" -Headers $headers
        $app = $apps.value | Where-Object { $_.id -eq $AppId }
        if ($app) {
            Write-Host "$displayName installed successfully (v$($app.version)) after ${elapsed}s." -ForegroundColor Green
            $installed = $true
            break
        }
    } catch {
        # Transient error during polling, continue
    }
    Write-Host "  Waiting... (${elapsed}s)" -ForegroundColor DarkGray
}

if (-not $installed) {
    Write-Error "$displayName installation did not complete within ${maxWait}s. Check BC Admin Center for status."
    exit 1
}

exit 0
