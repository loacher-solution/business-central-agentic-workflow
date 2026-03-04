<#
.SYNOPSIS
    Compiles the src and test AL apps.
.DESCRIPTION
    Uses the AL compiler (al compile) to build both the main app (src/)
    and the test app (test/). The test app depends on the main app,
    so src is compiled first and its output is copied to test/.alpackages.
    App metadata (name, publisher, version) is read from each app.json.
.EXAMPLE
    .\.claude\skills\bc-build\scripts\build.ps1
    .\.claude\skills\bc-build\scripts\build.ps1 -ProjectDir src
#>
param(
    [ValidateSet("all", "src", "test")]
    [string]$ProjectDir = "all"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

function Get-AppFileName {
    param([string]$AppJsonPath)

    $app = Get-Content $AppJsonPath -Raw | ConvertFrom-Json
    return "$($app.publisher)_$($app.name)_$($app.version).app"
}

function Build-AlProject {
    param(
        [string]$Project,
        [string]$PackageCachePath,
        [string]$OutputPath
    )

    $projectPath = Join-Path $repoRoot $Project
    $packageCache = Join-Path $repoRoot $PackageCachePath
    $outFile = Join-Path $repoRoot $OutputPath

    if (-not (Test-Path $projectPath)) {
        Write-Error "Project directory not found: $projectPath"
        return $false
    }

    Write-Host "Building $Project..." -ForegroundColor Cyan
    $result = & al compile /project:$projectPath /packagecachepath:$packageCache /out:$outFile 2>&1
    $exitCode = $LASTEXITCODE

    $result | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        Write-Error "Build failed for $Project (exit code $exitCode)"
        return $false
    }

    Write-Host "OK: $outFile" -ForegroundColor Green
    return $true
}

# --- Main ---

$buildSrc = $ProjectDir -in @("all", "src")
$buildTest = $ProjectDir -in @("all", "test")

# Determine output filenames from app.json
$srcAppJson = Join-Path $repoRoot "src/app.json"
$testAppJson = Join-Path $repoRoot "test/app.json"

if ($buildSrc) {
    if (-not (Test-Path $srcAppJson)) {
        Write-Error "src/app.json not found"
        exit 1
    }
    $srcAppFile = Get-AppFileName $srcAppJson
    $srcOutput = "src/.build/$srcAppFile"

    $ok = Build-AlProject -Project "src" `
                          -PackageCachePath "src/.alpackages" `
                          -OutputPath $srcOutput
    if (-not $ok) { exit 1 }

    # Copy src app to test/.alpackages so the test project can resolve the dependency
    if ($buildTest) {
        $testPkgDir = Join-Path $repoRoot "test/.alpackages"
        if (-not (Test-Path $testPkgDir)) { New-Item -ItemType Directory -Path $testPkgDir -Force | Out-Null }
        Copy-Item (Join-Path $repoRoot $srcOutput) $testPkgDir -Force
        Write-Host "Copied src app to test/.alpackages" -ForegroundColor DarkGray
    }
}

if ($buildTest) {
    if (-not (Test-Path $testAppJson)) {
        Write-Error "test/app.json not found"
        exit 1
    }
    $testAppFile = Get-AppFileName $testAppJson
    $testOutput = "test/.build/$testAppFile"

    $ok = Build-AlProject -Project "test" `
                          -PackageCachePath "test/.alpackages" `
                          -OutputPath $testOutput
    if (-not $ok) { exit 1 }
}

Write-Host "`nBuild completed successfully." -ForegroundColor Green
