#!/bin/bash
# Repo-specific prerequisites for the agentic workflow.
#
# This script runs automatically before each Developer and Reviewer agent session.
# Use it to install tools, compilers, or SDKs that the agents need for this repo.
#
# The standard prerequisites (Node.js, jq, python3, gh CLI, Claude Code CLI)
# are already installed before this script runs.

# Install @microsoft/bc-replay for Business Central E2E testing
# This makes `npx replay` available for running BC page scripts
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
if [ -f "$ROOT/package.json" ]; then
  echo "Installing npm dependencies (including @microsoft/bc-replay)..."
  cd "$ROOT" && npm install --quiet 2>&1 | tail -5
fi
