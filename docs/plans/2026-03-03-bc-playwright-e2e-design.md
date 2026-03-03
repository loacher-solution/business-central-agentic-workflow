# Design: Business Central End-to-End Test Automation

**Date:** 2026-03-03
**Issue:** #3 — Playwright End-to-end test
**Status:** Implemented

## Problem

The developer agent (Dave) needs to be able to write and execute end-to-end tests for
Business Central functionality it implements, in order to verify that what it builds
actually works in the BC UI.

## Solution Overview

Use Microsoft's **`@microsoft/bc-replay`** package — a Playwright-based test runner
purpose-built for Business Central's Page Scripting feature.

### How BC Page Scripting + bc-replay works

```
[BC UI] → record interactions → [YAML file]
                                     ↓
                              [bc-replay (Playwright)]
                                     ↓
                            [Test result + report]
```

1. A user (or agent) **records** interactions in the BC UI via the Page Scripting tool
2. The recording is saved as a **YAML file** capturing every step
3. **`bc-replay`** replays the YAML using Playwright against a live BC environment
4. Results are reported in a Playwright HTML report

### Why bc-replay (not raw Playwright)

- Business Central is not a generic web app — it uses custom AL controls that generic
  HTML selectors can't reliably target
- `bc-replay` uses BC-specific APIs to interact with pages, fields, and actions by
  their BC identifiers (not DOM selectors), making tests resilient to UI changes
- Recording in the BC UI is the correct, supported way to create BC test scripts
- The YAML format is human-readable and version-controllable

## Architecture

### Directory structure

```
tests/
├── recordings/          # YAML page script files (the actual tests)
│   └── example-customer-list.yml
├── results/             # Test run output (git-ignored)
├── package.json         # Declares @microsoft/bc-replay dependency
├── run-tests.js         # Node.js wrapper for npx replay
├── .gitignore           # Ignores node_modules and results
└── README.md            # Setup and usage documentation
```

### CI/CD

A new GitHub Actions workflow (`.github/workflows/bc-e2e-tests.yml`) runs the tests:
- Triggered on push/PR when recordings change, or manually via `workflow_dispatch`
- Requires three repository secrets: `BC_START_ADDRESS`, `BC_USERNAME`, `BC_PASSWORD`
- Uploads the Playwright HTML report as a workflow artifact

### Agent integration

The developer agent (Dave) is updated to:
- Know how to install dependencies (`cd tests && npm install`)
- Know how to run tests (`cd tests && npm test`)
- Have guidance on creating YAML recordings for features it implements
- Record tests even when no BC environment is available (commit the YAML, run later)

## Configuration

| Environment Variable | Description | Required |
|---------------------|-------------|----------|
| `BC_START_ADDRESS` | BC web client URL | Yes |
| `BC_AUTH` | Auth type (UserPassword/AAD/Windows) | No (default: UserPassword) |
| `BC_USERNAME` | BC test user account | Yes (for UserPassword/AAD) |
| `BC_PASSWORD` | BC test user password | Yes (for UserPassword/AAD) |
| `BC_TESTS_GLOB` | Glob pattern for test files | No (default: recordings/*.yml) |
| `BC_RESULT_DIR` | Results directory | No (default: results) |
| `BC_HEADED` | Show browser during tests | No (default: false) |

## Assumptions

1. The BC environment uses username/password authentication (not MFA)
2. The test user has the `PAGESCRIPTING - PLAY` permission set in BC
3. Tests run on the self-hosted runner that has network access to the BC environment
4. Agents without access to a live BC environment can still commit YAML recordings
   for later execution

## References

- [BC Page Scripting documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-page-scripting)
- [@microsoft/bc-replay on npm](https://www.npmjs.com/package/@microsoft/bc-replay)
- [Playwright documentation](https://playwright.dev/)
