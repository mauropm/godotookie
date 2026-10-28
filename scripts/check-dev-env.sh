#!/usr/bin/env bash
# Verify the essentials for developing/running/exporting Fortune Cookie on Ubuntu.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
failures=0
warnings=0

pass() { printf '  [ok]   %s\n' "$1"; }
warn() { printf '  [warn] %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf '  [fail] %s\n' "$1"; failures=$((failures + 1)); }
heading() { printf '\n%s\n' "$1"; }

heading "Operating system"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf '  %s (%s)\n' "${PRETTY_NAME:-unknown}" "${VERSION_CODENAME:-unknown}"
  case "${ID:-}" in
    ubuntu) pass "Ubuntu detected" ;;
    *) warn "This guide targets Ubuntu; detected '${ID:-unknown}'." ;;
  esac
else
  fail "/etc/os-release not found"
fi
ARCH="$(uname -m)"
printf '  Architecture: %s\n' "$ARCH"
case "$ARCH" in
  x86_64|aarch64|arm64) pass "Architecture is supported by official Godot builds" ;;
  *) warn "Unusual architecture '$ARCH'; verify the Godot build manually." ;;
esac
printf '  Kernel: %s\n' "$(uname -r)"
printf '  CPUs: %s\n' "$(nproc 2>/dev/null || echo unknown)"
printf '  Memory: %s\n' "$(free -h 2>/dev/null | awk '/Mem:/ {print $2 " total, " $7 " available"}')"
printf '  Disk: %s\n' "$(df -h . | awk 'NR==2 {print $4 " available on " $6}')"

heading "Godot 4"
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
  for candidate in godot godot4; do
    if command -v "$candidate" >/dev/null 2>&1; then GODOT_BIN="$(command -v "$candidate")"; break; fi
  done
fi
if [ -z "$GODOT_BIN" ] && [ -x "$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64" ]; then
  GODOT_BIN="$HOME/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
fi
if [ -n "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ]; then
  GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null | head -n 1)"
  printf '  Executable: %s\n' "$GODOT_BIN"
  printf '  Version: %s\n' "$GODOT_VERSION"
  case "$GODOT_VERSION" in
    4.*) pass "Godot 4.x detected" ;;
    *) fail "Godot 3.x or unreadable version detected; project requires Godot 4.x" ;;
  esac
  if "$GODOT_BIN" --headless --version >/dev/null 2>&1; then
    pass "Headless execution works"
  else
    fail "Headless execution failed"
  fi
else
  fail "Godot 4 executable not found (set GODOT_BIN or add it to PATH)"
  GODOT_VERSION=""
fi

heading "Project and tooling"
[ -f project.godot ] && pass "project.godot present at $ROOT" || fail "project.godot missing (run from the project root)"
if command -v git >/dev/null 2>&1; then pass "Git $(git --version | awk '{print $3}')"; else fail "Git not installed"; fi
if command -v python3 >/dev/null 2>&1; then
  pass "Python $(python3 --version 2>&1 | awk '{print $2}')"
  if python3 - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY
  then pass "Python 3.10+ available"; else fail "Python 3.10+ required"; fi
else
  fail "python3 not installed"
fi
for tool in unzip curl; do
  command -v "$tool" >/dev/null 2>&1 && pass "$tool available" || warn "$tool missing (needed to install downloads/templates)"
done

heading "Export templates"
if [ -n "${GODOT_VERSION:-}" ]; then
  TEMPLATE_VERSION="${GODOT_VERSION%%.official*}"
  TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_VERSION"
  printf '  Expected directory: %s\n' "$TEMPLATE_DIR"
  if [ -f "$TEMPLATE_DIR/version.txt" ] && [ -f "$TEMPLATE_DIR/linux_release.x86_64" ]; then
    pass "Matching templates installed ($(cat "$TEMPLATE_DIR/version.txt"))"
  else
    warn "Matching export templates not found; desktop Linux export will not work"
  fi
fi

heading "Graphics / display (optional for headless checks)"
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  printf '  Session: %s (DISPLAY=%s WAYLAND_DISPLAY=%s)\n' "${XDG_SESSION_TYPE:-unknown}" "${DISPLAY:-}" "${WAYLAND_DISPLAY:-}"
  pass "Graphical display detected; graphical visual QA is possible"
else
  warn "No graphical display detected; headless tests only"
fi
if command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -Eiq 'vga|3d|display'; then
  lspci 2>/dev/null | grep -Ei 'vga|3d|display' | sed 's/^/  /'
else
  warn "Could not inspect GPU via lspci"
fi

heading "Optional export platforms"
if command -v java >/dev/null 2>&1; then pass "Java available for Android export"; else warn "Java not available; Android export not ready"; fi
if [ -n "${ANDROID_HOME:-}" ] || [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  pass "Android SDK environment variable present"
else
  warn "Android SDK not configured (optional; desktop game is unaffected)"
fi
if command -v xcodebuild >/dev/null 2>&1; then pass "Xcode available"; else warn "Xcode unavailable (expected on Ubuntu; iOS export requires macOS)"; fi

printf '\nSummary: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
if [ "$failures" -gt 0 ]; then
  printf 'Essential prerequisites are missing. See docs/UBUNTU_SETUP.md.\n'
  exit 1
fi
printf 'Essential prerequisites are ready.\n'
exit 0
