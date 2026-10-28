# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Control
## Accessible settings sheet for sound, motion and effects.

signal language_requested
signal closed

var _panel: PanelContainer
var _title: Label
var _close_button: Button
var _language_label: Label
var _language_button: Button
var _language_hint: Label
var _sound_check: CheckButton
var _sound_hint: Label
var _motion_check: CheckButton
var _motion_hint: Label
var _effects_check: CheckButton
var _effects_hint: Label
var _saved_label: Label
var _about_label: Label
var _refreshing := false


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()
    resized.connect(_layout)
    SettingsManager.changed.connect(_on_setting_changed)
    call_deferred("_layout")


func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.10, 0.06, 0.03, 0.46)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)

    _panel = PanelContainer.new()
    _panel.name = "SettingsCard"
    add_child(_panel)

    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _panel.add_child(scroll)

    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 13)
    scroll.add_child(box)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    box.add_child(header)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 28)
    _title.add_theme_color_override("font_color", FortuneTheme.INK)
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_title)
    _close_button = Button.new()
    _close_button.text = "×"
    _close_button.custom_minimum_size = Vector2(42, 42)
    _close_button.focus_mode = Control.FOCUS_ALL
    _close_button.add_theme_font_size_override("font_size", 24)
    _close_button.pressed.connect(close)
    header.add_child(_close_button)

    _language_label = _section_label()
    box.add_child(_language_label)
    _language_button = Button.new()
    _language_button.custom_minimum_size = Vector2(0, 48)
    _language_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _language_button.pressed.connect(func() -> void:
        AudioManager.play_click()
        language_requested.emit()
    )
    box.add_child(_language_button)
    _language_hint = _hint_label()
    box.add_child(_language_hint)

    _sound_check = _check()
    _sound_check.toggled.connect(_on_sound_toggled)
    box.add_child(_sound_check)
    _sound_hint = _hint_label()
    box.add_child(_sound_hint)

    _motion_check = _check()
    _motion_check.toggled.connect(_on_motion_toggled)
    box.add_child(_motion_check)
    _motion_hint = _hint_label()
    box.add_child(_motion_hint)

    _effects_check = _check()
    _effects_check.toggled.connect(_on_effects_toggled)
    box.add_child(_effects_check)
    _effects_hint = _hint_label()
    box.add_child(_effects_hint)

    var line := ColorRect.new()
    line.color = Color(FortuneTheme.GOLD_PALE, 0.55)
    line.custom_minimum_size = Vector2(0, 1)
    box.add_child(line)

    _saved_label = _hint_label()
    box.add_child(_saved_label)
    _about_label = _hint_label()
    _about_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_about_label)


func _section_label() -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", FortuneTheme.GOLD_DEEP)
    return label


func _hint_label() -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_color_override("font_color", FortuneTheme.MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label


func _check() -> CheckButton:
    var check := CheckButton.new()
    check.custom_minimum_size = Vector2(0, 34)
    check.focus_mode = Control.FOCUS_ALL
    check.add_theme_font_size_override("font_size", 17)
    return check


func _on_setting_changed(key: String, _value: Variant) -> void:
    if key in ["sound", "reduced_motion", "low_effects", "language"]:
        refresh()


func _on_sound_toggled(value: bool) -> void:
    if _refreshing:
        return
    AudioManager.play_click()
    SettingsManager.set_sound_enabled(value)


func _on_motion_toggled(value: bool) -> void:
    if _refreshing:
        return
    AudioManager.play_click()
    SettingsManager.set_reduced_motion(value)


func _on_effects_toggled(value: bool) -> void:
    if _refreshing:
        return
    AudioManager.play_click()
    SettingsManager.set_low_effects(value)


func open() -> void:
    visible = true
    refresh()
    _layout()
    _close_button.grab_focus()


func close() -> void:
    visible = false
    closed.emit()


func refresh() -> void:
    if _panel == null:
        return
    _refreshing = true
    _title.text = LocalizationManager.t("settings")
    _close_button.tooltip_text = LocalizationManager.t("close")
    _close_button.accessibility_name = LocalizationManager.t("close")
    _language_label.text = LocalizationManager.t("language").to_upper()
    var code := LocalizationManager.current_locale
    _language_button.text = "%s   ·   %s" % [
        LocalizationManager.native_name(code),
        LocalizationManager.t("change_language"),
    ]
    _language_button.tooltip_text = LocalizationManager.t("language_hint")
    _language_button.accessibility_name = LocalizationManager.t("change_language")
    _language_hint.text = LocalizationManager.t("language_hint")
    _sound_check.text = LocalizationManager.t("sound")
    _sound_check.button_pressed = SettingsManager.sound_enabled
    _sound_hint.text = LocalizationManager.t("sound_hint")
    _motion_check.text = LocalizationManager.t("reduced_motion")
    _motion_check.button_pressed = SettingsManager.reduced_motion
    _motion_hint.text = LocalizationManager.t("reduced_motion_hint")
    _effects_check.text = LocalizationManager.t("low_effects")
    _effects_check.button_pressed = SettingsManager.low_effects
    _effects_hint.text = LocalizationManager.t("low_effects_hint")
    _saved_label.text = LocalizationManager.t("settings_saved")
    _about_label.text = LocalizationManager.t("about_note")
    _refreshing = false


func _layout() -> void:
    if _panel == null or not is_inside_tree():
        return
    var size := get_viewport_rect().size
    var width := clampf(size.x - 44.0, 300.0, 540.0)
    var height := clampf(size.y - 46.0, 380.0, 630.0)
    _panel.size = Vector2(width, height)
    _panel.position = Vector2((size.x - width) * 0.5, (size.y - height) * 0.5)
