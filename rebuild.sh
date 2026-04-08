#!/bin/bash
# Reimport assets, export the web build, and repackage the itch.io zip.
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

echo "--- Reimporting assets ---"
./godot.sh --headless --import

echo "--- Exporting Web build ---"
./godot.sh --export-release "Web" build/web/index.html

echo "--- Repackaging zip ---"
(cd build/web && zip -r ../drama-tictactoe-club-web.zip . -x "*.import" > /dev/null)

ls -lh build/drama-tictactoe-club-web.zip
echo "--- Done ---"
