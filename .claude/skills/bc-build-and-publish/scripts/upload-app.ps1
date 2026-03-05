<#
.SYNOPSIS
    Uploads a .app file to a BC Online Sandbox as a Dev extension via the /dev/apps endpoint.
.DESCRIPTION
    Publishes an extension from a .app file using the same /dev/apps REST endpoint
    that VS Code uses with F5. This allows installing apps with restricted publisher
    names (e.g. Microsoft Tests-TestLibraries) that the Automation API rejects.

    Optionally downloads the .app from BC platform artifacts if -FromArtifacts is used.
.EXAMPLE
    # Upload a local .app file
    .\upload-app.ps1 -AppPath "C:\path\to\Microsoft_Tests-TestLibraries_27.0.0.0.app"

    # Download from BC artifacts and upload
    .\upload-app.ps1 -FromArtifacts -ArtifactAppName "Tests-TestLibraries"

    # With ForceSync for schema changes
    .\upload-app.ps1 -FromArtifacts -ArtifactAppName "Tests-TestLibraries" -SchemaUpdateMode ForceSync
#>
param(
    [string]$AppPath = "",
    [switch]$FromArtifacts,
    [string]$ArtifactAppName = "",
    [ValidateSet("Synchronize", "ForceSync")]
    [string]$SchemaUpdateMode = "Synchronize",
    [string]$AppName = ""
)

$ErrorActionPreference = "Stop"
$skillRoot = Split-Path -Parent $PSScriptRoot

# --- Validate parameters ---
if (-not $FromArtifacts -and -not $AppPath) {
    Write-Error "Specify either -AppPath or -FromArtifacts with -ArtifactAppName."
    exit 1
}
if ($FromArtifacts -and -not $ArtifactAppName) {
    Write-Error "-ArtifactAppName is required when using -FromArtifacts."
    exit 1
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

# --- Download from artifacts if requested ---
if ($FromArtifacts) {
    Write-Host "Downloading BC artifacts to find '$ArtifactAppName'..." -ForegroundColor Cyan

    # Get artifact URL for online/sandbox matching the environment's application version
    $artifactUrl = Get-BCArtifactUrl -type Sandbox -country us -select Latest
    Write-Host "  Artifact URL: $artifactUrl" -ForegroundColor DarkGray

    # Download artifacts (platform only — that's where test apps live)
    $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
    $platformPath = $artifactPaths[1]  # Second element is the platform path

    Write-Host "  Platform path: $platformPath" -ForegroundColor DarkGray

    # Search for the .app file in the artifact platform folder
    # Test apps are typically in: platform/Applications/testframework/
    $searchPaths = @(
        (Join-Path $platformPath "Applications"),
        (Join-Path $platformPath "ModernDev")
    )

    $foundApp = $null
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $found = Get-ChildItem -Path $searchPath -Filter "Microsoft_$ArtifactAppName*.app" -Recurse -ErrorAction SilentlyContinue
            if ($found) {
                $foundApp = $found | Select-Object -First 1
                break
            }
        }
    }

    if (-not $foundApp) {
        # Broader search across entire artifact cache
        Write-Host "  Searching broader artifact cache..." -ForegroundColor DarkGray
        $foundApp = Get-ChildItem -Path $platformPath -Filter "Microsoft_$ArtifactAppName*.app" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $foundApp) {
        Write-Error "Could not find 'Microsoft_$ArtifactAppName*.app' in artifacts at $platformPath"
        exit 1
    }

    $AppPath = $foundApp.FullName
    Write-Host "  Found: $AppPath" -ForegroundColor Green

    if (-not $AppName) {
        $AppName = $ArtifactAppName
    }
}

if (-not (Test-Path $AppPath)) {
    Write-Error "App file not found: $AppPath"
    exit 1
}

if (-not $AppName) {
    $AppName = Split-Path -Leaf $AppPath
}
$displayName = "'$AppName'"
$fileSize = (Get-Item $AppPath).Length
Write-Host "Publishing $displayName ($([math]::Round($fileSize / 1MB, 2)) MB) as Dev..." -ForegroundColor Yellow

# --- Check if already installed ---
$baseApiUrl = "https://api.businesscentral.dynamics.com/v2.0/$BC_TENANT_ID/$BC_ENVIRONMENT/api/microsoft/automation/v2.0"
$headers = @{
    "Authorization" = "Bearer $($authContext.AccessToken)"
}

Write-Host "Checking if $displayName is already installed..." -ForegroundColor Cyan
try {
    $companies = Invoke-RestMethod -Method Get -Uri "$baseApiUrl/companies" -Headers $headers
    $companyId = $companies.value[0].id
    $extensions = Invoke-RestMethod -Method Get -Uri "$baseApiUrl/companies($companyId)/extensions" -Headers $headers
    $existingExt = $extensions.value | Where-Object {
        $_.displayName -eq $ArtifactAppName -or $_.displayName -eq $AppName
    }
    if ($existingExt) {
        Write-Host "$displayName is already installed (v$($existingExt.versionMajor).$($existingExt.versionMinor).$($existingExt.versionBuild).$($existingExt.versionRevision))." -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "WARN: Could not check installed extensions: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Proceeding with upload anyway..." -ForegroundColor Yellow
}

# --- Publish via /dev/apps endpoint (same as VS Code F5) ---
$appFileName = Split-Path -Leaf $AppPath
$url = "https://api.businesscentral.dynamics.com/v2.0/$BC_TENANT_ID/$BC_ENVIRONMENT/dev/apps?SchemaUpdateMode=$SchemaUpdateMode"

Add-Type -AssemblyName System.Net.Http
$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $authContext.AccessToken)
$httpClient.Timeout = [TimeSpan]::FromMinutes(10)

$fileStream = [System.IO.FileStream]::new($AppPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()

$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$fileHeader.Name = "`"$appFileName`""
$fileHeader.FileName = "`"$appFileName`""
$fileContent = [System.Net.Http.StreamContent]::new($fileStream)
$fileContent.Headers.ContentDisposition = $fileHeader
$multipartContent.Add($fileContent)

try {
    $result = $httpClient.PostAsync($url, $multipartContent).GetAwaiter().GetResult()
    $statusCode = [int]$result.StatusCode
    $responseBody = $result.Content.ReadAsStringAsync().GetAwaiter().GetResult()

    if ($result.IsSuccessStatusCode) {
        Write-Host "$displayName published successfully as Dev (HTTP $statusCode)." -ForegroundColor Green
    } else {
        Write-Error "Publish failed for $displayName (HTTP $statusCode): $responseBody"
        exit 1
    }
} finally {
    $fileStream.Dispose()
    $multipartContent.Dispose()
    $httpClient.Dispose()
}

exit 0
