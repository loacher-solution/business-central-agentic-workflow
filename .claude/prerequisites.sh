#!/bin/bash
# Repo-specific prerequisites for the agentic workflow.
#
# This script runs automatically before each Developer and Reviewer agent session.
# Use it to install tools, compilers, or SDKs that the agents need for this repo.
#
# Examples:
#   sudo apt-get install -y dotnet-sdk-8.0
#   npm install -g some-cli
#   curl -sL https://example.com/tool | sudo bash
#
# The standard prerequisites (Node.js, jq, python3, gh CLI, Claude Code CLI)
# are already installed before this script runs.
