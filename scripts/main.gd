# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node2D
## Main scene coordinator: input, layout, fortune lifecycle and preferences.

const STATE_IDLE := 0
const STATE_FORTUNE_REVEAL := 3
const STATE_FORTUNE_DISPLAY := 4

@onready var _background: Node2D = $Background
@onready var _sparkles: Node2D = $Sparkles
@onready var _cookie: Node2D = $CookieLayer/FortuneCookie
@onready var _ui: Control = $UI/GameUI

var _session := 0
var _current_text := ""
var _current_locale := "en"


func _ready() -> void:
    if OS.get_cmdline_args().has("--verify-content") or OS.get_cmdline_user_args().has("--verify-content"):
        _verify_exported_content()
        return
    _current_locale = LocalizationManager.current_locale
    _cookie.crack_started.connect(_on_crack_started)
    _cookie.reveal_requested.connect(_on_reveal_requested)
    _cookie.state_changed.connect(_on_cookie_state_changed)
    _ui.crack_requested.connect(_request_crack)
    _ui.another_requested.connect(_on_another_requested)
    _ui.copy_requested.connect(_copy_fortune)
    _ui.cookie_focus_changed.connect(_on_cookie_focus_changed)
    SettingsManager.changed.connect(_on_setting_changed)
    LocalizationManager.locale_changed.connect(_on_locale_changed)
    get_viewport().size_changed.connect(_layout_world)
    _apply_effects_preferences()
    _ui.set_session(_session)
    _ui.set_state(_cookie.state)
    _layout_world()


func _verify_exported_content() -> void:
    var total := 0
    var missing: Array[String] = []
    for meta in LocalizationManager.locales:
        var code := str(meta.get("code", ""))
        var count := FortuneManager.count_for(code)
        total += count
        if count < 2000:
            missing.append("%s=%d" % [code, count])
        if not FileAccess.file_exists("res://data/ui/%s.json" % code):
            missing.append("missing ui/%s.json" % code)
    print("EXPORT_CONTENT_TOTAL=%d" % total)
    print("EXPORT_CONTENT_MISSING=%s" % ",".join(missing))
    print("EXPORT_CONTENT_RESULT=%s" % ("PASS" if total >= 60000 and missing.is_empty() else "FAIL"))
    get_tree().quit(0 if total >= 60000 and missing.is_empty() else 1)


func _layout_world() -> void:
    var viewport_size := get_viewport_rect().size
    var scale_factor := clampf(minf(viewport_size.x / 1200.0, viewport_size.y / 700.0), 0.52, 1.15)
    if viewport_size.x < 350.0:
        scale_factor = minf(scale_factor, (viewport_size.x * 0.86) / 520.0)
    var home := Vector2(
        viewport_size.x * 0.5,
        viewport_size.y * (0.45 if viewport_size.x >= viewport_size.y else 0.42)
    )
    _cookie.scale = Vector2.ONE * scale_factor
    _cookie.set_home_position(home)
    _cookie.position = home
    _ui.set_cookie_hit_rect(home, 238.0 * scale_factor)


func _request_crack() -> void:
    if _ui.is_modal_open():
        return
    if _cookie.state != STATE_IDLE:
        return
    _cookie.request_crack()


func _on_crack_started() -> void:
    _session += 1
    _ui.set_session(_session)
    _current_locale = LocalizationManager.current_locale
    var fortune := FortuneManager.next_fortune(_current_locale)
    _current_text = str(fortune.get("text", ""))
    if _current_text.strip_edges().is_empty():
        _current_text = LocalizationManager.t("fallback_fortune")


func _on_reveal_requested() -> void:
    if _current_text.strip_edges().is_empty():
        var fortune := FortuneManager.next_fortune(LocalizationManager.current_locale)
        _current_text = str(fortune.get("text", LocalizationManager.t("fallback_fortune")))
        _current_locale = LocalizationManager.current_locale
    _ui.show_fortune(_current_text, _current_locale, true)


func _on_cookie_state_changed(new_state: int, old_state: int) -> void:
    _ui.set_state(new_state)
    if new_state == 5:
        _ui.hide_fortune(SettingsManager.reduced_motion)
    elif new_state == STATE_IDLE:
        _ui.hide_fortune(SettingsManager.reduced_motion, true)
    elif new_state == STATE_FORTUNE_DISPLAY:
        _ui.set_state(new_state)


func _on_another_requested() -> void:
    if _ui.is_modal_open():
        return
    if _cookie.state != STATE_FORTUNE_DISPLAY:
        return
    _ui.hide_fortune(SettingsManager.reduced_motion)
    _cookie.request_reset()


func _copy_fortune() -> void:
    if _current_text.strip_edges().is_empty():
        return
    if ClipboardService.copy_text(_current_text):
        _ui.show_toast(LocalizationManager.t("copied"))
    else:
        push_warning("Clipboard copy failed: %s" % ClipboardService.last_error)
        _ui.show_toast(LocalizationManager.t("copy_failed"))


func _on_cookie_focus_changed(focused: bool) -> void:
    _cookie.set("hovered", focused and _cookie.state == STATE_IDLE)
    var glow = _cookie.get_node_or_null("Glow")
    if glow != null:
        glow.set_hover(focused and _cookie.state == STATE_IDLE)


func _on_locale_changed(code: String) -> void:
    _current_locale = code
    _cookie.set("hovered", false)
    if _cookie.state in [STATE_FORTUNE_REVEAL, STATE_FORTUNE_DISPLAY] and not _current_text.is_empty():
        var fortune := FortuneManager.next_fortune(code)
        _current_text = str(fortune.get("text", LocalizationManager.t("fallback_fortune")))
        _ui.update_fortune(_current_text, code)
    _ui.set_session(_session)


func _on_setting_changed(key: String, _value: Variant) -> void:
    if key in ["reduced_motion", "low_effects"]:
        _apply_effects_preferences()


func _apply_effects_preferences() -> void:
    _sparkles.set_reduced(SettingsManager.reduced_motion)
    _sparkles.set_low_effects(SettingsManager.low_effects)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if _ui.is_modal_open():
            _ui.close_modals()
            get_viewport().set_input_as_handled()
        return
    if _ui.is_modal_open():
        return
    if event.is_action_pressed("ui_accept") and not event.is_echo():
        if get_viewport().gui_get_focus_owner() == null:
            if _cookie.state == STATE_IDLE:
                _request_crack()
                get_viewport().set_input_as_handled()
            elif _cookie.state == STATE_FORTUNE_DISPLAY:
                _on_another_requested()
                get_viewport().set_input_as_handled()
        return
    if event is InputEventKey:
        var key_event := event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.ctrl_pressed and key_event.keycode == KEY_C:
            if _cookie.state == STATE_FORTUNE_DISPLAY:
                _copy_fortune()
                get_viewport().set_input_as_handled()
