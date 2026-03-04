---
name: bc-build
description: Use when you need to compile, build, or publish AL apps to a Business Central cloud sandbox. Covers the full build-and-deploy workflow.
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
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/build.ps1

# Build src only
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/build.ps1 -ProjectDir src

# Build test only (requires src to be built first)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/build.ps1 -ProjectDir test
```

The build script:
1. Discovers app metadata (name, publisher, version) from `app.json`
2. Compiles `src/` using `al compile` with `.alpackages` as package cache
3. Copies the compiled src `.app` into `test/.alpackages` (dependency resolution)
4. Compiles `test/`

Output goes to `<project>/.build/<publisher>_<name>_<version>.app` (gitignored).

### Publish (deploy to cloud sandbox)

```bash
# Build and publish src app
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/publish.ps1 -BuildFirst

# Build and publish both apps (src + test)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/publish.ps1 -BuildFirst -IncludeTest

# Publish only (already built)
powershell -ExecutionPolicy Bypass -File .claude/skills/bc-build/scripts/publish.ps1
```

### Authentication

Publishing requires a valid refresh token. The token is stored in `.claude/skills/bc-build/scripts/.auth-token` and is valid for ~90 days.

**If the token is missing or expired**, you CANNOT fix this yourself. Ask the user to run the following command in a PowerShell terminal:

```
.\.claude\skills\bc-build\scripts\bc-login.ps1
```

This is an interactive script that opens a browser for device login. It must be run by a human.

**How to detect auth issues:**
- `.claude/skills/bc-build/scripts/.auth-token` does not exist
- `.claude/skills/bc-build/scripts/.env.ps1` does not exist
- `publish.ps1` fails with an authentication error

In all cases, tell the user to run `.\.claude\skills\bc-build\scripts\bc-login.ps1`.

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
