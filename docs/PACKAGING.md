# Packaging and Release Guide

## Version and identity

- Product: **Fortune Cookie: A Little Luck**
- Version: `1.0.0`
- Engine: **Godot 4.7.2 stable**, standard (non-.NET)
- Base resolution: 1280×720; responsive anchors and direct-pixel layout
- Renderer: Compatibility / OpenGL 3
- Icon: `icon.svg`
- Bundle/user directory: `user://` with custom name `FortuneCookieALittleLuck`

## Linux x86_64 — built and tested here

The convenience command is:

```bash
make release
```

It runs content validation and the headless test suite, exports the release binary,
verifies all packaged content, and creates
`builds/release/FortuneCookie-1.0.0-linux-x86_64.zip` plus `SHA256SUMS.txt`.

Matching export templates are installed at:

```text
~/.local/share/godot/export_templates/4.7.2.stable/
```

Export:

```bash
./scripts/export-linux.sh
```

Output:

```text
builds/linux/FortuneCookie.x86_64
builds/linux/FortuneCookie.pck
```

Verify the packaged content and runtime:

```bash
./builds/linux/FortuneCookie.x86_64 --headless --verify-content
./builds/linux/FortuneCookie.x86_64 --headless --quit-after 6
```

Actual result on this machine: `EXPORT_CONTENT_TOTAL=68911`,
`EXPORT_CONTENT_RESULT=PASS`, exit 0. The binary launches and renders the scene.

Optional release archive:

```bash
mkdir -p builds/release
cp builds/linux/FortuneCookie.x86_64 builds/linux/FortuneCookie.pck builds/release/
cd builds/release
zip -9 FortuneCookie-1.0.0-linux-x86_64.zip FortuneCookie.x86_64 FortuneCookie.pck
```

The Linux build requires a working OpenGL 3 driver (Mesa or vendor driver) and common
desktop libraries. It was tested on Intel Iris Xe/Mesa 26 on Wayland. It does not need
Godot installed or network access.

> The export is intentionally ignored by Git (`builds/*`); rebuild it from source with
> the matching templates.

## Windows

The project is configured as a standard Godot 4 desktop game and has no Linux-only
runtime APIs. Build from a Windows machine or from Linux with the Windows export
templates installed.

1. Install Godot 4.7.2 and its matching export templates.
2. Open the project, choose **Project → Export → Add… → Windows Desktop**.
3. Set the export path to `builds/windows/FortuneCookie.exe`.
4. Keep `x86_64`, embedded PCK optional.
5. Add an `.ico` if desired; the SVG icon is used by the project.
6. Export and test on a clean Windows machine.
7. Sign the executable if distributing publicly.

Include `FortuneCookie.pck` next to the executable unless embedded PCK is enabled. The
JSON content must be included; duplicate the Linux preset's include filter if creating
the preset from scratch.

**Not built or tested on this Ubuntu machine.**

## macOS

A macOS bundle can be exported from Godot on Linux only if the macOS export templates
are installed, but app signing, notarisation and final validation require macOS/Xcode.

1. Install Godot 4.7.2 + macOS export templates on a Mac.
2. Add a **macOS** export preset.
3. Set a unique bundle identifier, for example
   `com.yourdomain.fortunecookie`.
4. Select universal or arm64/x86_64 as intended.
5. Export the `.app` / `.zip`.
6. Sign with a Developer ID certificate and notarise with Apple's tooling.
7. Test Gatekeeper on a clean Mac.

**Not built or tested here.** A complete macOS release cannot be produced/validated
entirely on Ubuntu.

## Android

The matching Android templates (`android_debug.apk`, `android_release.apk`) are installed
with the 4.7.2 template package. Android build tooling is **not** installed/configured on
this machine.

Prerequisites:

- Android SDK with platform/build tools and `adb`
- A JDK version compatible with the selected Godot release (Godot 4.x commonly uses
  JDK 17; verify the 4.7 requirements)
- Android export templates for 4.7.2
- A release keystore, kept outside source control
- `ANDROID_HOME` or Godot editor SDK path configured

Steps:

