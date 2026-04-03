#!/bin/bash

# Ported for Linux/multiplatform
# This script uses the local 'bin' Godot binary or searches in PATH

PROJECT_PATH=$(dirname "$(readlink -f "$0")")
LOCAL_BIN="$PROJECT_PATH/bin/Godot_v4.6.1-stable_linux.x86_64"

if [ -f "$LOCAL_BIN" ]; then
    GODOT_BIN="$LOCAL_BIN"
elif [ -z "$GODOT_BIN" ]; then
    if command -v godot4 &> /dev/null; then
        GODOT_BIN="godot4"
    elif command -v godot &> /dev/null; then
        GODOT_BIN="godot"
    else
        echo "Error: Godot executable not found in PATH or 'bin/'."
        echo "Please install Godot or set GODOT_BIN environment variable."
        exit 1
    fi
fi

echo "--- Running Godot from: $PROJECT_PATH ---"
# Using --headless for CLI execution
"$GODOT_BIN" --path "$PROJECT_PATH" --headless "$@"
