---
name: bc-build-and-publish
description: Use when you need to compile, build, publish, or unpublish AL apps to/from a Business Central cloud sandbox. Covers the full build-and-deploy workflow.
---

# BC Build & Publish Skill

Build and publish AL apps for Business Central projects.

## When to use

- After writing or modifying AL code
- When asked to build, compile, or publish
- Before committing to verify the code compiles
- When deploying to a BC cloud sandbox

## Commands

### Build (compile)

```bash
# Build all apps (src + test)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1

# Build src only
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1 -ProjectDir src

# Build test only (requires src to be built first)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/build.ps1 -ProjectDir test
```

The build script:
1. Discovers app metadata (name, publisher, version) from `app.json`
2. Compiles `src/` using `al compile` with `.alpackages` as package cache
3. Copies the compiled src `.app` into `test/.alpackages` (dependency resolution)
4. Compiles `test/`

Output goes to `<project>/.build/<publisher>_<name>_<version>.app` (gitignored).

### Publish (deploy to cloud sandbox as Dev)

Apps are published as **Dev** scope using the `/dev/apps` REST endpoint — the same method VS Code uses with F5. This avoids conflicts with PTE (Per Tenant Extension) deployments.

```bash
# Build and publish src app
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst

# Build and publish both apps (src + test)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst -IncludeTest

# Publish only (already built)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1

# With ForceSync (destructive schema changes)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/publish.ps1 -BuildFirst -SchemaUpdateMode ForceSync
```

**SchemaUpdateMode options:**
- `Synchronize` (default) — safe, non-destructive schema sync
- `ForceSync` — allows destructive schema changes (field removal, type changes)
- `Recreate` — drops and recreates tables (data loss!)

### Unpublish (remove from cloud sandbox)

Uninstalls and unpublishes extensions from the BC environment via the Automation API. Use this to clean up PTE or Dev extensions.

```bash
# Unpublish a specific app by name
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/unpublish.ps1 -AppName "My Extension"

# Unpublish src app (reads name from src/app.json)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/unpublish.ps1 -ProjectDir src

# Unpublish both apps
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/unpublish.ps1 -ProjectDir all
```

The script automatically uninstalls (if installed) and then unpublishes the extension.

**Common use case:** If a publish fails with "already deployed as a global application or a per tenant application", unpublish the conflicting extension first, then publish again as Dev.

### Install AppSource App

Installs an AppSource app into the BC sandbox via Admin Center API. If the app is already installed, exits immediately (no overhead).

```bash
# Install Test Runner
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/install-app.ps1 -AppId "23de40a6-dfe8-4f80-80db-d70f83ce8caf" -AppName "Test Runner"

# Install any AppSource app by ID
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/install-app.ps1 -AppId "<app-guid>" -AppName "My App"

# Force reinstall (e.g., to update to latest version)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/install-app.ps1 -AppId "23de40a6-dfe8-4f80-80db-d70f83ce8caf" -AppName "Test Runner" -Force
```

Parameters:
- `-AppId` (mandatory): The AppSource app GUID
- `-AppName` (optional): Display name for log messages
- `-Force` (switch): Reinstall even if already present

Exit codes: 0 = success (or already installed), 1 = failure.

Common AppSource app IDs:

| App | AppSource ID |
|-----|-------------|
| Test Runner | `23de40a6-dfe8-4f80-80db-d70f83ce8caf` |

> **Note:** Only apps published to AppSource can be installed via Admin Center API. The `bc-test-runner` skill calls `install-app.ps1` automatically for the Test Runner app before running tests. You typically don't need to call it manually.

### Upload App from Artifacts

Uploads a `.app` file to a BC Online Sandbox as a Dev extension. Can download the `.app` from BC platform artifacts automatically. Uses the same `/dev/apps` endpoint as `publish.ps1`.

