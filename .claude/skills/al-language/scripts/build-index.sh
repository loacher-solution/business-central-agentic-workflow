#!/bin/bash
# AL Object Index Builder - Fast version
# Scans all BC repos and creates a searchable index

BC_REF_DIR="$HOME/.openclaw/workspace/bc-reference"
INDEX_FILE="$HOME/.openclaw/skills/al-language/references/object-lookup.txt"

echo "Building AL Object Index..."

cd "$BC_REF_DIR" || exit 1

# Header
echo "# AL Object Index - Generated $(date -Iseconds)" > "$INDEX_FILE"
echo "# Source: $BC_REF_DIR" >> "$INDEX_FILE"
echo "# Format: FILEPATH:LINE:  type id \"name\"" >> "$INDEX_FILE"
echo "#" >> "$INDEX_FILE"

# Single grep - fast!
grep -rn --include="*.al" -E '^\s*(table|page|codeunit|report|enum|query|xmlport|tableextension|pageextension|enumextension|reportextension|interface|permissionset)\s+[0-9]+\s+"[^"]+"' . 2>/dev/null | \
sed 's/^\.\///' >> "$INDEX_FILE"

count=$(wc -l < "$INDEX_FILE")
echo "Index created: $count entries"
echo "   Location: $INDEX_FILE"
echo ""
echo "Usage: grep -i 'search term' $INDEX_FILE"
