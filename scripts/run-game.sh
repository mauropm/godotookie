#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

# Launch the game using a local Godot 4.7.2 install or GODOT_BIN.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then GODOT="$(command -v godot4)"
  elif [ -x "$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ]; then
    GODOT="$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
  else
    echo "Godot 4 was not found. Set GODOT_BIN or run scripts/check-dev-env.sh." >&2
    exit 1
  fi
fi
exec "$GODOT" --path "$ROOT" "$@"
