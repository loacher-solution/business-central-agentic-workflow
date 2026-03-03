#!/bin/bash
# Repo-specific prerequisites for the agentic workflow.
#
# This script runs automatically before each Developer and Reviewer agent session.
# Use it to install tools, compilers, or SDKs that the agents need for this repo.
#
# The standard prerequisites (Node.js, jq, python3, gh CLI, Claude Code CLI)
# are already installed before this script runs.

set -euo pipefail

# ---------------------------------------------------------------------------
# AL Compiler (Business Central)
#
# Installs the Microsoft Dynamics 365 Business Central AL development tools
# as a .NET global tool. This provides the `AL` command which wraps alc.exe
# for compiling and working with AL extensions.
#
# Package: microsoft.dynamics.businesscentral.development.tools.linux
# Docs:    https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-al-tool-package
# ---------------------------------------------------------------------------

AL_PACKAGE="microsoft.dynamics.businesscentral.development.tools.linux"
DOTNET_TOOLS_PATH="$HOME/.dotnet/tools"

# Ensure .NET SDK is available (required to run dotnet global tools)
if ! command -v dotnet &>/dev/null; then
  echo "[prerequisites] dotnet not found — installing .NET SDK 8.0..."
  # Add Microsoft package feed (Debian/Ubuntu)
  wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
  sudo dpkg -i /tmp/packages-microsoft-prod.deb
  rm -f /tmp/packages-microsoft-prod.deb
  sudo apt-get update -q
  sudo apt-get install -y dotnet-sdk-8.0
else
  echo "[prerequisites] dotnet $(dotnet --version) already available"
fi

# Add dotnet tools directory to PATH for this session
if [[ ":$PATH:" != *":$DOTNET_TOOLS_PATH:"* ]]; then
  export PATH="$PATH:$DOTNET_TOOLS_PATH"
fi

# Install or update the AL development tools if not already present
if dotnet tool list --global 2>/dev/null | grep -qi "$AL_PACKAGE"; then
  echo "[prerequisites] AL compiler already installed: $(dotnet tool list --global | grep -i "$AL_PACKAGE" | awk '{print $1, $2}')"
else
  echo "[prerequisites] Installing AL compiler ($AL_PACKAGE)..."
  dotnet tool install --global "$AL_PACKAGE"
  echo "[prerequisites] AL compiler installed successfully"
fi

# Verify the AL tool is accessible
if [ -x "$DOTNET_TOOLS_PATH/AL" ]; then
  echo "[prerequisites] AL compiler ready: $("$DOTNET_TOOLS_PATH/AL" version)"
else
  echo "[prerequisites] WARNING: AL compiler not found at $DOTNET_TOOLS_PATH/AL. Check dotnet tool installation." >&2
  exit 1
fi
