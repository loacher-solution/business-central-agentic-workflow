<#
.SYNOPSIS
    Publishes compiled AL apps to a BC cloud sandbox as Dev extensions.
.DESCRIPTION
    Uses the /dev/apps REST endpoint (same as VS Code F5) to publish apps
    as "Dev" scope instead of PTE. This avoids conflicts with VS Code
    development workflow.

    Reads the environment config and stored refresh token, then publishes
    the src app (and optionally the test app) to the configured BC environment.
    App metadata is read from each app.json.
.EXAMPLE
    .\.claude\skills\bc-build-and-publish\scripts\publish.ps1
    .\.claude\skills\bc-build-and-publish\scripts\publish.ps1 -IncludeTest
    .\.claude\skills\bc-build-and-publish\scripts\publish.ps1 -BuildFirst
    .\.claude\skills\bc-build-and-publish\scripts\publish.ps1 -SchemaUpdateMode ForceSync
#>
param(
    [switch]$IncludeTest,
    [switch]$BuildFirst,
    [ValidateSet("Synchronize", "Recreate", "ForceSync")]
    [string]$SchemaUpdateMode = "Synchronize"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

function Get-AppFileName {
    param([string]$AppJsonPath)

    $app = Get-Content $AppJsonPath -Raw | ConvertFrom-Json
    return "$($app.publisher)_$($app.name)_$($app.version).app"
}

function Publish-DevApp {
    param(
        [string]$AppFilePath,
        [string]$AccessToken,
        [string]$TenantId,
        [string]$Environment,
        [string]$SchemaUpdateMode
    )

    $appName = Split-Path -Leaf $AppFilePath
    Write-Host "  Publishing $appName as Dev..." -ForegroundColor Cyan

    $url = "https://api.businesscentral.dynamics.com/v2.0/$TenantId/$Environment/dev/apps?SchemaUpdateMode=$SchemaUpdateMode"

    # Use MultipartFormDataContent — same as VS Code AL extension and navcontainerhelper
    Add-Type -AssemblyName System.Net.Http
    $httpClient = [System.Net.Http.HttpClient]::new()
    $httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $AccessToken)
    $httpClient.Timeout = [TimeSpan]::FromMinutes(10)

    $fileStream = [System.IO.FileStream]::new($AppFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()

    $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $fileHeader.Name = "`"$appName`""
    $fileHeader.FileName = "`"$appName`""
    $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
    $fileContent.Headers.ContentDisposition = $fileHeader
    $multipartContent.Add($fileContent)

    try {
        $result = $httpClient.PostAsync($url, $multipartContent).GetAwaiter().GetResult()
        $statusCode = [int]$result.StatusCode
        $responseBody = $result.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if ($result.IsSuccessStatusCode) {
            Write-Host "  OK: $appName (HTTP $statusCode)" -ForegroundColor Green
        } else {
            Write-Error "Publish failed for $appName (HTTP $statusCode): $responseBody"
            exit 1
        }
    } finally {
        $fileStream.Dispose()
        $multipartContent.Dispose()
        $httpClient.Dispose()
    }
}

# --- Load .env ---
$skillRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $skillRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error @"
Config not found: $envFile
Run .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 first to authenticate.
"@
    exit 1
}
Get-Content $envFile | Where-Object { $_ -match '^\w+=.+' } | ForEach-Object {
    $key, $val = $_ -split '=', 2
    Set-Variable -Name $key -Value $val
}

if ([string]::IsNullOrWhiteSpace($BC_REFRESH_TOKEN)) {
    Write-Error "Refresh token missing in .env. Run .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 to re-authenticate."
    exit 1
}
$refreshToken = $BC_REFRESH_TOKEN

# --- Build first if requested ---
if ($BuildFirst) {
    Write-Host "Building apps first..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot "build.ps1") -ProjectDir $(if ($IncludeTest) { "all" } else { "src" })
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Authenticate ---
Write-Host "Authenticating to BC environment '$BC_ENVIRONMENT'..." -ForegroundColor Cyan
$authContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $refreshToken

if (-not $authContext -or -not $authContext.AccessToken) {
    Write-Error @"
Authentication failed. Your refresh token may have expired.
Run .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 to re-authenticate.
"@
    exit 1
}

# Save the (possibly renewed) refresh token back to .env
if ($authContext.RefreshToken -and $authContext.RefreshToken -ne $BC_REFRESH_TOKEN) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "BC_REFRESH_TOKEN=.*", "BC_REFRESH_TOKEN=$($authContext.RefreshToken)"
    $envContent | Set-Content $envFile -NoNewline
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

# --- Publish via /dev/apps endpoint (Dev scope, same as VS Code F5) ---
Write-Host "Publishing to '$BC_ENVIRONMENT' as Dev (SchemaUpdateMode=$SchemaUpdateMode)..." -ForegroundColor Cyan

foreach ($appFile in $appFiles) {
    Publish-DevApp `
        -AppFilePath $appFile `
        -AccessToken $authContext.AccessToken `
        -TenantId $BC_TENANT_ID `
        -Environment $BC_ENVIRONMENT `
        -SchemaUpdateMode $SchemaUpdateMode
}

Write-Host "`nPublish completed successfully (Dev scope)." -ForegroundColor Green
