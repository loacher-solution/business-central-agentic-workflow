#!/bin/bash
# Repo-specific prerequisites for the agentic workflow.
#
# This script runs automatically before each Developer and Reviewer agent session.
# Use it to install tools, compilers, or SDKs that the agents need for this repo.
#
# The standard prerequisites (Node.js, jq, python3, gh CLI, Claude Code CLI)
# are already installed before this script runs.

set -e

# --- .NET SDK (required for AL compiler) ---
if ! command -v dotnet &>/dev/null; then
    echo "Installing .NET SDK..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0
    elif command -v brew &>/dev/null; then
        brew install dotnet-sdk
    elif command -v choco &>/dev/null; then
        choco install dotnet-sdk -y
    else
        echo "ERROR: Cannot install .NET SDK automatically. Install it manually: https://dotnet.microsoft.com/download"
        exit 1
    fi
fi

# --- AL Compiler (dotnet tool) ---
if ! dotnet tool list -g 2>/dev/null | grep -qi "businesscentral.development.tools"; then
    echo "Installing AL compiler..."
    dotnet tool install -g microsoft.dynamics.businesscentral.development.tools --prerelease
fi

# --- PowerShell (required for build/publish/unpublish scripts) ---
if ! command -v pwsh &>/dev/null && ! command -v powershell &>/dev/null; then
    echo "Installing PowerShell..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y powershell
    elif command -v brew &>/dev/null; then
        brew install powershell/tap/powershell
    else
        echo "ERROR: Cannot install PowerShell automatically. Install it manually: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
        exit 1
    fi
fi

# Determine PowerShell executable
PWSH=$(command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null)

# --- BcContainerHelper PowerShell module (required for authentication) ---
$PWSH -NoProfile -Command '
if (-not (Get-Module -ListAvailable BcContainerHelper)) {
    Write-Host "Installing BcContainerHelper PowerShell module..."
    Install-Module BcContainerHelper -Force -AllowClobber -Scope CurrentUser
} else {
    Write-Host "BcContainerHelper already installed."
}
'

echo "All prerequisites installed successfully."
