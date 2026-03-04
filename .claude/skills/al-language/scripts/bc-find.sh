#!/bin/bash
# BC Object Finder - Searches objects in the AL index
# Usage: bc-find.sh "Sales Header"
#        bc-find.sh table 36
#        bc-find.sh codeunit "Sales-Post"

INDEX="$HOME/.openclaw/skills/al-language/references/object-lookup.txt"

if [ -z "$1" ]; then
    echo "Usage: bc-find.sh <search term>"
    echo "       bc-find.sh table 36"
    echo "       bc-find.sh \"Sales Header\""
    exit 1
fi

# Combine all args for search
search="$*"

grep -i "$search" "$INDEX" | grep -v "^#" | head -20
