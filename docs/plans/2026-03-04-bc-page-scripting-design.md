# BC Page Scripting Skill — Design

## Goal

Enable the AI agent to run E2E UI tests against a Business Central Online Sandbox
using Microsoft's Page Scripting tool (`@microsoft/bc-replay`). The agent can both
create YAML page scripts and execute them headlessly.

## Approach: Wrapper around bc-replay

Use `@microsoft/bc-replay` (npm package, v0.1.119+) to run YAML page scripts
headlessly via Playwright against BC Online. The skill provides setup, execution,
and result parsing.

### Flow

```
1. setup-replay.ps1  — npm install @microsoft/bc-replay + Playwright browsers
2. AI creates/edits  — YAML page scripts in configurable directory (e.g. e2e/)
3. run-replay.ps1    — npx replay *.yml → headless Playwright → BC Web Client
4. Results           — Playwright HTML report + console summary for the AI
```

## Skill Structure

```
.claude/skills/bc-page-scripting/
├── SKILL.md                     # Skill docs, commands, YAML reference
├── scripts/
│   ├── setup-replay.ps1         # Install bc-replay + Playwright (one-time)
│   └── run-replay.ps1           # Execute page scripts, parse results
└── references/
    └── yaml-format.md           # Page Script YAML syntax reference for AI
```

## Authentication

bc-replay uses browser-based AAD login (Playwright types credentials into the
Entra ID login page). This requires a dedicated test account with username/password.

Credentials stored in `.claude/skills/bc-build-and-publish/.env`:
- `BC_E2E_USERNAME` — Test account email (e.g. test.automation@domain.com)
- `BC_E2E_PASSWORD` — Test account password
- `BC_TENANT_ID` — Reused from existing .env
- `BC_ENVIRONMENT` — Reused from existing .env

The run script sets these as environment variables and passes `-UserNameKey` /
`-PasswordKey` to bc-replay.

## Key Technical Details

- **Package**: `@microsoft/bc-replay` (npm, MIT license, maintained by Microsoft)
- **Runtime**: Node.js 16+ and PowerShell 7+ (pwsh, not PowerShell 5.1)
- **Browser**: Chromium via Playwright (headless by default, `-Headed` for debug)
- **Scripts format**: YAML with Power Fx expressions, parameters, conditions
- **Results**: Playwright HTML report in result directory
- **MFA**: Supported via TOTP (`-MultiFactorType TOTP -MultiFactorSecretKey`)

## run-replay.ps1 Parameters

```powershell
param(
    [string]$ScriptPath,        # REQUIRED: Glob or file path to YAML scripts
    [string]$ResultDir = "",    # Result directory (default: e2e/results)
    [switch]$Headed,            # Show browser UI for debugging
    [string]$StartAddress = ""  # Override BC URL (default: built from .env)
)
```

## Prerequisites

- **Node.js 16+** — must be installed
- **PowerShell 7+** — bc-replay requires pwsh (not Windows PowerShell 5.1)
- **Test account** — Entra ID user with username/password (no interactive MFA)
- **Permission set** — `PAGESCRIPTING - PLAY` assigned to the test account
- **`bc-build-and-publish` skill** — for .env credentials (tenant, environment)

## Dependencies

- **`bc-build-and-publish` skill**: Reuses `.env` for tenant/environment config
- **`bc-test-runner` skill**: Complementary — AL tests for logic, page scripts for UI

## Limitations

- **Preview feature**: Page Scripting is production-ready preview in BC
- **No Control Add-Ins**: Cannot automate embedded Power BI, custom controls
- **No MFA without TOTP**: If account has MFA, must use TOTP secret
- **Browser-based auth**: Cannot use refresh tokens — needs username/password
- **BC version dependent**: YAML scripts may break after major BC UI updates
- **No Playwright on PowerShell 5.1**: Requires pwsh 7+
