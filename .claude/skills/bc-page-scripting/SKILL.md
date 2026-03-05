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
