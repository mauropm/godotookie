#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

# Run content validation plus the headless Godot integration suite.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
  if command -v godot >/dev/null 2>&1; then GODOT="$(command -v godot)"
  elif [ -x "$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ]; then
    GODOT="$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
  fi
fi
status=0
python3 "$ROOT/tools/validate_fortunes.py" || status=1
if [ -n "$GODOT" ]; then
  "$GODOT" --headless --path "$ROOT" --editor --quit || status=1
  "$GODOT" --headless --path "$ROOT" res://tests/test_runner.tscn || status=1
else
  echo "Godot executable not found; skipped Godot tests." >&2
  status=1
fi
exit "$status"
