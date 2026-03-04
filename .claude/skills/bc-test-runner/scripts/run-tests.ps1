<#
.SYNOPSIS
    Runs AL tests against a BC Online Sandbox headlessly (no Docker, no browser).
.DESCRIPTION
    Uses BcContainerHelper's ClientContext to connect to a BC Online Sandbox
    and run tests via Page 130455 (AL Test Tool). The headless client DLLs
    are loaded from the local artifact cache.

    This script:
    1. Optionally builds and publishes both src and test apps
    2. Authenticates via refresh token
    3. Creates a headless ClientContext to the sandbox
    4. Runs tests and collects results
    5. Outputs structured pass/fail summary
.EXAMPLE
    .\.claude\skills\bc-test-runner\scripts\run-tests.ps1
    .\.claude\skills\bc-test-runner\scripts\run-tests.ps1 -SkipPublish
    .\.claude\skills\bc-test-runner\scripts\run-tests.ps1 -TestCodeunit 50200
    .\.claude\skills\bc-test-runner\scripts\run-tests.ps1 -TestFunction "TestMyFeature"
    .\.claude\skills\bc-test-runner\scripts\run-tests.ps1 -Detailed
#>
param(
    [switch]$SkipPublish,
    [string]$TestCodeunit = "*",
    [string]$TestFunction = "*",
    [string]$TestSuite = "DEFAULT",
    [switch]$Detailed,
    [string]$JUnitResultFileName = "",
    [switch]$BuildOnly,
    [string]$TestAppPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$skillRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = Join-Path $skillRoot ".artifacts"
$buildPublishSkill = Join-Path $repoRoot ".claude\skills\bc-build-and-publish"

# --- Ensure artifacts are set up ---
$clientDll = Join-Path $artifactDir "Microsoft.Dynamics.Framework.UI.Client.dll"
if (-not (Test-Path $clientDll)) {
    Write-Host "Client DLLs not found. Running setup..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "setup-artifacts.ps1")
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Ensure BcContainerHelper is available ---
if (-not (Get-Module -ListAvailable -Name BcContainerHelper)) {
    Write-Error "BcContainerHelper module not found. Install it with: Install-Module BcContainerHelper -Force"
    exit 1
}
Import-Module BcContainerHelper -DisableNameChecking

# --- Load .env ---
$envFile = Join-Path $buildPublishSkill ".env"
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
    Write-Error "Refresh token missing in .env. Run bc-login.ps1 to re-authenticate."
    exit 1
}

# --- Build & Publish (unless skipped) ---
if (-not $SkipPublish) {
    Write-Host "Building and publishing apps (src + test)..." -ForegroundColor Cyan
    $publishScript = Join-Path $buildPublishSkill "scripts\publish.ps1"
    & powershell -ExecutionPolicy Bypass -File $publishScript -BuildFirst -IncludeTest
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build/publish failed. Fix errors before running tests."
        exit 1
    }
    Write-Host ""
}

if ($BuildOnly) {
    Write-Host "Build completed. Skipping test execution (-BuildOnly)." -ForegroundColor Green
    exit 0
}

# --- Authenticate ---
# We need two auth contexts:
# 1. API scope (for Admin Center API — install Test Runner)
# 2. Client Service scope (for ClientContext — run tests)
Write-Host "Authenticating to BC environment '$BC_ENVIRONMENT'..." -ForegroundColor Cyan

# API-scoped context (for deployment URL lookup and Test Runner install)
$apiAuthContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $BC_REFRESH_TOKEN
if (-not $apiAuthContext -or -not $apiAuthContext.AccessToken) {
    Write-Error @"
Authentication failed. Your refresh token may have expired.
Run .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 to re-authenticate.
"@
    exit 1
}

# Save renewed refresh token
if ($apiAuthContext.RefreshToken -and $apiAuthContext.RefreshToken -ne $BC_REFRESH_TOKEN) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "BC_REFRESH_TOKEN=.*", "BC_REFRESH_TOKEN=$($apiAuthContext.RefreshToken)"
    $envContent | Set-Content $envFile -NoNewline
    $BC_REFRESH_TOKEN = $apiAuthContext.RefreshToken
}

