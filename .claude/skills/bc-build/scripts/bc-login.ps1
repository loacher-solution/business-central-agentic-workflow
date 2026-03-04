<#
.SYNOPSIS
    Log in to Business Central cloud sandbox (interactive).
.DESCRIPTION
    This script requires a human — it opens a browser for device login.
    Run it when:
    - Setting up a new machine for the first time
    - The refresh token has expired (~90 days)
    - Publish fails with an authentication error

    The Tenant ID is automatically detected from your login.
.EXAMPLE
    .\.claude\skills\bc-build\scripts\bc-login.ps1
    .\.claude\skills\bc-build\scripts\bc-login.ps1 -Environment "production"
#>
param(
    [string]$Environment = "ai-test"
)

$ErrorActionPreference = "Stop"

# --- Load existing config if present ---
$envFile = Join-Path $PSScriptRoot ".env.ps1"
if (Test-Path $envFile) {
    . $envFile
    Write-Host "Existing config: tenant=$BC_TENANT_ID, environment=$BC_ENVIRONMENT" -ForegroundColor DarkGray
}

# --- Device login (tenant=common → auto-detect from user) ---
Write-Host "`nSigning in to Business Central..." -ForegroundColor Cyan
Write-Host "A browser window will open. Sign in with your BC account.`n" -ForegroundColor Yellow

$authContext = New-BcAuthContext `
    -tenantID "common" `
    -includeDeviceLogin `
    -deviceLoginTimeout ([TimeSpan]::FromMinutes(5))

if (-not $authContext -or -not $authContext.AccessToken) {
    Write-Error "Authentication failed or timed out. Please try again."
    exit 1
}

# --- Extract Tenant ID from the access token ---
$tokenParts = $authContext.AccessToken.Split('.')
$payload = $tokenParts[1]
# Fix Base64 padding
switch ($payload.Length % 4) {
    2 { $payload += '==' }
    3 { $payload += '=' }
}
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
$claims = $decoded | ConvertFrom-Json
$TenantId = $claims.tid

Write-Host "Detected Tenant ID: $TenantId" -ForegroundColor Green

# --- Save config ---
@"
# BC environment configuration - DO NOT COMMIT
`$BC_TENANT_ID = "$TenantId"
`$BC_ENVIRONMENT = "$Environment"
"@ | Set-Content $envFile

# --- Save refresh token ---
$tokenFile = Join-Path $PSScriptRoot ".auth-token"
$authContext.RefreshToken | Set-Content $tokenFile -NoNewline

Write-Host "Login successful!" -ForegroundColor Green
Write-Host "Token saved (valid ~90 days). Re-run this script to renew.`n" -ForegroundColor DarkGray

# --- Verify ---
try {
    $verifyContext = New-BcAuthContext -tenantID $TenantId -refreshToken $authContext.RefreshToken
    $apps = Get-BcEnvironmentPublishedApps -bcAuthContext $verifyContext -environment $Environment
    Write-Host "Connected to '$Environment' - $($apps.Count) apps installed." -ForegroundColor Green
} catch {
    Write-Warning "Could not verify connection to '$Environment': $_"
    Write-Warning "Check that environment '$Environment' exists. You can change it with: $($MyInvocation.MyCommand.Name) -Environment <name>"
}
