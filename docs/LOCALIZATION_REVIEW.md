# Localization and Content Review Notes

## Honest status

- **30 locales ship** with complete interface catalogues and **68,911 unique fortunes**.
- **English** content is authored/composed for this project.
- **Nigerian Pidgin** content and UI are authored manually (no dependency on a translator
  service).
- **Nine locales** use direct build-time machine translation of 2,640 distinct English
  fortunes each. These libraries have the most sentence-level variety.
- **Nineteen locales** use a resilience fallback: 2,100 unique two-sentence fortunes
  composed from 150 curated positive English sentences translated at build time with a
  local NLLB-200 model. This was adopted after the bulk online translation route was
  throttled. Each sentence appears in multiple combinations.
- **All non-English content requires fluent-speaker review before public release.**
  Machine-assisted text is not equivalent to professional localisation.

The game itself performs **no translation at runtime** and uses **no network**.

## Per-locale status

| Locale | Language | Unique records | Content method | Review |
|---|---|---:|---|---|
| en | English | 2,640 | Authored/composed | Source |
| es | Español | 2,639 | Direct build-time translation | Pending |
| zh | 中文 | 2,634 | Direct build-time translation | Pending |
| hi | हिन्दी | 2,633 | Direct build-time translation | Pending |
| ar | العربية | 2,640 | Direct build-time translation | Pending; RTL tested |
| fr | Français | 2,640 | Direct build-time translation | Pending |
| pt | Português | 2,637 | Direct build-time translation | Pending |
| bn | বাংলা | 2,638 | Direct build-time translation | Pending; high priority |
| ru | Русский | 2,632 | Direct build-time translation | Pending |
| id | Bahasa Indonesia | 2,100 | NLLB pair-bank | Pending |
| ur | اردو | 2,638 | Direct build-time translation | Pending; RTL tested |
| de | Deutsch | 2,100 | NLLB pair-bank | Pending |
| ja | 日本語 | 2,100 | NLLB pair-bank | Pending |
| pcm | Nigerian Pidgin | 2,640 | Authored | Pending |
| mr | मराठी | 2,100 | NLLB pair-bank | Pending; high priority |
| te | తెలుగు | 2,100 | NLLB pair-bank | Pending; high priority |
| tr | Türkçe | 2,100 | NLLB pair-bank | Pending |
| ta | தமிழ் | 2,100 | NLLB pair-bank | Pending; high priority |
| vi | Tiếng Việt | 2,100 | NLLB pair-bank | Pending |
| ko | 한국어 | 2,100 | NLLB pair-bank | Pending |
| it | Italiano | 2,100 | NLLB pair-bank | Pending |
| th | ไทย | 2,100 | NLLB pair-bank | Pending; high priority |
| fa | فارسی | 2,100 | NLLB pair-bank | Pending; RTL tested |
| sw | Kiswahili | 2,100 | NLLB pair-bank | Pending |
| ha | Hausa | 2,100 | NLLB pair-bank | Pending; high priority |
| yo | Yorùbá | 2,100 | NLLB pair-bank | Pending; high priority |
| nl | Nederlands | 2,100 | NLLB pair-bank | Pending |
| pl | Polski | 2,100 | NLLB pair-bank | Pending |
| fil | Filipino | 2,100 | NLLB pair-bank | Pending |
| he | עברית | 2,100 | NLLB pair-bank | Pending; RTL tested |

"High priority" reflects the author's assessment of low-resource or more distant
translation paths, not a quality grade.

## Interface catalogue

`data/ui/<locale>.json` contains 42 strings. English is the source and Nigerian Pidgin is
manually authored. The other 27 catalogues were seeded with build-time machine translation,
then manually corrected for ambiguous "fortune" wording and browser-cookie terminology in
Arabic, German, Persian, Hausa, Hebrew, Korean, Dutch, Russian, Turkish, Chinese, Japanese,
Polish, Indonesian, Vietnamese, Spanish, Portuguese, French, Italian, Yoruba and Pidgin.
Remaining strings still require review.

RTL:
- Arabic, Urdu, Persian and Hebrew are flagged `rtl: true`.
- The UI explicitly applies `LAYOUT_DIRECTION_RTL`, RTL text direction and right-aligned
  fortune paragraphs; it does not rely on locale switching alone.
- Arabic screenshots: `docs/screenshots/06_arabic_rtl.png`,
  `13_arabic_languages.png`, `14_arabic_settings.png`.
- Arabic, Urdu, Persian and Hebrew direction checks are in the headless suite.

Fonts:
- Embedded Noto Sans/Serif, Noto Sans CJK (SC/JP/KR faces), Arabic, Bengali, Devanagari,
  Hebrew, Tamil, Telugu, Thai and Noto Color Emoji.
- Chinese, Hindi and Arabic render correctly in captured screenshots.
- Fluent reviewers should still inspect shaping, line height, truncation and punctuation.

## The 150-sentence pair-bank fallback

The 19 NLLB locales use complete positive sentences rather than a few grammar templates.
The curated English bank spans luck, hope, love, growth, prosperity, wisdom, courage,
happiness, resilience, adventure, generosity and peace. Every shipped fortune combines
two distinct sentences and has a stable ID and category. No exact duplicates were found.

Trade-off: each source sentence is reused across several combinations. Reviewers may
replace awkward sentences or regenerate a locale with a professional translation
service. The English bank is `tools/curated_pair_bank.json`; per-locale translated banks
are in `data/fortunes/_banks/`; rebuild with:

```bash
python3 tools/build_pair_fortunes.py --locales de,ja,...
python3 tools/validate_fortunes.py
```

## Safety and content rules

- Positive, inclusive, non-frightening messages only.
- No curses, threats, bad omens, insults or guaranteed financial/medical outcomes.
- No claim that the game predicts the future; the settings sheet states this.
- No unattributed quotations or song lyrics.
- English negative/guarantee terms are scanned by the validator. Other languages rely
  on source control and fluent review because naive word lists create false positives.
- The validator reports **0 failures** and **161 advisory near-duplicate pairs**.

## Build-time translation provenance and licensing

- Direct build-time translation used a public Google Translate endpoint. Its output was
  generated offline into committed JSON; the game never calls it.
- The NLLB pair banks used **facebook/nllb-200-distilled-600M**, converted to
  CTranslate2 int8 (`JustFrederik/nllb-200-distilled-600M-ct2-int8`). NLLB-200 is
  published under **CC-BY-NC-4.0**. The model is not distributed with the game. If this
  game will be sold commercially, obtain a licensing review or replace the NLLB-assisted
  locales with professionally licensed translation.
- Model/tool versions used: CTranslate2 4.8.4, Transformers 5.21.0, Python 3.14.
- These tools are build-time-only; they are not included in exports or used at runtime.

## Recommended review workflow

1. Run `python3 tools/validate_fortunes.py`; read `reports/fortune-validation.md`.
2. For each locale, sample at least 100 fortunes across all categories plus the 42 UI
   strings.
3. Check grammar, tone, names, cultural fit, punctuation and line wrapping.
4. Resolve near-duplicate flags.
5. Prefer editing the source/bank and regenerating over hand-editing generated records.
6. Keep IDs stable where possible.
7. Re-run the validator and Godot test suite.
8. Capture new screenshots for RTL and long-message cases after changes.

## Known gaps

- No fluent-speaker sign-off has been performed.
- No physical mobile/touch device or screen reader was available.
- Machine-translated short UI labels can be contextually wrong; manual patches addressed
  the most visible cases only.
- The 19 pair-bank locales have less sentence variety than the 9 direct libraries.
- Near-duplicate flags are advisory, not a quality approval.
