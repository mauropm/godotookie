# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Locale metadata, runtime interface translations, RTL handling and fonts.

signal locale_changed(code: String)

const LOCALES_PATH := "res://data/locales.json"
const UI_PATH := "res://data/ui/%s.json"
const FONT_DIR := "res://assets/fonts/"
const SCRIPT_FONTS := {
    "latin": "NotoSans-Regular.ttf",
    "arabic": "NotoSansArabic-Regular.ttf",
    "bengali": "NotoSansBengali-Regular.ttf",
    "devanagari": "NotoSansDevanagari-Regular.ttf",
    "hebrew": "NotoSansHebrew-Regular.ttf",
    "tamil": "NotoSansTamil-Regular.ttf",
    "telugu": "NotoSansTelugu-Regular.ttf",
    "thai": "NotoSansThai-Regular.ttf",
}
const CJK_FACES := {"cjk_sc": 2, "cjk_jp": 0, "cjk_kr": 1}

var locales: Array = []
var by_code: Dictionary = {}
var fallback_locale := "en"
var current_locale := "en"
var flags_are_country_suggestions := true

var _ui_cache: Dictionary = {}
var _translations: Dictionary = {}
var _font_cache: Dictionary = {}
var _emoji_font: Font
var _latin_font: Font
var _latin_serif: Font
var _latin_serif_bold: Font
var _loaded := false


func _ready() -> void:
    _load_metadata()
    if SettingsManager != null:
        SettingsManager.changed.connect(_on_setting_changed)
        set_language(SettingsManager.language, false)
    else:
        set_language("en", false)


func _on_setting_changed(key: String, value: Variant) -> void:
    if key == "language" and value is String:
        set_language(value, false)


