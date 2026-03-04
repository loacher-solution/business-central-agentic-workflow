<#
.SYNOPSIS
    Uninstalls and unpublishes extensions from a BC cloud sandbox.
.DESCRIPTION
    Uses the Automation API to uninstall and unpublish extensions by name.
    Handles both PTE and Dev scope extensions.

    Steps:
    1. Lists all installed extensions via Automation API
    2. Finds matching extension(s) by name
    3. Uninstalls (if installed)
    4. Unpublishes (removes from environment)
.EXAMPLE
    .\.claude\skills\bc-build-and-publish\scripts\unpublish.ps1 -AppName "My Extension"
    .\.claude\skills\bc-build-and-publish\scripts\unpublish.ps1 -AppName "My Extension" -SkipUninstall
    .\.claude\skills\bc-build-and-publish\scripts\unpublish.ps1 -ProjectDir src
    .\.claude\skills\bc-build-and-publish\scripts\unpublish.ps1 -ProjectDir all
#>
param(
    [string]$AppName,
    [ValidateSet("src", "test", "all")]
    [string]$ProjectDir,
    [switch]$SkipUninstall
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

# --- Resolve app names from project dirs ---
# Order: test before src (test depends on src, so it must be removed first)
if ($ProjectDir -and -not $AppName) {
    $names = @()
    if ($ProjectDir -in @("all", "test")) {
        $testJson = Join-Path $repoRoot "test/app.json"
        if (Test-Path $testJson) {
            $app = Get-Content $testJson -Raw | ConvertFrom-Json
            $names += $app.name
        }
    }
    if ($ProjectDir -in @("all", "src")) {
        $srcJson = Join-Path $repoRoot "src/app.json"
        if (Test-Path $srcJson) {
            $app = Get-Content $srcJson -Raw | ConvertFrom-Json
            $names += $app.name
        }
    }
    if ($names.Count -eq 0) {
        Write-Error "No app.json found for project '$ProjectDir'"
        exit 1
    }
} elseif ($AppName) {
    $names = @($AppName)
} else {
    Write-Error "Specify either -AppName or -ProjectDir"
    exit 1
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

# --- Authenticate ---
Write-Host "Authenticating to BC environment '$BC_ENVIRONMENT'..." -ForegroundColor Cyan
$authContext = New-BcAuthContext -tenantID $BC_TENANT_ID -refreshToken $refreshToken

if (-not $authContext -or -not $authContext.AccessToken) {
    Write-Error "Authentication failed. Run .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 to re-authenticate."
    exit 1
}

# Save the (possibly renewed) refresh token back to .env
if ($authContext.RefreshToken -and $authContext.RefreshToken -ne $BC_REFRESH_TOKEN) {
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "BC_REFRESH_TOKEN=.*", "BC_REFRESH_TOKEN=$($authContext.RefreshToken)"
    $envContent | Set-Content $envFile -NoNewline
}

$token = $authContext.AccessToken
$baseUrl = "https://api.businesscentral.dynamics.com/v2.0/$BC_TENANT_ID/$BC_ENVIRONMENT/api/microsoft/automation/v2.0"

# --- Get company ID ---
$companiesUrl = "https://api.businesscentral.dynamics.com/v2.0/$BC_TENANT_ID/$BC_ENVIRONMENT/api/microsoft/automation/v2.0/companies"
$companies = Invoke-RestMethod -Uri $companiesUrl -Headers @{ Authorization = "Bearer $token" } -Method Get
$companyId = $companies.value[0].id

# --- List extensions ---
$extUrl = "$baseUrl/companies($companyId)/extensions"
$extensions = Invoke-RestMethod -Uri $extUrl -Headers @{ Authorization = "Bearer $token" } -Method Get

foreach ($name in $names) {
    $ext = $extensions.value | Where-Object { $_.displayName -eq $name }
    if (-not $ext) {
        Write-Host "Extension '$name' not found in environment. Skipping." -ForegroundColor Yellow
        continue
    }

    $packageId = $ext.packageId
    $scope = $ext.publishedAs
    Write-Host "Found: $name (packageId=$packageId, scope=$scope, installed=$($ext.isInstalled))" -ForegroundColor Cyan

    # Uninstall
    if ($ext.isInstalled -and -not $SkipUninstall) {
        Write-Host "  Uninstalling '$name'..." -ForegroundColor Yellow
        $uninstallUrl = "$baseUrl/companies($companyId)/extensions($packageId)/Microsoft.NAV.uninstall"
        try {
            Invoke-RestMethod -Uri $uninstallUrl -Headers @{ Authorization = "Bearer $token" } -Method Post -ContentType "application/json"
            Write-Host "  Uninstalled." -ForegroundColor Green
        } catch {
            $errMsg = $_.Exception.Message
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errMsg = $reader.ReadToEnd()
            }
            Write-Warning "  Uninstall failed: $errMsg"
            Write-Warning "  The extension may already be uninstalled. Continuing with unpublish..."
        }
    }

    # Unpublish
    Write-Host "  Unpublishing '$name'..." -ForegroundColor Yellow
    $unpublishUrl = "$baseUrl/companies($companyId)/extensions($packageId)/Microsoft.NAV.unpublish"
    try {
        Invoke-RestMethod -Uri $unpublishUrl -Headers @{ Authorization = "Bearer $token" } -Method Post -ContentType "application/json"
        Write-Host "  Unpublished." -ForegroundColor Green
    } catch {
        $errMsg = $_.Exception.Message
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errMsg = $reader.ReadToEnd()
        }
        Write-Error "  Unpublish failed for '$name': $errMsg"
        exit 1
    }
}

Write-Host "`nUnpublish completed successfully." -ForegroundColor Green
