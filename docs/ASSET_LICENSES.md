# Asset, Font, Engine and Content Licenses

## Project code, artwork and audio

The GDScript, SVG artwork (cookie halves, icon, sparkles, crumbs and UI icons), the
custom-drawn parchment background and the four WAV sound effects were created for this
project. They are released under the project's **MIT License** (`LICENSE`).

The cookie, background, rings and particles are original vector/procedural work. No
third-party stock art, icon packs, music, lyrics or quotations are bundled.

## Fonts

The following fonts are embedded so the game works offline on systems without Noto
fonts installed:

- Noto Sans Regular/Bold
- Noto Serif Regular/Bold
- Noto Sans CJK Regular (SC/JP/KR/HK/TC faces)
- Noto Sans Arabic, Bengali, Devanagari, Hebrew, Tamil, Telugu and Thai
- Noto Color Emoji (used for Unicode flags and symbols)

License: **SIL Open Font License, Version 1.1**. The full Debian copyright/license file
from the system font package is retained as:

```text
assets/fonts/LICENSE-NOTO.txt
```

Copyright belongs to the Noto Project Authors / Google and contributors. The fonts are
not sold separately. Their OFL terms permit embedding in the game. Names beginning
"Noto" remain subject to the OFL trademark/name provisions.

## Godot Engine

The games are built with **Godot Engine 4.7.2**, Copyright © 2007–2026 Juan Linietsky,
Ariel Manzur and contributors. Godot is licensed under the MIT License.

The full engine copyright notice is included at:

```text
docs/GODOT_COPYRIGHT.txt
```

The Godot license text is also available at
<https://godotengine.org/license>. The Linux export bundles the engine runtime and its
required notices.

## Fortune content

The English and Nigerian Pidgin fortunes, the curated English sentence bank and the
game-specific UI copy were authored for this project. They are intended to be distributed
with the game.

The other locale libraries were seeded with build-time machine translation and curated,
edited and normalized as described in `docs/LOCALIZATION_REVIEW.md`. They are provided
as game content and require fluent-speaker review before public release.

No fortune is copied from a copyrighted quotation collection or song lyric. There are no
attributed third-party quotations.

## Build-time translation services and models (not distributed)

- **Google Translate public endpoint** was used during a build-time drafting pass for
  some locale libraries and interface strings. The shipped game makes no network calls.
  Google's service terms apply to use of that service; no API key, model or service
  credential is included in this repository.
- **NLLB-200 distilled 600M** (`facebook/nllb-200-distilled-600M`, converted to
  CTranslate2 int8 by `JustFrederik`) was used locally at build time to translate 150
  curated sentences for 19 locales. NLLB-200 is published under **CC-BY-NC-4.0**. The
  model is **not** included in this repository or the game export. Outputs were used to
  compose game sentences; if this game will be commercially distributed, obtain a
  licensing review or replace those locales with professionally licensed translations.
- Build-only dependencies are listed in `tools/requirements-translate.txt` and are not
  part of the Godot runtime or export.

## Generated validation and test artifacts

Reports under `reports/` and screenshots under `docs/screenshots/` were generated from
this project for QA and documentation. They may be reused with the project.

## No database/server/API runtime

The shipped application has no HTTP client, backend, database, paid runtime API or
network requirement. It runs offline from `user://` preferences and packaged resources.
