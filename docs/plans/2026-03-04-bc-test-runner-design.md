# BC Test Runner Skill — Design

## Goal

Enable the AI agent (Dave) to run AL tests against a Business Central Online Sandbox
**without Docker**, parse the results, and act on failures.

## Approach: Headless ClientContext

BcContainerHelper internally uses a headless .NET client (`ClientContext`) that
communicates with BC via HTTP/WebSocket — no browser, no UI. We extract the required
client DLLs from BC Platform Artifacts and call the ClientContext directly.

### Flow

```
1. setup-artifacts.ps1  — Download BC platform artifacts, cache client DLLs
2. Auth                  — New-BcAuthContext with refresh token (.env)
3. Build + Publish       — Reuse bc-build-and-publish scripts
4. run-tests.ps1         — ClientContext → Page 130455 → RunNextTest → parse JSON
5. Output                — Structured pass/fail per codeunit/method + JUnit XML
```

## Skill Structure

```
.claude/skills/bc-test-runner/
├── SKILL.md
└── scripts/
    ├── run-tests.ps1         # Main: orchestrate build, publish, test, parse
    └── setup-artifacts.ps1   # Download BC artifacts, extract client DLLs
```

## Key Technical Details

- **Client DLL**: `Microsoft.Dynamics.Framework.UI.Client.dll` from BC platform artifacts
- **Test Page**: 130455 (AL Test Tool) — requires Test Runner app installed from AppSource
- **Test Runner AppSource ID**: `23de40a6-dfe8-4f80-80db-d70f83ce8caf`
- **Auth**: OAuth refresh token via BcContainerHelper `New-BcAuthContext`
- **Results**: JSON from `TestResultJson` control → parsed into structured output
- **No Docker required**: DLLs downloaded via `Download-Artifacts` from BcContainerHelper

## Prerequisites

- BcContainerHelper PowerShell module
- .NET SDK (for DLL loading)
- `.env` with BC_TENANT_ID, BC_ENVIRONMENT, BC_REFRESH_TOKEN
- Test Runner installed in sandbox (one-time setup)

## Limitations

- No Test Libraries (Assert, Any, Variable Storage) available in online sandbox
- Service Principal auth does NOT work for ClientContext — user credentials only
- Test apps must not depend on test framework apps (refactor needed)
