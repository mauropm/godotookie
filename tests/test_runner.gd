# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Lightweight headless integration test suite (no third-party framework).

const CookieScript := preload("res://scripts/fortune_cookie.gd")
const STATE_IDLE := 0
const STATE_FORTUNE_DISPLAY := 4
const EXPECTED_LOCALES := [
    "en", "es", "zh", "hi", "ar", "fr", "pt", "bn", "ru", "id", "ur", "de",
    "ja", "pcm", "mr", "te", "tr", "ta", "vi", "ko", "it", "th", "fa", "sw",
    "ha", "yo", "nl", "pl", "fil", "he",
]
const TEST_SETTINGS := "user://fortune-cookie-test-settings.json"

var passed := 0
var failed := 0
var _failure_lines: Array[String] = []
var _main: Node
var _ui: Control
var _cookie: Node
var _original_settings: Dictionary
var _original_settings_path: String


func _ready() -> void:
    _original_settings = SettingsManager.snapshot()
    _original_settings_path = SettingsManager.settings_path
    print("== Fortune Cookie headless test suite ==")
    await _test_metadata_and_ui()
    await _test_fortunes()
    await _test_settings()
    await _test_main_scene()
    await _cleanup()
    print("== RESULT: %d passed, %d failed ==" % [passed, failed])
    if failed > 0:
        for line in _failure_lines:
            print("  FAILED: ", line)
    get_tree().quit(0 if failed == 0 else 1)


func _check(condition: bool, message: String) -> void:
    if condition:
        passed += 1
    else:
        failed += 1
        _failure_lines.append(message)
        push_error("TEST FAILED: %s" % message)


func _section(name: String) -> void:
    print("-- ", name)


func _test_metadata_and_ui() -> void:
    _section("locale metadata and interface catalogue")
    _check(LocalizationManager.locales.size() == 30, "expected 30 locale metadata records")
    for code in EXPECTED_LOCALES:
        _check(LocalizationManager.has_locale(code), "missing locale metadata for %s" % code)
        var meta := LocalizationManager.meta(code)
        _check(not str(meta.get("native_name", "")).is_empty(), "empty native name for %s" % code)
        _check(not str(meta.get("english_name", "")).is_empty(), "empty English name for %s" % code)
        _check(not str(meta.get("flag", "")).is_empty(), "empty flag for %s" % code)
        _check(meta.has("font"), "missing font group for %s" % code)
    _check(LocalizationManager.is_rtl("ar"), "Arabic must be RTL")
    _check(LocalizationManager.is_rtl("ur"), "Urdu must be RTL")
    _check(LocalizationManager.is_rtl("fa"), "Persian must be RTL")
    _check(LocalizationManager.is_rtl("he"), "Hebrew must be RTL")
    _check(not LocalizationManager.is_rtl("en"), "English must be LTR")
    var expected_keys := LocalizationManager.required_ui_keys()
    _check(expected_keys.size() >= 35, "English UI catalogue unexpectedly small")
    for code in EXPECTED_LOCALES:
        var panel := FileAccess.open("res://data/ui/%s.json" % code, FileAccess.READ)
        _check(panel != null, "missing UI catalogue for %s" % code)
        if panel == null:
            continue
        var parsed: Variant = JSON.parse_string(panel.get_as_text())
        _check(parsed is Dictionary, "invalid UI catalogue for %s" % code)
        if not parsed is Dictionary:
            continue
        var data: Dictionary = parsed
        var missing := 0
        var empty := 0
        for key in expected_keys:
            if not data.has(key):
                missing += 1
            elif not data[key] is String or str(data[key]).strip_edges().is_empty():
                empty += 1
        _check(missing == 0, "%s has %d missing UI keys" % [code, missing])
        _check(empty == 0, "%s has %d empty UI values" % [code, empty])