# Client Service-scoped context (for headless test execution)
$bcAuthContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $BC_REFRESH_TOKEN -scopes "https://projectmadeira.com/user_impersonation offline_access"
if (-not $bcAuthContext -or -not $bcAuthContext.AccessToken) {
    Write-Error "Failed to get Client Service token."
    exit 1
}

# --- Ensure Test Runner is installed ---
$testRunnerAppId = "23de40a6-dfe8-4f80-80db-d70f83ce8caf"
Write-Host "Checking Test Runner installation..." -ForegroundColor Cyan
$apiAuthContext = Renew-BcAuthContext $apiAuthContext
$headers = @{ "Authorization" = "Bearer $($apiAuthContext.AccessToken)" }
try {
    $installedApps = Invoke-RestMethod -Method Get `
        -Uri "https://api.businesscentral.dynamics.com/admin/v2.21/applications/businesscentral/environments/$BC_ENVIRONMENT/apps" `
        -Headers $headers
    $testRunner = $installedApps.value | Where-Object { $_.id -eq $testRunnerAppId }
    if ($testRunner) {
        Write-Host "  Test Runner already installed (v$($testRunner.version))" -ForegroundColor Green
    } else {
        Write-Host "  Test Runner not found. Installing from AppSource..." -ForegroundColor Yellow
        $installBody = @{
            acceptIsvEula = $true
            installOrUpdateNeededDependencies = $true
        } | ConvertTo-Json
        $installResult = Invoke-RestMethod -Method Post `
            -Uri "https://api.businesscentral.dynamics.com/admin/v2.21/applications/businesscentral/environments/$BC_ENVIRONMENT/apps/$testRunnerAppId/install" `
            -Headers $headers `
            -ContentType "application/json" `
            -Body $installBody
        $operationId = $installResult.id
        Write-Host "  Installation started (operation: $operationId). Waiting for completion..." -ForegroundColor Yellow

        # Poll until installation completes (max 5 minutes)
        $maxWait = 300
        $elapsed = 0
        $interval = 10
        while ($elapsed -lt $maxWait) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            $apiAuthContext = Renew-BcAuthContext $apiAuthContext
            $headers = @{ "Authorization" = "Bearer $($apiAuthContext.AccessToken)" }
            try {
                $apps = Invoke-RestMethod -Method Get `
                    -Uri "https://api.businesscentral.dynamics.com/admin/v2.21/applications/businesscentral/environments/$BC_ENVIRONMENT/apps" `
                    -Headers $headers
                $tr = $apps.value | Where-Object { $_.id -eq $testRunnerAppId }
                if ($tr) {
                    Write-Host "  Test Runner installed (v$($tr.version)) after ${elapsed}s" -ForegroundColor Green
                    break
                }
            } catch {}
            Write-Host "  Still waiting... (${elapsed}s)" -ForegroundColor DarkGray
        }
        if ($elapsed -ge $maxWait) {
            Write-Host "  WARN: Test Runner install may still be in progress. Continuing anyway..." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  WARN: Could not check/install Test Runner: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  If tests fail, install 'Test Runner' from AppSource manually." -ForegroundColor Yellow
}

# --- Get test app extension ID ---
if (-not $TestAppPath) {
    Write-Error @"
-TestAppPath is required. Pass the path to the test app's app.json file.
Example: -TestAppPath "test/app.json"
"@
    exit 1
}
# Resolve relative paths against repo root
if (-not [System.IO.Path]::IsPathRooted($TestAppPath)) {
    $TestAppPath = Join-Path $repoRoot $TestAppPath
}
if (-not (Test-Path $TestAppPath)) {
    Write-Error "Test app.json not found at: $TestAppPath"
    exit 1
}
$testApp = Get-Content $TestAppPath -Raw | ConvertFrom-Json
$extensionId = $testApp.id
Write-Host "  Test app: $($testApp.name) ($extensionId)" -ForegroundColor DarkGray

# --- Resolve service URL ---
Write-Host "Resolving sandbox URL..." -ForegroundColor Cyan
$bcAuthContext = Renew-BcAuthContext $bcAuthContext
$accessToken = $bcAuthContext.AccessToken
$apiAuthContext = Renew-BcAuthContext $apiAuthContext

$tenant = "default"
try {
    $response = Invoke-RestMethod -Method Get -Uri "$($bcContainerHelperConfig.baseUrl.TrimEnd('/'))/$($bcAuthContext.tenantID)/$BC_ENVIRONMENT/deployment/url"
    $deploymentUrl = $response.data

    # Parse the deployment URL to extract base URL and tenant
    $uri = [System.Uri]$deploymentUrl
    $publicWebBaseUrl = "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)".TrimEnd('/')

    # Extract tenant from query string if present
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    $queryParams = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
    if ($queryParams['tenant']) {
        $tenant = $queryParams['tenant']
    }
} catch {
    # Fallback: construct URL directly
    $publicWebBaseUrl = "https://businesscentral.dynamics.com/$($bcAuthContext.tenantID)/$BC_ENVIRONMENT"
    $tenant = $bcAuthContext.tenantID
}
$serviceUrl = "$publicWebBaseUrl/cs?tenant=$tenant"
Write-Host "  Base URL: $publicWebBaseUrl" -ForegroundColor DarkGray
Write-Host "  Service URL: $serviceUrl" -ForegroundColor DarkGray

# --- Load ClientContext and PsTestFunctions ---
$clientContextScript = Join-Path $artifactDir "ClientContext.ps1"
$testFunctionsScript = Join-Path $artifactDir "PsTestFunctions.ps1"
$newtonSoftDll = Join-Path $artifactDir "Newtonsoft.Json.dll"

if (-not (Test-Path $testFunctionsScript) -or -not (Test-Path $clientContextScript)) {
    Write-Error "Helper scripts not found in $artifactDir. Run setup-artifacts.ps1 first."
    exit 1
}

# Pre-load all dependency DLLs from the artifacts directory (ignore load failures for optional DLLs)
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
Get-ChildItem -Path $artifactDir -Filter "*.dll" | Where-Object {
    $_.Name -ne "Microsoft.Dynamics.Framework.UI.Client.dll" -and $_.Name -ne "Newtonsoft.Json.dll"
} | ForEach-Object {
    try { Add-Type -Path $_.FullName 2>$null } catch {}
}
$ErrorActionPreference = $prevEAP

# PsTestFunctions.ps1 loads the main DLLs and dot-sources ClientContext.ps1
# Temporarily lower error pref since AntiSSRF.dll may fail to load (optional, not critical)
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
. $testFunctionsScript -clientDllPath $clientDll -newtonSoftDllPath $newtonSoftDll -clientContextScriptPath $clientContextScript
$ErrorActionPreference = $prevEAP

# --- Create ClientContext ---
Write-Host "Connecting to BC sandbox..." -ForegroundColor Cyan
$credential = New-Object PSCredential -ArgumentList $bcAuthContext.upn, (ConvertTo-SecureString -String $accessToken -AsPlainText -Force)

$clientContext = $null
try {
    $clientContext = New-ClientContext `
        -serviceUrl $serviceUrl `
        -auth "AAD" `
        -credential $credential `
        -interactionTimeout ([timespan]::FromMinutes(10)) `
        -culture "en-US"
} catch {
    Write-Error "Failed to create ClientContext: $_"
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  - Test Runner app not installed in sandbox" -ForegroundColor Yellow
    Write-Host "  - Refresh token expired (run bc-login.ps1)" -ForegroundColor Yellow
    Write-Host "  - Sandbox not accessible" -ForegroundColor Yellow
    exit 1
}

# --- Run Tests ---
Write-Host "`n=== Running BC Tests ===" -ForegroundColor Cyan
Write-Host ""

$testParams = @{
    clientContext    = $clientContext
    TestSuite        = $TestSuite
    TestCodeunit     = $TestCodeunit
    TestFunction     = $TestFunction
    ExtensionId      = $extensionId
    detailed         = $Detailed.IsPresent
    testPage         = 130455
    connectFromHost  = $true
}

if ($JUnitResultFileName) {
    $testParams.JUnitResultFileName = $JUnitResultFileName
}

$allPassed = $false
try {
    $allPassed = Run-Tests @testParams -returnTrueIfAllPassed -AzureDevOps "no" -GitHubActions "warning"
} catch {
    Write-Host "`nTest execution error: $_" -ForegroundColor Red
} finally {
    if ($clientContext) {
        $clientContext.Dispose()
    }
}

# --- Summary ---
Write-Host ""
if ($allPassed) {
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== TESTS FAILED ===" -ForegroundColor Red
    exit 1
}