func _load_metadata() -> void:
    var file := FileAccess.open(LOCALES_PATH, FileAccess.READ)
    if file == null:
        push_error("Locale metadata is missing: %s" % LOCALES_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Locale metadata is not valid JSON.")
        return
    fallback_locale = str(parsed.get("fallback_locale", "en"))
    flags_are_country_suggestions = bool(parsed.get("flags_are_country_suggestions", true))
    locales = parsed.get("locales", [])
    by_code.clear()
    for item in locales:
        if item is Dictionary and item.has("code"):
            by_code[str(item["code"])] = item
    _loaded = true


func set_language(code: String, persist := true) -> void:
    if not by_code.has(code):
        push_warning("Locale %s unavailable; keeping %s." % [code, current_locale])
        if current_locale == "en" and not by_code.has("en"):
            return
        code = fallback_locale if by_code.has(fallback_locale) else "en"
    if persist and SettingsManager != null:
        SettingsManager.set_language(code)
    var was_same := current_locale == code and _loaded
    current_locale = code
    _ensure_translation(fallback_locale)
    _ensure_translation(code)
    TranslationServer.set_locale(code)
    if not was_same:
        locale_changed.emit(code)


func _ensure_translation(code: String) -> void:
    if _translations.has(code):
        return
    var data := _load_ui_data(code)
    if data.is_empty():
        return
    var translation := Translation.new()
    translation.locale = code
    for key in data:
        translation.add_message(str(key), str(data[key]))
    TranslationServer.add_translation(translation)
    _translations[code] = translation


func _load_ui_data(code: String) -> Dictionary:
    if _ui_cache.has(code):
        return _ui_cache[code]
    var path := UI_PATH % code
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Missing UI translation: %s" % path)
        _ui_cache[code] = {}
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Invalid UI translation: %s" % path)
        _ui_cache[code] = {}
        return {}
    _ui_cache[code] = parsed
    return parsed


func t(key: String) -> String:
    var translated := TranslationServer.translate(key)
    if translated != key and not translated.is_empty():
        return translated
    var fallback_data := _load_ui_data(fallback_locale)
    if fallback_data.has(key):
        return str(fallback_data[key])
    return key


func has_locale(code: String) -> bool:
    return by_code.has(code)


func meta(code := current_locale) -> Dictionary:
    return by_code.get(code, {})


func native_name(code := current_locale) -> String:
    return str(meta(code).get("native_name", code))


func english_name(code := current_locale) -> String:
    return str(meta(code).get("english_name", code))


func flag(code := current_locale) -> String:
    return str(meta(code).get("flag", "🌐"))


func is_rtl(code := current_locale) -> bool:
    return bool(meta(code).get("rtl", false))


func font_group(code := current_locale) -> String:
    return str(meta(code).get("font", "latin"))


func ui_font(code := current_locale) -> Font:
    var group := font_group(code)
    return _font_for_group(group, false)


func fortune_font(code := current_locale) -> Font:
    var group := font_group(code)
    return _font_for_group(group, true)


func title_font(code := current_locale) -> Font:
    var group := font_group(code)
    if group == "latin":
        return _get_serif_bold()
    return _font_for_group(group, true)


func emoji_font() -> Font:
    if _emoji_font == null:
        _emoji_font = load(FONT_DIR + "NotoColorEmoji.ttf") as Font
        if _emoji_font != null and _emoji_font is FontFile:
            (_emoji_font as FontFile).allow_system_fallback = true
    return _emoji_font


func _font_for_group(group: String, serif_role: bool) -> Font:
    var cache_key := "%s:%s" % [group, "fortune" if serif_role else "ui"]
    if _font_cache.has(cache_key):
        return _font_cache[cache_key]

    var font: Font
    if group == "latin" and serif_role:
        font = _get_serif()
    elif CJK_FACES.has(group):
        font = _make_cjk_font(int(CJK_FACES[group]))
    else:
        var filename: String = SCRIPT_FONTS.get(group, SCRIPT_FONTS["latin"])
        font = load(FONT_DIR + filename) as Font
        if font == null:
            font = _get_latin()
    if font is FontFile:
        (font as FontFile).allow_system_fallback = true
    var fallbacks: Array[Font] = []
    if group != "latin":
        fallbacks.append(_get_latin())
    var emoji := emoji_font()
    if emoji != null:
        fallbacks.append(emoji)
    font.fallbacks = fallbacks
    _font_cache[cache_key] = font
    return font


func _get_latin() -> Font:
    if _latin_font == null:
        _latin_font = load(FONT_DIR + "NotoSans-Regular.ttf") as Font
        if _latin_font != null:
            if _latin_font is FontFile:
                (_latin_font as FontFile).allow_system_fallback = true
            var emoji := emoji_font()
            if emoji != null:
                _latin_font.fallbacks = [emoji]
    return _latin_font


func _get_serif() -> Font:
    if _latin_serif == null:
        _latin_serif = load(FONT_DIR + "NotoSerif-Regular.ttf") as Font
        if _latin_serif != null:
            if _latin_serif is FontFile:
                (_latin_serif as FontFile).allow_system_fallback = true
            _latin_serif.fallbacks = [_get_latin()]
    return _latin_serif


func _get_serif_bold() -> Font:
    if _latin_serif_bold == null:
        _latin_serif_bold = load(FONT_DIR + "NotoSerif-Bold.ttf") as Font
        if _latin_serif_bold != null:
            if _latin_serif_bold is FontFile:
                (_latin_serif_bold as FontFile).allow_system_fallback = true
            _latin_serif_bold.fallbacks = [_get_latin()]
    return _latin_serif_bold


func _make_cjk_font(face_index: int) -> Font:
    var base := load(FONT_DIR + "NotoSansCJK-Regular.ttc") as Font
    if base == null:
        return _get_latin()
    if base is FontFile:
        (base as FontFile).allow_system_fallback = true
    var variation := FontVariation.new()
    variation.base_font = base
    variation.variation_face_index = face_index
    return variation


func apply_direction(root: Node) -> void:
    var rtl := is_rtl()
    _apply_direction_recursive(root, rtl)


func _apply_direction_recursive(node: Node, rtl: bool) -> void:
    if node is Control:
        var control := node as Control
        control.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
        if not control.has_meta("bidi_auto"):
            var direction := Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
            if control is Label:
                (control as Label).text_direction = direction
            elif control is Button:
                (control as Button).text_direction = direction
            elif control is LineEdit:
                (control as LineEdit).text_direction = direction
    for child in node.get_children():
        _apply_direction_recursive(child, rtl)


func text_direction() -> Control.TextDirection:
    return Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR


func required_ui_keys() -> Array[String]:
    var keys: Array[String] = []
    var data := _load_ui_data(fallback_locale)
    for key in data:
        keys.append(str(key))
    return keys
