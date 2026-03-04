#!/bin/bash
# AL Object Index Builder — SQLite version
# Reads sources.conf and builds a searchable SQLite index of all AL objects.

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_FILE="$SKILL_DIR/sources.conf"
DB_FILE="$SKILL_DIR/references/index.db"
TMP_TSV=$(mktemp /tmp/al-index-XXXXXX.tsv)
TMP_AWK=$(mktemp /tmp/al-index-XXXXXX.awk)

trap "rm -f $TMP_TSV $TMP_AWK" EXIT

if [ ! -f "$SOURCES_FILE" ]; then
    echo "Error: $SOURCES_FILE not found"
    exit 1
fi

if ! command -v sqlite3 &>/dev/null; then
    echo "Error: sqlite3 is required but not installed"
    exit 1
fi

# Remove old DB and create fresh
rm -f "$DB_FILE"

sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE objects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    object_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    filepath TEXT NOT NULL,
    source_repo TEXT NOT NULL,
    line INTEGER NOT NULL
);
SQL

echo "Building AL Object Index (SQLite)..."

# Write the awk program to a temp file to avoid quoting hell
cat > "$TMP_AWK" << 'AWKSCRIPT'
{
    # Input: /full/path/file.al:LINE:  type id "name"
    idx1 = index($0, ":")
    filepath = substr($0, 1, idx1 - 1)
    rest = substr($0, idx1 + 1)
    idx2 = index(rest, ":")
    lineno = substr(rest, 1, idx2 - 1)
    declaration = substr(rest, idx2 + 1)

    # Make filepath relative to repo
    sub(repo_path, "", filepath)

    # Strip leading whitespace
    gsub(/^[[:space:]]+/, "", declaration)

    # Parse type (first word) and id (second word)
    match(declaration, /^[a-z]+/)
    obj_type = substr(declaration, RSTART, RLENGTH)

    rest2 = substr(declaration, RLENGTH + 1)
    gsub(/^[[:space:]]+/, "", rest2)
    match(rest2, /^[0-9]+/)
    obj_id = substr(rest2, RSTART, RLENGTH)

    # Extract name between first pair of double quotes
    q1 = index(declaration, "\"")
    if (q1 > 0) {
        tmp = substr(declaration, q1 + 1)
        q2 = index(tmp, "\"")
        if (q2 > 0) {
            obj_name = substr(tmp, 1, q2 - 1)
        }
    }

    # Output as TSV: type, object_id, name, filepath, source_repo, line
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", obj_type, obj_id, obj_name, filepath, repo, lineno
}
AWKSCRIPT

# Clear TSV
> "$TMP_TSV"

while IFS= read -r raw_line; do
    # Skip comments and empty lines
    line=$(echo "$raw_line" | sed 's/#.*//' | xargs)
    [ -z "$line" ] && continue

    # Expand env vars (e.g. $HOME)
    repo_path=$(eval echo "$line")

    if [ ! -d "$repo_path" ]; then
        echo "  SKIP (not found): $repo_path"
        continue
    fi

    repo_name=$(basename "$repo_path")
    echo "  Indexing: $repo_name"

    grep -rn --include="*.al" -E '^\s*(table|page|codeunit|report|enum|query|xmlport|tableextension|pageextension|enumextension|reportextension|interface|permissionset)\s+[0-9]+\s+"[^"]+"' "$repo_path" 2>/dev/null | \
    awk -v repo="$repo_name" -v repo_path="$repo_path/" -f "$TMP_AWK" >> "$TMP_TSV"

done < "$SOURCES_FILE"

# Import TSV into a temp table, then copy to objects
sqlite3 "$DB_FILE" <<SQL
CREATE TABLE _import(type TEXT, object_id INTEGER, name TEXT, filepath TEXT, source_repo TEXT, line INTEGER);
.mode tabs
.import $TMP_TSV _import
INSERT INTO objects(type, object_id, name, filepath, source_repo, line) SELECT * FROM _import;
DROP TABLE _import;
SQL

# Create indexes after bulk insert (faster)
sqlite3 "$DB_FILE" <<'SQL'
CREATE INDEX idx_objects_name ON objects(name COLLATE NOCASE);
CREATE INDEX idx_objects_type ON objects(type);
CREATE INDEX idx_objects_object_id ON objects(object_id);
CREATE INDEX idx_objects_source_repo ON objects(source_repo);
SQL

# Stats
echo ""
sqlite3 "$DB_FILE" "SELECT source_repo, COUNT(*) AS count FROM objects GROUP BY source_repo ORDER BY count DESC;" | \
while IFS='|' read -r repo count; do
    printf '  %-30s %s objects\n' "$repo" "$count"
done

total=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM objects;")
echo ""
echo "Total: $total objects in $DB_FILE"
