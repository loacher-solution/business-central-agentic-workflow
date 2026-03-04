#!/bin/bash
# BC Object Finder — SQLite version
# Searches AL objects in the SQLite index.
#
# Usage:
#   bc-find.sh "Sales Header"              Search by name
#   bc-find.sh --type table "Sales"        Filter by object type
#   bc-find.sh --id 36                     Find by object ID
#   bc-find.sh --repo BusinessCentralApps  Filter by source repo
#   bc-find.sh --type codeunit --repo BCApps "Post"   Combined filters

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_FILE="$SKILL_DIR/references/index.db"

if [ ! -f "$DB_FILE" ]; then
    echo "Error: Index not found at $DB_FILE"
    echo "Run build-index.sh first."
    exit 1
fi

# Parse arguments
OBJ_TYPE=""
OBJ_ID=""
REPO=""
SEARCH=""
LIMIT=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type|-t)
            OBJ_TYPE="$2"; shift 2 ;;
        --id|-i)
            OBJ_ID="$2"; shift 2 ;;
        --repo|-r)
            REPO="$2"; shift 2 ;;
        --limit|-l)
            LIMIT="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: bc-find.sh [OPTIONS] [SEARCH_TERM]"
            echo ""
            echo "Options:"
            echo "  --type, -t TYPE    Filter by object type (table, page, codeunit, ...)"
            echo "  --id,   -i ID     Find by exact object ID"
            echo "  --repo, -r REPO   Filter by source repo name"
            echo "  --limit, -l N     Max results (default: 30)"
            echo ""
            echo "Examples:"
            echo "  bc-find.sh \"Sales Header\""
            echo "  bc-find.sh --type table \"Sales\""
            echo "  bc-find.sh --id 36"
            exit 0
            ;;
        *)
            SEARCH="$1"; shift ;;
    esac
done

# Build WHERE clause
CONDITIONS=()

if [ -n "$SEARCH" ]; then
    # Escape single quotes
    safe_search="${SEARCH//\'/\'\'}"
    CONDITIONS+=("name LIKE '%${safe_search}%'")
fi

if [ -n "$OBJ_TYPE" ]; then
    safe_type="${OBJ_TYPE//\'/\'\'}"
    CONDITIONS+=("type = '${safe_type}'")
fi

if [ -n "$OBJ_ID" ]; then
    CONDITIONS+=("object_id = ${OBJ_ID}")
fi

if [ -n "$REPO" ]; then
    safe_repo="${REPO//\'/\'\'}"
    CONDITIONS+=("source_repo LIKE '%${safe_repo}%'")
fi

if [ ${#CONDITIONS[@]} -eq 0 ]; then
    echo "Error: Provide at least a search term, --type, --id, or --repo"
    exit 1
fi

# Join conditions with AND
WHERE=""
for i in "${!CONDITIONS[@]}"; do
    [ "$i" -gt 0 ] && WHERE="$WHERE AND "
    WHERE="$WHERE${CONDITIONS[$i]}"
done

sqlite3 -header -column "$DB_FILE" \
    "SELECT type, object_id, name, source_repo, filepath, line FROM objects WHERE $WHERE ORDER BY type, object_id LIMIT $LIMIT;"
