# BC Page Scripting Skill — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable the AI agent to create and run E2E UI tests against a BC Online Sandbox using `@microsoft/bc-replay`.

**Architecture:** Wrapper skill around the npm package `@microsoft/bc-replay`. A setup script installs Node dependencies and PowerShell 7. A run script executes YAML page scripts headlessly via Playwright and outputs structured results. A YAML reference doc teaches the AI how to write page scripts.

**Tech Stack:** `@microsoft/bc-replay` (npm), Playwright, PowerShell 7 (pwsh), YAML page scripts

---

### Task 1: Create skill directory structure and SKILL.md

**Files:**
- Create: `.claude/skills/bc-page-scripting/SKILL.md`

**Step 1: Create SKILL.md**

```markdown
---
name: bc-page-scripting
description: Use when you need to run E2E UI tests against a Business Central web client, validate page behavior (fields, buttons, actions), or create page script recordings. Uses Microsoft's bc-replay tool with Playwright.
---

# BC Page Scripting Skill

Run E2E UI tests against a Business Central Online Sandbox using page scripts (YAML).

## When to use

- After creating or modifying pages, page extensions, or actions
- When asked to verify UI behavior (fields visible, buttons work, navigation)
- For user acceptance testing (UAT) automation
- When AL TestPages are insufficient (need real browser validation)

## Commands

### Run page scripts

```bash
# Run all page scripts in a directory — ScriptPath is REQUIRED
pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/*.yml"

# Run a specific script
pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/test-customer.yml"

# Run with visible browser (for debugging)
pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/*.yml" -Headed
```

> **Note:** `-ScriptPath` is required and accepts a glob pattern or single file path. The AI agent creates YAML scripts in the repo's `e2e/recordings/` directory (or a project-specific path).

### Setup (one-time, auto-runs if needed)

```bash
pwsh -File .claude/skills/bc-page-scripting/scripts/setup-replay.ps1
```

Setup installs `@microsoft/bc-replay` via npm and Playwright browsers. Runs automatically on first execution if `node_modules` is missing.

## How it works

1. **Setup**: Installs `@microsoft/bc-replay` npm package and Playwright Chromium browser.
2. **Auth**: Uses AAD authentication with username/password via environment variables. Playwright automates the Entra ID login page in headless Chromium.
3. **Run**: `npx replay` opens a headless browser, navigates to the BC web client, and replays YAML page scripts step by step.
4. **Results**: Outputs pass/fail per script and step. Full Playwright HTML report saved to result directory.

## Dependencies

- **`bc-build-and-publish` skill**: Required. Reuses `.env` for `BC_TENANT_ID` and `BC_ENVIRONMENT`. E2E credentials (`BC_E2E_USERNAME`, `BC_E2E_PASSWORD`) must be added to the same `.env`.

## Prerequisites

- **Node.js 16+** (installed via `prerequisites.sh`)
- **PowerShell 7+ (pwsh)** — bc-replay requires pwsh, not Windows PowerShell 5.1. Setup script installs it if missing.
- **Test account** — Entra ID user with username/password (no interactive MFA, or use TOTP secret)
- **Permission set** — `PAGESCRIPTING - PLAY` assigned to the test account in BC
- **`.env`** at `.claude/skills/bc-build-and-publish/.env` with `BC_E2E_USERNAME` and `BC_E2E_PASSWORD` added

## Writing Page Scripts

Page scripts are YAML files. See `references/yaml-format.md` for the full syntax reference.

Basic structure:
```yaml
name: my-test
description: Test that customer card opens correctly
start:
  page: Customer Card
steps:
  - type: action
    target:
    - page: Customer Card
    - action: New
    description: Click New action
  - type: input
    target:
    - page: Customer Card
    - field: Name
    value: Test Customer
    description: Enter customer name
  - type: validate
    target:
    - page: Customer Card
    - field: Name
    value: Test Customer
    description: Validate name was set
```

## Limitations

- **Preview feature**: Page Scripting is a production-ready preview in BC
- **No Control Add-Ins**: Cannot automate Power BI, custom controls, or non-BC content
- **Browser-based auth only**: Cannot use refresh tokens — needs username/password
- **BC version sensitive**: YAML scripts may need updates after major BC UI changes
- **Requires pwsh 7+**: Will not work with Windows PowerShell 5.1

## Troubleshooting

### "npx replay not found"
Run setup first: `pwsh -File .claude/skills/bc-page-scripting/scripts/setup-replay.ps1`

### Authentication fails
Verify `BC_E2E_USERNAME` and `BC_E2E_PASSWORD` in `.env`. The account must not require interactive MFA. Disable security defaults or use TOTP.

### "pwsh not found"
PowerShell 7 is not installed. The setup script attempts to install it via winget. If that fails, install manually from https://aka.ms/install-powershell.
```

**Step 2: Commit**

```bash
git add .claude/skills/bc-page-scripting/SKILL.md
git commit -m "feat: add bc-page-scripting skill skeleton"
```

---

### Task 2: Create setup-replay.ps1

**Files:**
- Create: `.claude/skills/bc-page-scripting/scripts/setup-replay.ps1`

**Step 1: Write setup script**

The script must:
1. Check if pwsh 7+ is available (it's running in pwsh already, so just verify version)
2. Check if `node_modules/@microsoft/bc-replay` exists in skill dir
3. If not, run `npm install @microsoft/bc-replay --save`
4. Install Playwright browsers (`npx playwright install chromium`)
5. Verify installation

```powershell
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
```

**Step 2: Add to .gitignore**

Append to `.gitignore`:
```
# BC page scripting (npm dependencies, cached)
.claude/skills/bc-page-scripting/node_modules
.claude/skills/bc-page-scripting/package-lock.json
.claude/skills/bc-page-scripting/package.json
e2e/results
```

**Step 3: Commit**

```bash
git add .claude/skills/bc-page-scripting/scripts/setup-replay.ps1 .gitignore
git commit -m "feat: add bc-page-scripting setup script"
```

---

### Task 3: Create run-replay.ps1

**Files:**
- Create: `.claude/skills/bc-page-scripting/scripts/run-replay.ps1`

**Step 1: Write run script**

The script must:
1. Load `.env` for credentials (BC_E2E_USERNAME, BC_E2E_PASSWORD, BC_TENANT_ID, BC_ENVIRONMENT)
2. Auto-run setup if bc-replay not installed
3. Build the BC StartAddress URL from tenant/environment
4. Set credentials as environment variables
5. Run `npx replay` with proper parameters
6. Parse exit code and output summary

```powershell
<#
.SYNOPSIS
    Runs BC page scripts (YAML) headlessly against a BC Online Sandbox.
.DESCRIPTION
    Uses @microsoft/bc-replay to execute page script recordings via Playwright.
    Authenticates via AAD with username/password from .env.
.EXAMPLE
    pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/*.yml"
    pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/test-customer.yml" -Headed
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [string]$ResultDir = "",
    [switch]$Headed,
    [string]$StartAddress = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$skillRoot = Split-Path -Parent $PSScriptRoot
$buildPublishSkill = Join-Path $repoRoot ".claude/skills/bc-build-and-publish"

# --- Ensure bc-replay is installed ---
$replayDir = Join-Path $skillRoot "node_modules/@microsoft/bc-replay"
if (-not (Test-Path $replayDir)) {
    Write-Host "bc-replay not found. Running setup..." -ForegroundColor Yellow
    & pwsh -File (Join-Path $PSScriptRoot "setup-replay.ps1")
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Load .env ---
$envFile = Join-Path $buildPublishSkill ".env"
if (-not (Test-Path $envFile)) {
    Write-Error @"
Config not found: $envFile
Run .claude/skills/bc-build-and-publish/scripts/bc-login.ps1 first, then add BC_E2E_USERNAME and BC_E2E_PASSWORD.
"@
    exit 1
}
Get-Content $envFile | Where-Object { $_ -match '^\w+=.+' } | ForEach-Object {
    $key, $val = $_ -split '=', 2
    Set-Variable -Name $key -Value $val
}

# Validate E2E credentials
if ([string]::IsNullOrWhiteSpace($BC_E2E_USERNAME) -or [string]::IsNullOrWhiteSpace($BC_E2E_PASSWORD)) {
    Write-Error @"
E2E credentials missing in .env. Add these lines to $envFile:
BC_E2E_USERNAME=test.automation@yourdomain.com
BC_E2E_PASSWORD=your-password
"@
    exit 1
}

# --- Build StartAddress ---
if (-not $StartAddress) {
    if ([string]::IsNullOrWhiteSpace($BC_TENANT_ID) -or [string]::IsNullOrWhiteSpace($BC_ENVIRONMENT)) {
        Write-Error "BC_TENANT_ID and BC_ENVIRONMENT must be set in .env"
        exit 1
    }
    $StartAddress = "https://businesscentral.dynamics.com/$BC_TENANT_ID/$BC_ENVIRONMENT"
}
Write-Host "Target: $StartAddress" -ForegroundColor Cyan

# --- Resolve script path ---
if (-not [System.IO.Path]::IsPathRooted($ScriptPath)) {
    $ScriptPath = Join-Path $repoRoot $ScriptPath
}

# --- Set result directory ---
if (-not $ResultDir) {
    $ResultDir = Join-Path $repoRoot "e2e/results"
}
if (-not [System.IO.Path]::IsPathRooted($ResultDir)) {
    $ResultDir = Join-Path $repoRoot $ResultDir
}

# --- Set credentials as env vars ---
$env:BC_E2E_USERNAME = $BC_E2E_USERNAME
$env:BC_E2E_PASSWORD = $BC_E2E_PASSWORD

# --- Run bc-replay ---
Write-Host "`n=== Running Page Scripts ===" -ForegroundColor Cyan
Write-Host "Scripts: $ScriptPath" -ForegroundColor DarkGray
Write-Host "Results: $ResultDir" -ForegroundColor DarkGray
Write-Host ""

$replayArgs = @(
    "replay"
    $ScriptPath
    "-StartAddress", $StartAddress
    "-Authentication", "AAD"
    "-UserNameKey", "BC_E2E_USERNAME"
    "-PasswordKey", "BC_E2E_PASSWORD"
    "-ResultDir", $ResultDir
)
if ($Headed) {
    $replayArgs += "-Headed"
}

Push-Location $skillRoot
try {
    & npx @replayArgs
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    # Clean up env vars
    Remove-Item Env:BC_E2E_USERNAME -ErrorAction SilentlyContinue
    Remove-Item Env:BC_E2E_PASSWORD -ErrorAction SilentlyContinue
}

# --- Summary ---
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "=== ALL PAGE SCRIPTS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== PAGE SCRIPTS FAILED ===" -ForegroundColor Red
    Write-Host "View report: npx playwright show-report $ResultDir/playwright-report" -ForegroundColor Yellow
}
exit $exitCode
```

**Step 2: Commit**

```bash
git add .claude/skills/bc-page-scripting/scripts/run-replay.ps1
git commit -m "feat: add bc-page-scripting run script"
```

---

### Task 4: Create YAML format reference

**Files:**
- Create: `.claude/skills/bc-page-scripting/references/yaml-format.md`

**Step 1: Write YAML reference**

This teaches the AI how to write page scripts. Include:
- Basic structure (name, description, start, steps)
- Step types (action, input, validate, wait, conditional)
- Target selectors (page, field, action, part)
- Parameters and Power Fx expressions
- Include (sub-script) syntax
- Common patterns (open page, fill form, click button, validate field)

**Step 2: Commit**

```bash
git add .claude/skills/bc-page-scripting/references/yaml-format.md
git commit -m "docs: add page script YAML reference"
```

---

### Task 5: Create sample page script

**Files:**
- Create: `e2e/recordings/hello-world-customer.yml`

**Step 1: Write a simple test script**

A minimal page script that:
1. Opens the Customer List
2. Verifies the page opened
3. Creates a new customer
4. Validates the customer name field

**Step 2: Commit**

```bash
git add e2e/recordings/hello-world-customer.yml
git commit -m "test: add sample page script for customer list"
```

---

### Task 6: Run setup and test

**Step 1: Install pwsh if missing**

```bash
winget install --id Microsoft.PowerShell --source winget
```

**Step 2: Run setup**

```bash
pwsh -File .claude/skills/bc-page-scripting/scripts/setup-replay.ps1
```

Expected: `Setup completed. bc-replay ready in ...`

**Step 3: Run sample script (if E2E credentials are configured)**

```bash
pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/hello-world-customer.yml"
```

Expected: Page script executes and outputs pass/fail.

---

### Task 7: Update agent configs and .env.example

**Files:**
- Modify: `.claude/agents/developer.md` — add page scripting commands and skill
- Modify: `.claude/agents/reviewer.md` — add page scripting skill reference
- Modify: `.claude/skills/bc-build-and-publish/.env.example` — add E2E credential placeholders

**Step 1: Add to developer.md Tools & Commands**

```markdown
- **Run page scripts**: `pwsh -File .claude/skills/bc-page-scripting/scripts/run-replay.ps1 -ScriptPath "e2e/recordings/*.yml"`
```

**Step 2: Add to developer.md and reviewer.md Skills section**

```markdown
- **`bc-page-scripting`**: Invoke when you need to run E2E UI tests. Creates and runs page scripts (YAML) against the BC web client via Playwright.
```

**Step 3: Add to .env.example**

```
BC_E2E_USERNAME=
BC_E2E_PASSWORD=
```

**Step 4: Commit**

```bash
git add .claude/agents/developer.md .claude/agents/reviewer.md .claude/skills/bc-build-and-publish/.env.example
git commit -m "feat: register bc-page-scripting skill in agent configs"
```
