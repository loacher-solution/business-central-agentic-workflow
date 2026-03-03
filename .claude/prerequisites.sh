#!/bin/bash
# Repo-specific prerequisites for the agentic workflow.
#
# This script runs automatically before each Developer and Reviewer agent session.
# Use it to install tools, compilers, or SDKs that the agents need for this repo.
#
# The standard prerequisites (Node.js, jq, python3, gh CLI, Claude Code CLI)
# are already installed before this script runs.

# Install BC test dependencies if package.json exists and node_modules is missing
TESTS_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/tests"
if [ -f "$TESTS_DIR/package.json" ] && [ ! -d "$TESTS_DIR/node_modules" ]; then
  echo "Installing BC Playwright test dependencies..."
  cd "$TESTS_DIR" && npm install --quiet
fi
