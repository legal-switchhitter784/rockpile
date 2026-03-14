#!/bin/bash
# export-sprites.sh — Export Aseprite .ase files to sprite sheets + JSON metadata
#
# Usage: ./scripts/export-sprites.sh [sprites_dir] [output_dir]
#
# Requires: Aseprite CLI (aseprite -b)
# Install: brew install --cask aseprite  OR  build from source
#
# Output per .ase file:
#   - <name>.png   — packed sprite sheet
#   - <name>.json  — frame metadata (positions, durations, tags)

set -euo pipefail

SPRITES_DIR="${1:-sprites}"
OUTPUT_DIR="${2:-Rockpile/Resources/Sprites}"

# Check Aseprite
ASEPRITE=""
if command -v aseprite &>/dev/null; then
    ASEPRITE="aseprite"
elif [ -f "/Applications/Aseprite.app/Contents/MacOS/aseprite" ]; then
    ASEPRITE="/Applications/Aseprite.app/Contents/MacOS/aseprite"
else
    echo "Error: Aseprite not found. Install it or add to PATH."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check for .ase files
shopt -s nullglob
ASE_FILES=("$SPRITES_DIR"/*.ase "$SPRITES_DIR"/*.aseprite)
shopt -u nullglob

if [ ${#ASE_FILES[@]} -eq 0 ]; then
    echo "No .ase/.aseprite files found in $SPRITES_DIR"
    exit 0
fi

echo "Exporting ${#ASE_FILES[@]} sprite files..."

for ase_file in "${ASE_FILES[@]}"; do
    name=$(basename "$ase_file" | sed 's/\.\(ase\|aseprite\)$//')
    echo "  → $name"

    "$ASEPRITE" -b \
        --sheet-pack \
        --trim \
        --extrude 1 \
        --data "$OUTPUT_DIR/$name.json" \
        --sheet "$OUTPUT_DIR/$name.png" \
        --format json-array \
        "$ase_file"
done

echo "Done! Output in $OUTPUT_DIR"
