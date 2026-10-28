# QA Checklist and Test Evidence

Verified on **2026-10-27** on Ubuntu 26.04.1 LTS, x86_64, Wayland, Intel Iris Xe,
Godot **4.7.2.stable.official.ed1daf0bf**.

Status legend: `[x]` verified, `[ ]` manual/device work still required. Nothing marked
`[x]` relies on a claim that was not actually exercised.

## Automated checks

- [x] Project imports without parser errors (`godot --headless --path . --editor --quit`).
- [x] Headless launch smoke test.
- [x] Content validator passes: 68,911 unique fortunes, 0 failures.
- [x] Godot integration suite passes: **398 passed, 0 failed**.
- [x] Linux export produced and launched headlessly.
- [x] Exported `--verify-content` loads all 30 locales and all UI catalogues.
- [x] Graphical performance probe completed on the real display/GPU.
- [x] Clipboard success round-trip on Wayland.
- [x] WAV files are valid 44.1 kHz/16-bit mono PCM and non-silent.

Commands:

```bash
python3 tools/validate_fortunes.py
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 8
godot --headless --path . res://tests/test_runner.tscn
godot --path . res://tests/screenshot.tscn
godot --path . res://tests/performance_probe.tscn
godot --path . res://tests/clipboard_probe.tscn
./builds/linux/FortuneCookie.x86_64 --headless --verify-content
```

## Content

- [x] Exactly 30 locale files exist.
- [x] Every locale has at least 2,000 unique valid fortunes.
- [x] Total exceeds 60,000 (68,911).
- [x] Required `id`, `locale`, `text`, `category` fields present.
- [x] Stable IDs unique per locale; locale field matches the filename.
- [x] No empty/whitespace-only messages, control characters, placeholders or noncharacters.
- [x] UTF-8 strict decode and NFC normalisation.
- [x] Message lengths 6–240 characters within script-aware limits.
- [x] Exact duplicate count: 0.
- [x] Near-duplicates scanned (SimHash + Hamming banding); 161 pairs flagged for editorial
  review. Reports: `reports/fortune-validation.json`, `reports/fortune-validation.md`.
- [x] All 30 interface catalogues have all 42 keys and no empty values.
- [x] No negative/guarantee language detected by the conservative English guardrail.
- [x] Unknown locale fallback returns a positive localised message and logs an error.
- [x] Malformed JSON and empty fields are rejected without crashing.

## Selection

- [x] 4,000 English draws: 0 immediate repeats.
- [x] Fewer than 10 recent repeats in 4,000 draws with a 32-entry observation window.
- [x] Recent history remains bounded at 64.
- [x] Language switching keeps working; Arabic fortune is genuinely non-ASCII.
- [x] Unknown locale does not leave an empty slip.
- [x] All 30 locales load and expose at least 2,000 records in the integration suite.
- [x] No network code exists in the runtime project.

## Interaction and animation

- [x] First crack accepted; immediate duplicate rejected.
- [x] State machine rejects illegal transitions.
- [x] Sequence reaches `FORTUNE_DISPLAY` and exposes the slip and actions.
- [x] Fortune text is non-empty and assigned to the slip.
- [x] Reset returns to `IDLE`, hides the slip and restores the shell.
- [x] Three reduced-motion crack/reset cycles complete.
- [x] Node count does not grow across repeated cycles.
- [x] Session counter increments once per successful crack.
- [x] Touch event path is exercised with `InputEventScreenTouch`.
- [x] Space keyboard activation is exercised when no control has focus.
- [x] Empty/duplicate-trigger guards are present.
- [x] Shell pieces animate independently and shell/crumb particle counts are bounded.
- [x] Particle nodes are hidden/cleared on reset so idle shows no stale crumbs.
- [ ] Actual finger latency and multi-touch feel on physical Android/iOS hardware.
- [ ] Speaker/device listening test with calibrated audio output.

## Responsive layout

Visually captured in `docs/screenshots/`:

