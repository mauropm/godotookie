# Implementation Plan — Fortune Cookie: A Little Luck

## Product summary

A native, offline-first Godot 4.7.2 2D game. A hand-drawn fortune cookie floats at
the centre of a warm parchment scene. Clicking, tapping, pressing Enter, or pressing
Space cracks it into independently animated shell halves, scatters a bounded burst of
crumbs and sparkles, and reveals a localised uplifting fortune on a paper slip.

The player can copy the fortune and request unlimited fresh cookies. Preferences are
stored locally in `user://`.

## Technical architecture

| Area | Decision |
|---|---|
| Engine | Godot 4.7.2 stable, standard (non-.NET) build |
| Renderer | Compatibility / OpenGL 3 for broad desktop and VM support |
| Language | GDScript, typed where practical |
| Resolution | 1280 × 720 logical base; responsive anchors with direct pixel layout |
| Scenes | `main.tscn`, `fortune_cookie.tscn`, `shell_piece.tscn` plus script-built UI panels |
| Autoloads | Settings, localisation, fortunes, audio |
| Art | Original SVG cookie halves, crumb, sparkle, icon, custom-drawn background |
| Audio | Original locally synthesised WAV effects; no music, no autoplay |
| Persistence | `user://settings.json`, corrupt-file recovery |
| Content | 12 categories × ≥2,000 validated records per locale |
| Tests | Headless Godot test runner + Python content validator + export smoke test |

## State machine

`IDLE → ANTICIPATION → CRACKING → FORTUNE_REVEAL → FORTUNE_DISPLAY → RESETTING → IDLE`

Only `IDLE` accepts a crack request. Every transition is validated. A single cookie
node and a fixed set of particles are reused, so repeated sessions do not accumulate
nodes.

## Interaction

- Mouse click on a generous circular hit area.
- Touch tap through Godot's emulated mouse/touch input.
- Enter/Space when no UI control owns focus.
- Duplicate-input protection by the state machine.
- Hover produces restrained scale/glow feedback; hover is never required.

## Animation

- Idle: vertical ease, horizontal drift, rotation, breathing scale, ambient sparkles.
- Anticipation: compression and two quick wobbles.
- Crack: two shell halves with separate trajectories, rotations, easing, gravity feel,
  and independent timing; bounded crumb and gold-sparkle particles; golden ring.
- Reveal: paper slip rises, rotates, unfolds, settles, then text fades in.
- Display: copy and another-cookie actions become available.
- Reset: slip dismisses, halves restore, state returns to idle.

Reduced motion removes ambient drift, wobble, and most particles and shortens motion.
Low-effects mode cuts particle counts and ambient sparkles independently.

## Localisation

- 30 locale metadata records (`data/locales.json`) with configurable native name,
  English name, flag, font group and RTL flag.
- Interface strings live in `data/ui/<locale>.json` and are loaded into Godot
  `Translation` resources at runtime.
- Fortunes live separately in `data/fortunes/<locale>.json` and are loaded only for the
  selected locale.
- Arabic, Urdu, Persian and Hebrew explicitly set RTL text direction and alignment.
- Script-appropriate embedded Noto fonts: Latin, CJK (SC/JP/KR faces), Arabic,
  Bengali, Devanagari, Hebrew, Tamil, Telugu, Thai, plus colour emoji flags.
- OS locale is used on first run when supported; otherwise English.

## Fortune selection

A shuffled index bag avoids immediate repetition. A bounded 64-entry recent-history
set avoids recent repeats. Bags are rebuilt on language switch and refill safely.
Missing or malformed content produces a localised positive fallback and a logged
development error. No network calls occur at runtime.

## Content pipeline

`tools/generate_fortunes.py` deterministically composes a rich English source library
from 12 categories and a large phrase grammar. `tools/translate_content.py` can seed
localisations through an offline-at-runtime build step; generated JSON is committed so
the game never contacts the network. Nigerian Pidgin is authored separately because
the translation service does not support it. All non-English content is marked for
fluent-speaker review in `docs/LOCALIZATION_REVIEW.md`.

`tools/validate_fortunes.py` enforces fields, UTF-8 integrity, minimum counts, uniqueness,
near-duplicate detection, empties/placeholders, and length limits, and writes both JSON
and Markdown reports.

## Delivery sequence

1. Environment verification and documentation.
2. Project shell, art, fonts, audio.
3. Cookie state machine and reveal animation.
4. UI, settings, language selector, clipboard.
5. Localisation metadata and UI translations.
6. 30 fortune libraries and validation.
7. Headless tests, graphical screenshots, export.
8. QA, packaging docs, final report.

## Explicit limitations

- Visual and animation quality is checked through captured screenshots on this Ubuntu
  machine; no physical touchscreen or mobile device is available.
- Windows, macOS, Android and iOS exports are configured/documented but not built or
  tested here. iOS requires macOS and Xcode.
- Machine-assisted localisations require fluent-speaker review before public release.