1. In Godot: **Editor → Manage Export Templates** and confirm the Android templates.
2. **Editor → Editor Settings → Export → Android** and set SDK/JDK paths.
3. **Project → Export → Add… → Android**.
4. Set package name (`com.yourdomain.fortunecookie`), version code/name, min/target SDK,
   architectures, and screen orientation.
5. For a release build, create/configure a keystore and password in the export preset or
   `export_credentials.cfg` (never commit credentials).
6. Export AAB for Play Store or APK for sideloading.
7. Install on a physical phone and test:
   - touch and multi-touch,
   - portrait/landscape resizing and safe areas,
   - back button/suspend/resume,
   - clipboard,
   - audio routing and reduced motion.
8. Re-run the content validator; no content depends on Android.

The game sets a 1280×720 base viewport with direct-pixel responsive layout, so a phone
does not need letterboxing. Test actual safe areas/notches before release.

**Not built or tested here** because the Android SDK/JDK/signing toolchain is absent.

## iOS

A complete iOS build requires:

- macOS and a compatible Xcode
- Apple Developer account and provisioning profiles
- Godot 4.7.2 iOS export templates
- an iOS export preset/bundle identifier
- signing and a physical iOS device or simulator for validation

It cannot be completed entirely on Ubuntu. The Godot project itself is mobile-friendly
and uses touch input, but iOS packaging/signing is a macOS/Xcode workflow.

## Optional Web export

Not implemented or requested. The shipped product is a native Godot game. There are no
browser frameworks or mandatory servers.

## Asset and content packaging

The Linux preset includes:

```text
data/*.json
data/ui/*.json
data/fortunes/*.json
README.md
docs/*.md
assets/fonts/LICENSE-NOTO.txt
```

The preset excludes `tests/`, `tools/`, `reports/`, `docs/screenshots/`, `builds/` and
Git metadata. Fonts, SVG art, WAV files and scenes are resources and are packed
automatically. The `--verify-content` mode in `scripts/main.gd` proves the fortune and UI
JSON are present in the packaged build.

## Reproducible content validation

The shipped JSON libraries are committed. To re-validate:

```bash
python3 tools/validate_fortunes.py
```

To regenerate:

1. `python3 tools/generate_fortunes.py --english --pidgin` builds the English/Pidgin
   sources.
2. Build-time translation tools (`generate_fortunes.py` or `translate_nllb.py` +
   `build_pair_fortunes.py`) can seed other locales. They are not runtime dependencies.
3. Normalise output to NFC and re-run the validator.
4. Review reports under `reports/`.

The NLLB phrase-bank tool requires the external model and build-only Python packages
listed in `tools/requirements-translate.txt`; do not add these to the game export.

## Release checklist

- [ ] Re-run `./scripts/check-dev-env.sh`.
- [ ] Re-run `python3 tools/validate_fortunes.py` (must exit 0).
- [ ] Re-run the Godot integration suite (must exit 0).
- [ ] Review the 161 near-duplicate flags and fluent-speaker content notes.
- [ ] Re-capture screenshots at supported resolutions.
- [ ] Re-run the graphical performance probe.
- [ ] Export Linux and run `--verify-content`.
- [ ] Build and device-test Android/iOS/Windows/macOS if releasing there.
- [ ] Verify licenses and review the build-time translation model terms if selling.
- [ ] Archive the matching Godot export templates/version used for the release.
- [ ] Never commit keystores, provisioning profiles or `export_credentials.cfg`.

## Troubleshooting

- **"No export template found"** — install the templates for exactly `4.7.2.stable`,
  not just `4.7.2`.
- **Missing JSON/content** — check the preset's include filter for `data/*.json` and run
  the exported binary with `--verify-content`.
- **Black or blank window** — try
  `--rendering-method gl_compatibility --rendering-driver opengl3` and update Mesa.
- **Wayland clipboard** — copy succeeds only while the app owns focus; verify by pasting
  into a text editor. Headless mode correctly reports unavailable.
- **Audio silence** — check the in-game speaker toggle, system mixer and output device.
  Missing SFX are non-fatal.
- **Android export fails** — check JDK/SDK compatibility and matching templates; ensure
  signing credentials are valid and not in Git.
