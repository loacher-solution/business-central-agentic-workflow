<#
.SYNOPSIS
    Publishes compiled AL apps to a BC cloud sandbox.
.DESCRIPTION
    Reads the environment config and stored refresh token, then publishes
    the src app (and optionally the test app) to the configured BC environment.
    App metadata is read from each app.json.
.EXAMPLE
    .\.claude\skills\bc-build\scripts\publish.ps1
    .\.claude\skills\bc-build\scripts\publish.ps1 -IncludeTest
    .\.claude\skills\bc-build\scripts\publish.ps1 -BuildFirst
#>
param(
    [switch]$IncludeTest,
    [switch]$BuildFirst
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

function Get-AppFileName {
    param([string]$AppJsonPath)

    $app = Get-Content $AppJsonPath -Raw | ConvertFrom-Json
    return "$($app.publisher)_$($app.name)_$($app.version).app"
}

# --- Load config ---
$envFile = Join-Path $PSScriptRoot ".env.ps1"
if (-not (Test-Path $envFile)) {
    Write-Error @"
Environment config not found: $envFile
Run .\.claude\skills\bc-build\scripts\bc-login.ps1 first to configure authentication.
"@
    exit 1
}
. $envFile

# --- Load refresh token ---
$tokenFile = Join-Path $PSScriptRoot ".auth-token"
if (-not (Test-Path $tokenFile)) {
    Write-Error @"
Auth token not found: $tokenFile
Run .\.claude\skills\bc-build\scripts\bc-login.ps1 first to authenticate.
"@
    exit 1
}
$refreshToken = Get-Content $tokenFile -Raw | ForEach-Object { $_.Trim() }

if ([string]::IsNullOrWhiteSpace($refreshToken)) {
    Write-Error "Auth token file is empty. Run .\.claude\skills\bc-build\scripts\bc-login.ps1 to re-authenticate."
    exit 1
}

# --- Build first if requested ---
if ($BuildFirst) {
    Write-Host "Building apps first..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "build.ps1") -ProjectDir $(if ($IncludeTest) { "all" } else { "src" })
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Authenticate ---
Write-Host "Authenticating to BC environment '$BC_ENVIRONMENT'..." -ForegroundColor Cyan
$authContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $refreshToken

if (-not $authContext) {
    Write-Error @"
Authentication failed. Your refresh token may have expired.
Run .\.claude\skills\bc-build\scripts\bc-login.ps1 to re-authenticate.
"@
    exit 1
}

# Save the (possibly renewed) refresh token
if ($authContext.RefreshToken) {
    $authContext.RefreshToken | Set-Content $tokenFile -NoNewline
}

# --- Collect app files ---
$srcAppJson = Join-Path $repoRoot "src/app.json"
$srcAppFile = Get-AppFileName $srcAppJson
$srcApp = Join-Path $repoRoot "src/.build/$srcAppFile"
if (-not (Test-Path $srcApp)) {
    Write-Error "Src app not found at $srcApp. Run build.ps1 first."
    exit 1
}

$appFiles = @($srcApp)

if ($IncludeTest) {
    $testAppJson = Join-Path $repoRoot "test/app.json"
    $testAppFile = Get-AppFileName $testAppJson
    $testApp = Join-Path $repoRoot "test/.build/$testAppFile"
    if (-not (Test-Path $testApp)) {
        Write-Error "Test app not found at $testApp. Run build.ps1 -ProjectDir all first."
        exit 1
    }
    $appFiles += $testApp
}

# --- Publish ---
Write-Host "Publishing to '$BC_ENVIRONMENT'..." -ForegroundColor Cyan
Publish-PerTenantExtensionApps `
    -bcAuthContext $authContext `
    -environment $BC_ENVIRONMENT `
    -appFiles $appFiles `
    -schemaSyncMode "Add"

Write-Host "`nPublish completed successfully." -ForegroundColor Green
