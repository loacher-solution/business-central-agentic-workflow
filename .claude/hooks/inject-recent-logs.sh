#!/usr/bin/env bash
# SessionStart hook: injects recent activity logs into Claude's context.
# Outputs the N most recent log files (by filename) so agents have immediate
# context about what happened in this repo — regardless of gaps between dates.
#
# The number of log files is configurable via `recent_logs_count` in
# .claude/config.yml or config.yml (per-repo). Defaults to 3 if not set.
#
# Usage: Registered as a SessionStart hook in .claude/settings.json
# The stdout of this script is injected into the conversation.

set -euo pipefail

# Verify we're in a git repo, but keep CWD (project dir) for log lookup
git rev-parse --show-toplevel 2>/dev/null || exit 0

LOGS_DIR=".claude/agent-memory/logs"
DEFAULT_COUNT=3

if [ ! -d "$LOGS_DIR" ]; then
  exit 0
fi

# Read recent_logs_count from per-repo config (check both locations)
count=$DEFAULT_COUNT
for config in ".claude/config.yml" "config.yml"; do
  if [ -f "$config" ]; then
    parsed=$(grep -E '^recent_logs_count:\s*[0-9]+' "$config" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
    if [ -n "$parsed" ]; then
      count=$parsed
      break
    fi
  fi
done

# Find the N most recent log files by name (YYYY-MM-DD.md sorts chronologically)
mapfile -t recent_logs < <(ls -1 "$LOGS_DIR"/*.md 2>/dev/null | sort -r | head -"$count")

if [ ${#recent_logs[@]} -eq 0 ]; then
  exit 0
fi

echo "## Recent Activity Logs"
echo ""

# Output in chronological order (oldest first)
for (( i=${#recent_logs[@]}-1; i>=0; i-- )); do
  log_file="${recent_logs[$i]}"
  filename=$(basename "$log_file")
  echo "### ${filename%.md}"
  echo ""
  cat "$log_file"
  echo ""
done