func _test_fortunes() -> void:
    _section("fortune data, selection and fallbacks")
    FortuneManager.clear_cache()
    var total := 0
    for code in EXPECTED_LOCALES:
        var count := FortuneManager.count_for(code)
        _check(count >= 2000, "%s has only %d fortunes" % [code, count])
        total += count
    _check(total >= 60000, "total fortune records below 60,000 (%d)" % total)
    FortuneManager.clear_cache()
    FortuneManager.set_seed(424242)
    var last_text := ""
    var immediate_repeats := 0
    var recent: Array[String] = []
    var recent_repeats := 0
    for i in range(4000):
        var fortune := FortuneManager.next_fortune("en")
        var text := str(fortune.get("text", ""))
        if i < 3:
            _check(not text.is_empty(), "empty English fortune at draw %d" % i)
        if text == last_text:
            immediate_repeats += 1
        if recent.has(text):
            recent_repeats += 1
        recent.append(text)
        if recent.size() > 32:
            recent.pop_front()
        last_text = text
    _check(immediate_repeats == 0, "immediate fortune repetition detected (%d)" % immediate_repeats)
    _check(recent_repeats < 10, "too many recent repeats in 4000 draws (%d)" % recent_repeats)
    _check(FortuneManager.recent_indexes("en").size() <= 64, "recent history is not bounded")

    LocalizationManager.set_language("ar", false)
    var arabic := FortuneManager.next_fortune("ar")
    _check(str(arabic.get("locale", "")) == "ar", "Arabic fortune locale mismatch")
    _check(not str(arabic.get("text", "")).is_empty(), "Arabic fortune is empty")
    _check(_has_non_ascii(str(arabic.get("text", ""))), "Arabic fortune is unexpectedly ASCII")
    LocalizationManager.set_language("en", false)

    var fallback := FortuneManager.next_fortune("zz")
    _check(not str(fallback.get("text", "")).is_empty(), "unknown locale did not produce a fallback text")
    _check(str(fallback.get("id", "")).begins_with("fallback-"), "unknown locale fallback id mismatch")

    var bad_path := "user://malformed-fortunes.json"
    var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
    bad_file.store_string("[{not valid json")
    bad_file.close()
    var loaded := FortuneManager.load_from_file(bad_path, "bad")
    _check(loaded == 0, "malformed JSON should not load records")
    _check(not FortuneManager.last_error.is_empty(), "malformed JSON did not report an error")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))

    var field_path := "user://invalid-fortunes.json"
    var field_file := FileAccess.open(field_path, FileAccess.WRITE)
    field_file.store_string(JSON.stringify([
        {"id": "", "locale": "bad", "text": "", "category": "hope"},
        {"id": "bad-0001", "locale": "bad", "text": "   ", "category": "hope"},
    ]))
    field_file.close()
    _check(FortuneManager.load_from_file(field_path, "bad") == 0, "empty fields should be rejected")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(field_path))
    FortuneManager.clear_cache()
    LocalizationManager.set_language("en", false)


func _test_settings() -> void:
    _section("settings persistence and corrupt-file recovery")
    SettingsManager.settings_path = TEST_SETTINGS
    var absolute := ProjectSettings.globalize_path(TEST_SETTINGS)
    if FileAccess.file_exists(TEST_SETTINGS):
        DirAccess.remove_absolute(absolute)
    if FileAccess.file_exists(TEST_SETTINGS + ".corrupt"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS + ".corrupt"))
    SettingsManager.load_settings()
    SettingsManager.set_language("fr", true)
    SettingsManager.set_sound_enabled(false, true)
    SettingsManager.set_reduced_motion(true, true)
    SettingsManager.set_low_effects(true, true)
    _check(FileAccess.file_exists(TEST_SETTINGS), "settings file was not written")
    var written := FileAccess.open(TEST_SETTINGS, FileAccess.READ)
    var written_data: Variant = JSON.parse_string(written.get_as_text())
    written.close()
    _check(written_data is Dictionary, "settings file is not valid JSON")
    if written_data is Dictionary:
        _check(written_data.get("language") == "fr", "persisted language mismatch")
        _check(written_data.get("sound") == false, "persisted sound mismatch")
        _check(written_data.get("reduced_motion") == true, "persisted reduced motion mismatch")
        _check(written_data.get("low_effects") == true, "persisted low effects mismatch")
    SettingsManager.load_settings()
    _check(SettingsManager.language == "fr", "language did not reload")
    _check(SettingsManager.sound_enabled == false, "sound did not reload")
    _check(SettingsManager.reduced_motion == true, "reduced motion did not reload")
    _check(SettingsManager.low_effects == true, "low effects did not reload")

    var corrupt := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
    corrupt.store_string("this is not JSON {")
    corrupt.close()
    SettingsManager.load_settings()
    _check(SettingsManager.language in EXPECTED_LOCALES, "corrupt settings left an invalid language")
    _check(FileAccess.file_exists(TEST_SETTINGS + ".corrupt"), "corrupt settings were not quarantined")
    DirAccess.remove_absolute(absolute)
    if FileAccess.file_exists(TEST_SETTINGS + ".corrupt"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS + ".corrupt"))

    SettingsManager.settings_path = _original_settings_path
    SettingsManager.language = str(_original_settings["language"])
    SettingsManager.sound_enabled = bool(_original_settings["sound"])
    SettingsManager.reduced_motion = bool(_original_settings["reduced_motion"])
    SettingsManager.low_effects = bool(_original_settings["low_effects"])
    LocalizationManager.set_language(str(_original_settings["language"]), false)


