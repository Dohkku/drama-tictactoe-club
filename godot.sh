#!/bin/bash
# Helper script to run Godot console in headless mode
GODOT="/c/Users/frederick.andrade/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.1-stable_win64_console.exe"

"$GODOT" --headless --path /c/dev/godot_test "$@"