- [x] 320×568: `11_small_idle.png`, `12_small_fortune.png`
- [x] 375×812: `18_mobile_375x812.png`
- [x] 390×844: `09_mobile_idle.png`, `10_mobile_fortune.png`
- [x] 768×1024: `17_tablet_768x1024.png`
- [x] 1280×720: `01_idle_desktop.png`, `03_fortune_display.png`
- [x] 1440×900: `16_1440x900.png`
- [x] 1920×1080: `15_1920x1080.png`
- [x] Small-screen action buttons wrap and both remain visible.
- [x] Cookie remains centred and clickable; hint remains visible.
- [x] Title compacts at 320 px without clipping.
- [x] Fortune text wraps and font size adapts for long messages.
- [x] Settings sheet becomes scrollable when it cannot fit.
- [x] Language list remains searchable and scrollable at 320×568.

## Languages, fonts, RTL

- [x] 30 selectable locales with flags, native names, English names and selected indicator.
- [x] Search filters rows and shows a no-results state.
- [x] Keyboard navigation/focus styles exist.
- [x] Switching language updates UI text without restart.
- [x] Arabic, Urdu, Persian and Hebrew direction tested in the integration suite.
- [x] Arabic screenshots show right-aligned fortune text and a mirrored UI
  (`06_arabic_rtl.png`, `13_arabic_languages.png`, `14_arabic_settings.png`).
- [x] Chinese and Devanagari render with embedded fonts (`07_chinese.png`,
  `08_hindi.png`).
- [x] Emoji flags render in the language selector.
- [x] Script-specific embedded fonts (Latin/CJK SC/JP/KR/Arabic/Bengali/Devanagari/
  Hebrew/Tamil/Telugu/Thai) load.
- [x] UI translation catalogue complete for all 30 locales.
- [ ] Fluent-speaker review of every translation and correction of awkward phrasing.
- [ ] Physical RTL device/keyboard/bidi paste testing beyond Godot's renderer.
- [ ] Screen-reader pass with the target desktop/mobile accessibility APIs.

## Settings, persistence, clipboard

- [x] Language, sound, reduced motion and low effects persist to `user://`.
- [x] Reload restores saved values.
- [x] Corrupt settings quarantined and defaults restored.
- [x] Atomic `.tmp` → target write pattern.
- [x] Settings and language sheets can be opened/closed; Escape closes topmost modal.
- [x] Reduced motion stops idle floating and removes most particles.
- [x] Low effects reduces particle counts and ambient sparkles.
- [x] Sound toggle visible; no autoplay; missing sound files are non-fatal.
- [x] Clipboard failure path reports a localised message without crashing (headless).
- [x] Clipboard success path round-trips on Wayland.
- [x] Ctrl+C copies while a fortune is displayed.

## Performance and resources

- [x] 1920×1080 / vsync graphical run: **59.5 FPS average**, 16.79 ms average frame,
  9 frames over 20 ms, 118 nodes, 139 draw calls in final frame.
- [x] Fixed cookie/particle node set; no per-crack allocations.
- [x] Fortune bag/history and JSON cache only for actually used locale groups.
- [x] 4,000 selection draws exercised in the headless suite.
- [x] Export runs on Compatibility/OpenGL 3.

Report: `reports/performance.txt`.

## Packaging

- [x] Linux x86_64 release exported with matching 4.7.2 templates.
- [x] Exported executable launches headlessly with no script errors.
- [x] Exported `--verify-content` reports 68,911 records across all 30 locales.
- [x] Application icon/version configured (`1.0.0`).
- [x] Asset/license documentation.
- [ ] Windows build physically executed.
- [ ] macOS build/signing executed.
- [ ] Android build/signing/device install executed.
- [ ] iOS build executed (requires macOS + Xcode).

## Manual review still required before public release

- [ ] Fluent-speaker content and UI review for all 29 non-English locales (highest
  priority: Hausa, Yoruba, Telugu, Tamil, Thai, Filipino).
- [ ] Review the 161 flagged near-duplicate pairs.
- [ ] Confirm cultural appropriateness with in-market reviewers.
- [ ] Run on at least one low-end Android phone and one iPhone.
- [ ] Test physical touch, rotation, safe areas, audio routing and clipboard.
- [ ] Confirm commercial licensing for build-time translation tooling if the game will
  be sold (see `docs/ASSET_LICENSES.md`).
- [ ] Final visual inspection of fonts on Windows/macOS/mobile.