func _test_main_scene() -> void:
    _section("main scene, animation state machine, RTL and clipboard")
    SettingsManager.language = "en"
    SettingsManager.reduced_motion = false
    SettingsManager.low_effects = false
    LocalizationManager.set_language("en", false)
    _main = load("res://scenes/main.tscn").instantiate()
    add_child(_main)
    await get_tree().create_timer(0.7).timeout
    _ui = _main.get_node("UI/GameUI")
    _cookie = _main.get_node("CookieLayer/FortuneCookie")
    _check(_ui != null, "GameUI did not load")
    _check(_cookie.state == STATE_IDLE, "cookie did not start idle")
    _check(_ui.slip != null, "fortune slip did not load")
    _check(_ui._hint.visible, "idle hint is not visible")
    _check(_cookie.get_node("Effects/Crumbs").amount <= 54, "crumb particle count is not bounded")
    _check(_cookie.get_node("Effects/Sparkles").amount <= 26, "sparkle particle count is not bounded")
    _check(AudioManager.available_sounds().size() == 4, "expected four locally generated sound effects")

    var started: bool = _cookie.request_crack()
    _check(started, "first crack request was rejected")
    _check(not _cookie.request_crack(), "duplicate crack request was not rejected")
    await get_tree().create_timer(2.1).timeout
    _check(_cookie.state == STATE_FORTUNE_DISPLAY, "cookie did not reach FORTUNE_DISPLAY")
    _check(_ui.slip.visible, "fortune slip is not visible")
    _check(not _ui.current_text.strip_edges().is_empty(), "revealed fortune text is empty")
    _check(_ui._actions.visible, "fortune actions are not visible")
    _check(_ui.session == 1, "session counter did not increment")
    _check(not _ui.slip.get_fortune_text().is_empty(), "slip did not receive the fortune")

    _check(ClipboardService.copy_text("test") == false, "headless clipboard should report failure")
    ClipboardService.force_failure = true
    _check(ClipboardService.copy_text("test") == false, "forced clipboard failure was not reported")
    ClipboardService.force_failure = false
    _main._copy_fortune()
    _check(_ui._toast.visible, "clipboard failure toast was not displayed")

    LocalizationManager.set_language("ar", false)
    await get_tree().create_timer(0.2).timeout
    var fortune_label: Label = _ui.slip.get_node("Card/VBox/FortuneText")
    _check(fortune_label.text_direction == Control.TEXT_DIRECTION_RTL, "Arabic fortune is not RTL")
    _check(fortune_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Arabic fortune is not right-aligned")
    _check(_ui.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic UI layout is not RTL")
    _check(not _ui.current_text.strip_edges().is_empty(), "Arabic fortune text is empty")
    _check(_ui._title.text == LocalizationManager.t("app_title"), "Arabic interface title did not update")
    for rtl_code in ["ur", "fa", "he"]:
        LocalizationManager.set_language(rtl_code, false)
        await get_tree().create_timer(0.12).timeout
        _check(fortune_label.text_direction == Control.TEXT_DIRECTION_RTL, "%s fortune is not RTL" % rtl_code)
        _check(not _ui.current_text.strip_edges().is_empty(), "%s fortune text is empty" % rtl_code)
    LocalizationManager.set_language("en", false)
    await get_tree().create_timer(0.2).timeout

    var selector = _ui.language_selector
    selector.open()
    _check(selector.visible, "language selector did not open")
    _check(selector._rows.size() == 30, "language selector does not contain 30 rows")
    selector._search.text = "Español"
    selector._filter("Español")
    var visible_rows := 0
    for entry in selector._rows:
        if entry["button"].visible:
            visible_rows += 1
    _check(visible_rows == 1, "language search did not filter to one result")
    selector._search.text = "zzzzzz"
    selector._filter("zzzzzz")
    _check(selector._empty.visible, "language no-results state did not appear")
    selector.close()
    _check(not selector.visible, "language selector did not close")

    var long_text := "A gentle opportunity is gathering around you with warmth, patience and a bright, hopeful beginning for every small step you take. "
    long_text = long_text.repeat(3)
    _ui.show_fortune(long_text, "en", false)
    await get_tree().process_frame
    _check(fortune_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "long fortune does not wrap")
    _check(fortune_label.get_theme_font_size("font_size") <= 30, "long fortune font is too large")

    _ui.another_requested.emit()
    await get_tree().create_timer(0.8).timeout
    _check(_cookie.state == STATE_IDLE, "cookie did not reset to idle")
    _check(not _ui.slip.visible, "fortune slip remained visible after reset")

    SettingsManager.set_reduced_motion(true, false)
    SettingsManager.set_low_effects(true, false)
    await get_tree().process_frame
    var reduced_position: Vector2 = _cookie.position
    await get_tree().create_timer(0.3).timeout
    _check(_cookie.position.distance_to(reduced_position) < 0.5, "reduced motion still moves the idle cookie")
    var nodes_before := _count_nodes(get_tree().root)
    for i in range(3):
        var ok: bool = _cookie.request_crack()
        _check(ok, "reduced-motion crack %d was rejected" % i)
        await get_tree().create_timer(1.25).timeout
        _check(_cookie.state == STATE_FORTUNE_DISPLAY, "reduced-motion crack %d did not display" % i)
        _check(_cookie.request_reset(), "reduced-motion reset %d was rejected" % i)
        await get_tree().create_timer(0.75).timeout
        _check(_cookie.state == STATE_IDLE, "reduced-motion reset %d did not return idle" % i)
    var nodes_after := _count_nodes(get_tree().root)
    _check(nodes_after <= nodes_before + 2, "node count grew during repeated cracks (%d -> %d)" % [nodes_before, nodes_after])
    _check(_ui.session == 4, "session counter mismatch after repeated cracks")
    SettingsManager.set_reduced_motion(false, false)
    SettingsManager.set_low_effects(false, false)

    var bad_transitions := [
        [STATE_IDLE, 2], [1, 0], [2, 4], [4, 0], [5, 4],
    ]
    for pair in bad_transitions:
        _check(not CookieScript.is_transition_allowed(pair[0], pair[1]), "invalid transition was accepted: %s" % str(pair))

    SettingsManager.set_reduced_motion(false, false)
    SettingsManager.set_low_effects(false, false)
    await get_tree().process_frame
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    touch.position = _cookie.position
    _cookie._on_hit_area_input_event(null, touch, 0)
    await get_tree().create_timer(0.15).timeout
    _check(_cookie.state != STATE_IDLE, "touch event did not start the crack sequence")
    await get_tree().create_timer(2.0).timeout
    _check(_cookie.state == STATE_FORTUNE_DISPLAY, "touch-triggered sequence did not display")
    _check(_ui.session == 5, "touch gesture did not increment the session counter")
    _cookie.request_reset()
    await get_tree().create_timer(0.8).timeout

    var focus_owner := get_viewport().gui_get_focus_owner()
    if focus_owner != null:
        focus_owner.release_focus()
    var key := InputEventKey.new()
    key.keycode = KEY_SPACE
    key.physical_keycode = KEY_SPACE
    key.pressed = true
    _main._unhandled_input(key)
    await get_tree().create_timer(0.15).timeout
    _check(_cookie.state != STATE_IDLE, "keyboard activation did not start the crack sequence")
    await get_tree().create_timer(2.0).timeout
    _check(_cookie.state == STATE_FORTUNE_DISPLAY, "keyboard-triggered sequence did not display")
    _check(_ui.session == 6, "keyboard activation did not increment the session counter")
    _cookie.request_reset()
    await get_tree().create_timer(0.8).timeout


func _has_non_ascii(text: String) -> bool:
    for index in range(text.length()):
        if text.unicode_at(index) > 127:
            return true
    return false


func _count_nodes(node: Node) -> int:
    var total := 1
    for child in node.get_children():
        total += _count_nodes(child)
    return total


func _cleanup() -> void:
    if _main != null:
        _main.queue_free()
        await get_tree().process_frame
    if FileAccess.file_exists(TEST_SETTINGS):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
    if FileAccess.file_exists(TEST_SETTINGS + ".corrupt"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS + ".corrupt"))
    SettingsManager.settings_path = _original_settings_path
    SettingsManager.language = str(_original_settings["language"])
    SettingsManager.sound_enabled = bool(_original_settings["sound"])
    SettingsManager.reduced_motion = bool(_original_settings["reduced_motion"])
    SettingsManager.low_effects = bool(_original_settings["low_effects"])
    LocalizationManager.set_language(str(_original_settings["language"]), false)
