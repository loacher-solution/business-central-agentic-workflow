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
