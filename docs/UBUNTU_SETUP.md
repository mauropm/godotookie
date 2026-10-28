# Ubuntu Setup and Verification

## Verified machine (2026-10-27)

| Item | Result |
|---|---|
| OS | Ubuntu 26.04.1 LTS (Resolute Raccoon) |
| Architecture | x86_64 |
| Kernel | 7.0.0-38-generic |
| CPUs / RAM / free disk | 8 / 14 GiB / ~135 GiB free |
| Session | Wayland (`wayland-0`) with X11 compatibility (`DISPLAY=:0`) |
| GPU | Intel TigerLake-LP GT2 Iris Xe Graphics |
| Virtualisation | none detected (physical machine) |
| Existing Godot | none |
| Godot installed | **4.7.2.stable.official.ed1daf0bf** |
| Godot executable | `/home/magumison/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64` |
| Convenience symlink | `~/.local/bin/godot` → the executable above |
| Export templates | `~/.local/share/godot/export_templates/4.7.2.stable/` |
| Git / Python | Git 2.53.0 / Python 3.14.4 |
| Basic tools reused | `curl`, `wget`, `unzip`, `fc-list`; no APT packages were changed |

The project directory was empty and was initialised as a new Git repository. No user
files, package upgrades, shell profiles or system PATH entries were modified.

## 1. Install the essential tools

Check first, then install only what is missing:

```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip unzip curl ca-certificates
```

This project's validator uses only the Python standard library. A virtual environment
is therefore not required. If future tooling needs packages:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt   # only if such a file is added
```

## 2. Install Godot 4.x (verified route)

APT on this Ubuntu release only offers Godot 3.6, which is not suitable. The official
Godot 4.7.2 Linux x86_64 archive was downloaded from:

<https://github.com/godotengine/godot/releases/tag/4.7.2-stable>

```bash
mkdir -p ~/.local/share/godot-editor/4.7.2 ~/.local/bin
cd /tmp
curl -fLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
curl -fLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
sha512sum Godot_v4.7.2-stable_linux.x86_64.zip
grep 'Godot_v4.7.2-stable_linux.x86_64.zip' SHA512-SUMS.txt
unzip Godot_v4.7.2-stable_linux.x86_64.zip -d ~/.local/share/godot-editor/4.7.2
chmod +x ~/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64
ln -sfn ~/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot
```

Verified SHA-512 for the editor archive:

```text
9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
```

Do **not** install this as root. `~/.local/bin` is already on PATH on this machine. If it
is not on your PATH, call the executable by its full path or set `GODOT_BIN`; no profile
change is required.

### Architecture notes

- `x86_64`: use the Linux x86_64 archive above.
- `aarch64`/`arm64`: use `Godot_v4.7.2-stable_linux.arm64.zip` from the same release.
- Do not run x86_64 binaries on ARM without a deliberate emulation layer.

### Verify

```bash
godot --version
godot --headless --version
```

Expected prefix: `4.7.2.stable.official`.

## 3. Install matching export templates

The template archive is large (~1.2 GB). Verify it before extraction:

```bash
cd /tmp
curl -fLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
curl -fLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
sha512sum Godot_v4.7.2-stable_export_templates.tpz
grep 'export_templates.tpz' SHA512-SUMS.txt
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable
unzip -q Godot_v4.7.2-stable_export_templates.tpz -d /tmp/godot-template-extract
cp -a /tmp/godot-template-extract/templates/. ~/.local/share/godot/export_templates/4.7.2.stable/
cat ~/.local/share/godot/export_templates/4.7.2.stable/version.txt
```

Verified template SHA-512:

```text
ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
```

The installed `version.txt` must read exactly `4.7.2.stable`.

## 4. Fonts

The game embeds Noto Sans, Noto Serif, Noto Sans CJK, Arabic, Bengali, Devanagari,
Hebrew, Tamil, Telugu, Thai and Noto Color Emoji under `assets/fonts/`. These were copied
from Ubuntu's installed Noto font packages and are distributed under the SIL Open Font
License (see `assets/fonts/LICENSE-NOTO.txt`). Embedding them means the exported game
does not rely on fonts being installed on the player's machine.

## 5. Graphics and headless

This machine has a Wayland desktop and Intel Iris Xe graphics. The project uses Godot's
**Compatibility (OpenGL 3)** renderer for broad hardware support. Graphical screenshots
were captured with Godot's viewport API on this session; no physical touchscreen or
mobile device was available.

```bash
# Interactive desktop game
./scripts/run-game.sh

# Headless import/parse check
godot --headless --path . --editor --quit

# Headless launch smoke test
godot --headless --path . --quit-after 8

# Headless integration tests
godot --headless --path . res://tests/test_runner.tscn
```

For a headless-only server, export templates and content validation still work, but
animation quality cannot be visually inspected. Headless mode is not evidence that the
animation looks correct.

## 6. Project verification

```bash
./scripts/check-dev-env.sh
python3 tools/validate_fortunes.py
./scripts/test.sh
```

The development check returns nonzero when an essential prerequisite is missing.
`validate_fortunes.py` writes reports to `reports/`.

## 7. Export

Linux (tested):

```bash
./scripts/export-linux.sh
./builds/linux/FortuneCookie.x86_64 --headless --quit-after 4
```

The Linux preset includes JSON content, fonts, audio and documentation. Windows, macOS,
Android and iOS instructions are in `docs/PACKAGING.md`.

## 8. Common Ubuntu problems

### Godot window is blank or fails on a VM

Try the Compatibility renderer explicitly:

```bash
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
```

### Wayland/X11 input warnings

Godot may log an XIM warning on a Wayland session. It is harmless. For an X11 fallback:

```bash
XDG_SESSION_TYPE=x11 godot --path .
```

### Export says templates are missing

The folder name and `version.txt` must match the editor exactly, including `.stable`.
Use the full version directory `4.7.2.stable`, not `4.7.2`.

### Clipboard on headless or locked sessions

`DisplayServer.clipboard_set()` cannot work with the dummy/headless display server. The
game reports this safely with a localised message instead of crashing. On Wayland the
clipboard is owned by the focused application; verify by pasting into a text editor.

### Audio is silent

Sound is off by default only if the user turned it off. Check the speaker button, the
localised settings sheet and the host audio server. Missing optional audio files are
detected and logged without preventing the game from running.

### Fonts look like boxes

The required fonts are embedded. If boxes still appear, run a fresh import
(`godot --headless --path . --editor --quit`) and confirm the files under
`assets/fonts/` are present in the project/export.

### Command names

This setup provides `godot` via the symlink. On other machines use `godot4` or set
`GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64`; all repository scripts honour it.
