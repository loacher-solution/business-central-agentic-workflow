<#
.SYNOPSIS
    Downloads symbol packages from a BC cloud sandbox.
.DESCRIPTION
    Uses the /dev/packages REST endpoint to download .app symbol files
    from the configured BC environment. Downloads all dependencies declared
    in app.json that are not yet present in .alpackages.
.EXAMPLE
    .\.claude\skills\bc-build-and-publish\scripts\download-symbols.ps1 -ProjectDir test
    .\.claude\skills\bc-build-and-publish\scripts\download-symbols.ps1 -ProjectDir all
#>
param(
    [ValidateSet("all", "src", "test")]
    [string]$ProjectDir = "all"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

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
    Write-Error "Refresh token missing in .env. Run bc-login.ps1 to re-authenticate."
    exit 1
}

# --- Authenticate ---
Write-Host "Authenticating to BC environment '$BC_ENVIRONMENT'..." -ForegroundColor Cyan
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

$accessToken = $authContext.AccessToken

function Download-Symbol {
    param(
        [string]$Publisher,
        [string]$AppName,
        [string]$Version,
        [string]$TargetDir
    )

    $url = "https://api.businesscentral.dynamics.com/v2.0/$BC_TENANT_ID/$BC_ENVIRONMENT/dev/packages?publisher=$Publisher&appName=$AppName&versionText=$Version"

    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    $outFile = Join-Path $TargetDir "${Publisher}_${AppName}_${Version}.app"

    Write-Host "  Downloading $Publisher - $AppName ($Version)..." -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri $url -Headers $headers -OutFile $outFile -Method Get
        Write-Host "  OK: $(Split-Path -Leaf $outFile)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "  Failed to download $AppName : $_"
        return $false
    }
}

function Download-SymbolsForProject {
    param([string]$Project)

    $appJsonPath = Join-Path $repoRoot "$Project/app.json"
    if (-not (Test-Path $appJsonPath)) {
        Write-Warning "No app.json found at $appJsonPath, skipping."
        return
    }

    $app = Get-Content $appJsonPath -Raw | ConvertFrom-Json
    $pkgDir = Join-Path $repoRoot "$Project/.alpackages"
    if (-not (Test-Path $pkgDir)) {
        New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
    }

    Write-Host "`nDownloading symbols for '$($app.name)' into $Project/.alpackages..." -ForegroundColor Yellow

    foreach ($dep in $app.dependencies) {
        # Check if already present
        $existing = Get-ChildItem -Path $pkgDir -Filter "$($dep.publisher)_$($dep.name)_*.app" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "  Already present: $($dep.publisher) - $($dep.name)" -ForegroundColor DarkGray
            continue
        }

        Download-Symbol -Publisher $dep.publisher -AppName $dep.name -Version $dep.version -TargetDir $pkgDir
    }

    # Also download platform symbols (Application, System, Base App) if missing
    $platformPackages = @(
        @{ Publisher = "Microsoft"; AppName = "Application"; Version = $app.application },
        @{ Publisher = "Microsoft"; AppName = "System Application"; Version = $app.application },
        @{ Publisher = "Microsoft"; AppName = "Base Application"; Version = $app.application },
        @{ Publisher = "Microsoft"; AppName = "Business Foundation"; Version = $app.application },
        @{ Publisher = "Microsoft"; AppName = "System"; Version = $app.platform }
    )

    foreach ($pkg in $platformPackages) {
        $existing = Get-ChildItem -Path $pkgDir -Filter "$($pkg.Publisher)_$($pkg.AppName)_*.app" -ErrorAction SilentlyContinue
        if ($existing) {
            continue
        }
        Download-Symbol -Publisher $pkg.Publisher -AppName $pkg.AppName -Version $pkg.Version -TargetDir $pkgDir
    }
}

# --- Main ---
$projects = @()
if ($ProjectDir -in @("all", "src"))  { $projects += "src" }
if ($ProjectDir -in @("all", "test")) { $projects += "test" }

foreach ($proj in $projects) {
    Download-SymbolsForProject -Project $proj
}

Write-Host "`nSymbol download completed." -ForegroundColor Green
