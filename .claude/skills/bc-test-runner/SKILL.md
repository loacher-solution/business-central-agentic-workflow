---
name: bc-test-runner
description: Use when you need to run AL tests against a Business Central cloud sandbox, verify test results, or diagnose test failures. Runs tests headlessly without Docker.
---

# BC Test Runner Skill

Run AL tests against a Business Central Online Sandbox without Docker.

## When to use

- After writing or modifying test codeunits
- When asked to run tests or verify functionality
- Before committing to ensure tests pass
- When diagnosing test failures

## Commands

### Run all tests

```bash
# Build, publish, and run all tests — TestAppPath is REQUIRED
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json"

# Run tests without rebuilding (apps already published)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -SkipPublish

# With detailed output (shows every test, not just failures)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -Detailed
```

### Run specific tests

```bash
# Run a specific test codeunit
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -TestCodeunit 50200

# Run a specific test function
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/run-tests.ps1 -TestAppPath "test/app.json" -TestFunction "TestMyFeature"
```

> **Note:** `-TestAppPath` is required and must point to the test project's `app.json`. The path can be relative (resolved from repo root) or absolute. The AI agent determines the correct path from project structure (CLAUDE.md, memory, or codebase exploration).

### Setup (one-time, auto-runs if needed)

```bash
# Download BC platform artifacts (client DLLs) — cached after first run
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-test-runner/scripts/setup-artifacts.ps1
```

Setup runs automatically on first test execution. The Test Runner app is also installed automatically via the Admin Center API if not already present.

## How it works

1. **Setup**: Downloads BC platform artifacts to extract all headless client DLLs (20 assemblies including `Microsoft.Dynamics.Framework.UI.Client.dll`). Cached locally in `.artifacts/`.
2. **Test Runner Install**: Checks via Admin Center API if the Test Runner app (AppSource ID: `23de40a6-dfe8-4f80-80db-d70f83ce8caf`) is installed. If not, installs it automatically and waits for completion.
3. **Build & Publish**: Reuses `bc-build-and-publish` scripts to compile and deploy both src and test apps.
4. **Auth**: Acquires two OAuth tokens — one for the API (Admin Center) and one for the Client Service (headless test execution, scope `projectmadeira.com`).
5. **Run**: Opens a headless `ClientContext` to the BC sandbox (no browser, no Docker). Connects to Page 130455 (AL Test Tool) and executes tests via the `RunNextTest` action.
6. **Results**: Outputs pass/fail per codeunit and method, with error messages and durations.

## Dependencies

- **`bc-build-and-publish` skill**: Required. This skill reuses its `.env` credentials and `publish.ps1` for building and deploying apps before test execution. Must be set up first (run `bc-login.ps1`).

## Prerequisites

- **BcContainerHelper** PowerShell module (installed via `prerequisites.sh`)
- **`.env`** at `.claude/skills/bc-build-and-publish/.env` with `BC_TENANT_ID`, `BC_ENVIRONMENT`, `BC_REFRESH_TOKEN`
- Everything else (client DLLs, Test Runner app) is set up automatically.

## Limitations

- **No Test Libraries**: The Assert, Any, and Variable Storage test framework apps are not available in online sandboxes. Test codeunits must not depend on them.
- **User credentials only**: Service Principal authentication does not work with the ClientContext. The refresh token must be from a user login.
- **One sandbox at a time**: Tests run against the environment configured in `.env`.
- **AntiSSRF warning**: The `Microsoft.Internal.AntiSSRF.dll` may emit a load warning on PowerShell 5.1. This is harmless and does not affect test execution.

## Troubleshooting

### "Cannot open page 130455"
The Test Runner app is not installed yet. The script attempts auto-installation, but if it fails, install manually via the BC web client: Extension Marketplace → search "Test Runner".

### Authentication errors / 401 Unauthorized
The refresh token has expired (~90 days). Run `bc-login.ps1` to re-authenticate:
```bash
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/bc-login.ps1
```

### "Test app not found"
The test app was not published. Run without `-SkipPublish` to build and publish first.

### ClientContext hangs
If the script hangs at "Connecting to BC sandbox...", the Client Service scope may be wrong. Ensure `New-BcAuthContext` uses `https://projectmadeira.com/user_impersonation offline_access` as the scope.
