#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

# Export the tested Linux x86_64 build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT="$(command -v godot)"
  elif [ -x "$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ]; then
    GODOT="$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
  fi
fi
if [ -z "$GODOT" ]; then
  echo "Godot 4 executable not found." >&2
  exit 1
fi
mkdir -p "$ROOT/builds/linux"
"$GODOT" --headless --path "$ROOT" --editor --quit
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "$ROOT/builds/linux/FortuneCookie.x86_64"
chmod +x "$ROOT/builds/linux/FortuneCookie.x86_64"
echo "Exported $ROOT/builds/linux/FortuneCookie.x86_64"