```bash
# Download from BC artifacts and upload as Dev
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/upload-app.ps1 -FromArtifacts -ArtifactAppName "MyApp"

# Upload a local .app file
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/upload-app.ps1 -AppPath "C:\path\to\app.app"

# With ForceSync
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build-and-publish/scripts/upload-app.ps1 -FromArtifacts -ArtifactAppName "MyApp" -SchemaUpdateMode ForceSync
```

Parameters:
- `-AppPath`: Path to a local `.app` file
- `-FromArtifacts` (switch): Download from BC platform artifacts instead
- `-ArtifactAppName`: Name to search for in artifacts (e.g. `Tests-TestLibraries`)
- `-AppName` (optional): Display name for log messages
- `-SchemaUpdateMode`: `Synchronize` (default) or `ForceSync`

> **Limitation:** Apps with publisher "Microsoft" cannot be published to online sandboxes — the service blocks restricted publisher names in both tenant and dev scope. This means **Tests-TestLibraries, Library Assert, Library Variable Storage** are not installable in online sandboxes by any method. Build your own test helper codeunits instead.

## Setup (Bootstrap)

Publishing and unpublishing require a config file at `.claude/skills/bc-build-and-publish/.env` with three values (see `.env.example`):

```ini
BC_TENANT_ID=<azure-ad-tenant-id>
BC_ENVIRONMENT=<bc-environment-name>
BC_REFRESH_TOKEN=<oauth-refresh-token>
```

**How these values are set:**

| Value | How to set |
|-------|-----------|
| `BC_TENANT_ID` | Auto-detected during login (from the access token) |
| `BC_ENVIRONMENT` | Must be provided by the user or AI — this is the BC sandbox name (e.g. `sandbox`, `dev`, `ai-test`) |
| `BC_REFRESH_TOKEN` | Obtained during interactive login, valid ~90 days |

### First-time setup

1. **Set the environment name** — either:
   - Copy `.env.example` to `.env` and set `BC_ENVIRONMENT=<name>`, or
   - Pass it as parameter: `.\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1 -Environment "<name>"`
2. **Run the login script** (interactive, requires a human):
   ```
   .\.claude\skills\bc-build-and-publish\scripts\bc-login.ps1
   ```
   This opens a browser for device login and saves all three values to `.env`.

### When things go wrong

**If `.env` does not exist or is missing values:** Tell the user to run `bc-login.ps1` with their environment name.

**If publish/unpublish fails with an authentication error:** The refresh token has likely expired (~90 days). Tell the user to re-run `bc-login.ps1`.

**If only the environment needs to change:** The `.env` file can be edited directly — just change the `BC_ENVIRONMENT` line. No re-login needed.

**You CANNOT run `bc-login.ps1` yourself** — it opens a browser for interactive device login. Always ask the user to run it.

## Prerequisites

The following tools must be installed (see `.claude/prerequisites.sh`):

- **.NET SDK** — required to run the AL compiler
- **AL Compiler** — `dotnet tool install -g microsoft.dynamics.businesscentral.development.tools --prerelease`
- **PowerShell** — required for build/publish/unpublish scripts
- **BcContainerHelper** — PowerShell module for BC authentication (`Install-Module BcContainerHelper`)

## Conventions

- `src/` contains the main app, `test/` contains the test app
- Each app has an `app.json` manifest (id, name, version, dependencies, idRanges)
- `.alpackages/` holds BC symbol packages (Base App, System App, etc.)
- `.build/` holds compiled output (gitignored)

## Workflow

### After modifying AL code

1. **Build** to verify compilation
2. If build fails, fix the errors and rebuild
3. Commit the changes
4. **Publish** if deployment is needed — check auth first

### Common build errors

- `AL1021: package cache path not specified` → The script handles this; if running `al compile` manually, add `/packagecachepath:<project>/.alpackages`
- `AL0247: target object not found` → Missing symbol package in `.alpackages`
- `AL0791: namespace unknown` → Same as above, missing Base App symbols
