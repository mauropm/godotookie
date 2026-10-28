# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Control
## Responsive native UI: title, settings, language picker, slip and actions.

signal crack_requested
signal another_requested
signal copy_requested
signal cookie_focus_changed(focused: bool)

const SLIP_SCENE := preload("res://scenes/ui/fortune_slip.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const LANGUAGE_SCENE := preload("res://scenes/ui/language_selector.tscn")
const ICON_GLOBE := preload("res://assets/sprites/icon_globe.svg")
const ICON_SOUND_ON := preload("res://assets/sprites/icon_sound_on.svg")
const ICON_SOUND_OFF := preload("res://assets/sprites/icon_sound_off.svg")
const ICON_GEAR := preload("res://assets/sprites/icon_gear.svg")

const STATE_IDLE := 0
const STATE_ANTICIPATION := 1
const STATE_CRACKING := 2
const STATE_FORTUNE_REVEAL := 3
const STATE_FORTUNE_DISPLAY := 4
const STATE_RESETTING := 5

var slip: Control
var settings_panel: Control
var language_selector: Control
var current_text := ""
var current_locale := "en"
var session := 0
var state := STATE_IDLE
var reduced_motion := false

var _topbar: HBoxContainer
var _title_box: VBoxContainer
var _title: Label
var _mark: Label
var _subtitle: Label
var _session_label: Label
var _language_button: Button
var _sound_button: Button
var _settings_button: Button
var _bottom: Control
var _actions: HFlowContainer
var _another_button: Button
var _copy_button: Button
var _hint: Label
var _keyboard_hint: Label
var _cookie_access: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _toast_height := 42.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    current_locale = LocalizationManager.current_locale
    _shell_controls()
    _apply_theme()
    _build_topbar()
    _build_bottom()
    _build_cookie_access()
    _build_toast()
    _instantiate_panels()
    _connect_world()
    _refresh_texts()
    _refresh_state()
    _layout()
    resized.connect(_layout)


func _shell_controls() -> void:
    slip = SLIP_SCENE.instantiate()
    slip.name = "FortuneSlip"
    add_child(slip)


func _instantiate_panels() -> void:
    settings_panel = SETTINGS_SCENE.instantiate()
    settings_panel.name = "SettingsPanel"
    add_child(settings_panel)
    settings_panel.language_requested.connect(open_language_selector)

    language_selector = LANGUAGE_SCENE.instantiate()
    language_selector.name = "LanguageSelector"
    add_child(language_selector)
    language_selector.closed.connect(func() -> void:
        if settings_panel != null and settings_panel.visible:
            settings_panel._close_button.grab_focus()
    )


func _connect_world() -> void:
    LocalizationManager.locale_changed.connect(_on_locale_changed)
    SettingsManager.changed.connect(_on_setting_changed)


func _apply_theme() -> void:
    theme = FortuneTheme.build(LocalizationManager.ui_font())
    reduced_motion = SettingsManager.reduced_motion


func _build_topbar() -> void:
    _topbar = HBoxContainer.new()
    _topbar.add_theme_constant_override("separation", 8)
    add_child(_topbar)

    _title_box = VBoxContainer.new()
    _title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _title_box.add_theme_constant_override("separation", -2)
    _topbar.add_child(_title_box)

    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 8)
    _title_box.add_child(title_row)
    _mark = Label.new()
    _mark.text = "✦"
    _mark.add_theme_color_override("font_color", FortuneTheme.GOLD)
    _mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    title_row.add_child(_mark)
    _title = Label.new()
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _title.clip_text = true
    _title.add_theme_color_override("font_color", FortuneTheme.INK)
    _title.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.4))
    _title.add_theme_constant_override("shadow_offset_y", 1)
    title_row.add_child(_title)

    _subtitle = Label.new()
    _subtitle.add_theme_color_override("font_color", FortuneTheme.GOLD_DEEP)
    _subtitle.add_theme_font_size_override("font_size", 14)
    _title_box.add_child(_subtitle)

    _session_label = Label.new()
    _session_label.add_theme_color_override("font_color", FortuneTheme.MUTED)
    _session_label.add_theme_font_size_override("font_size", 12)
    _title_box.add_child(_session_label)

    _language_button = _make_compact_button(74)
    _language_button.icon = ICON_GLOBE
    _language_button.text = "EN"
    _language_button.add_theme_font_size_override("font_size", 13)
    _language_button.pressed.connect(open_language_selector)
    _topbar.add_child(_language_button)

    _sound_button = _make_compact_button(48)
    _sound_button.pressed.connect(_on_sound_pressed)
    _topbar.add_child(_sound_button)

    _settings_button = _make_compact_button(48)
    _settings_button.icon = ICON_GEAR
    _settings_button.pressed.connect(open_settings)
    _topbar.add_child(_settings_button)


func _make_compact_button(min_width: float) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(min_width, 48)
    button.expand_icon = true
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var normal := _compact_box(FortuneTheme.PARCHMENT, FortuneTheme.GOLD_PALE)
    var hover := _compact_box(Color("#fffdf5"), FortuneTheme.GOLD)
    var pressed := _compact_box(Color("#f1ddb5"), FortuneTheme.GOLD_DEEP)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", hover)
    return button


func _compact_box(background: Color, border: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(24)
    box.content_margin_left = 6
    box.content_margin_right = 6
    box.content_margin_top = 6
    box.content_margin_bottom = 6
    return box


func _build_bottom() -> void:
    _bottom = Control.new()
    _bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_bottom)

    _actions = HFlowContainer.new()
    _actions.alignment = FlowContainer.ALIGNMENT_CENTER
    _actions.add_theme_constant_override("h_separation", 10)
    _actions.add_theme_constant_override("v_separation", 8)
    _actions.visible = false
    _bottom.add_child(_actions)

    _another_button = Button.new()
    _another_button.custom_minimum_size = Vector2(0, 46)
    _another_button.focus_mode = Control.FOCUS_ALL
    _another_button.pressed.connect(func() -> void:
        AudioManager.play_click()
        another_requested.emit()
    )
    _actions.add_child(_another_button)

    _copy_button = Button.new()
    _copy_button.custom_minimum_size = Vector2(0, 46)
    _copy_button.focus_mode = Control.FOCUS_ALL
    _copy_button.pressed.connect(func() -> void:
        AudioManager.play_click()
        copy_requested.emit()
    )
    _actions.add_child(_copy_button)

    _hint = Label.new()
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint.add_theme_color_override("font_color", FortuneTheme.INK_SOFT)
    _hint.add_theme_font_size_override("font_size", 16)
    _hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _bottom.add_child(_hint)

    _keyboard_hint = Label.new()
    _keyboard_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _keyboard_hint.add_theme_color_override("font_color", FortuneTheme.MUTED)
    _keyboard_hint.add_theme_font_size_override("font_size", 12)
    _keyboard_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _bottom.add_child(_keyboard_hint)


func _build_cookie_access() -> void:
    _cookie_access = Button.new()
    _cookie_access.name = "CookieAccessibilityButton"
    _cookie_access.flat = true
    _cookie_access.text = ""
    _cookie_access.focus_mode = Control.FOCUS_ALL
    _cookie_access.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cookie_access.pressed.connect(func() -> void: crack_requested.emit())
    _cookie_access.focus_entered.connect(func() -> void: cookie_focus_changed.emit(true))
    _cookie_access.focus_exited.connect(func() -> void: cookie_focus_changed.emit(false))
    var focus_box := StyleBoxFlat.new()
    focus_box.bg_color = Color(1, 1, 1, 0.0)
    focus_box.border_color = Color(FortuneTheme.GOLD, 0.65)
    focus_box.set_border_width_all(2)
    focus_box.set_corner_radius_all(28)
    _cookie_access.add_theme_stylebox_override("focus", focus_box)
    add_child(_cookie_access)


func _build_toast() -> void:
    _toast = PanelContainer.new()
    _toast.theme_type_variation = &"ToastChip"
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast.visible = false
    add_child(_toast)
    _toast_label = Label.new()
    _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _toast_label.add_theme_color_override("font_color", Color("#fff7e6"))
    _toast_label.add_theme_font_size_override("font_size", 14)
    _toast.add_child(_toast_label)


func _on_locale_changed(_code: String) -> void:
    current_locale = LocalizationManager.current_locale
    _apply_theme()
    _refresh_texts()
    _layout()
    if not current_text.is_empty():
        slip.set_fortune(current_text, current_locale)


func _on_setting_changed(key: String, _value: Variant) -> void:
    if key == "sound":
        _refresh_sound_button()
    elif key == "reduced_motion":
        reduced_motion = SettingsManager.reduced_motion


func _refresh_texts() -> void:
    _title.text = LocalizationManager.t("app_title")
    _subtitle.text = LocalizationManager.t("app_subtitle")
    _mark.tooltip_text = ""
    _language_button.tooltip_text = LocalizationManager.t("change_language")
    _language_button.accessibility_name = LocalizationManager.t("change_language")
    _sound_button.tooltip_text = LocalizationManager.t("toggle_sound")
    _sound_button.accessibility_name = LocalizationManager.t("toggle_sound")
    _settings_button.tooltip_text = LocalizationManager.t("open_settings")
    _settings_button.accessibility_name = LocalizationManager.t("open_settings")
    _another_button.text = LocalizationManager.t("another_cookie")
    _another_button.accessibility_name = LocalizationManager.t("another_cookie")
    _copy_button.text = LocalizationManager.t("copy_fortune")
    _copy_button.accessibility_name = LocalizationManager.t("copy_fortune")
    _hint.text = LocalizationManager.t("tap_hint")
    _keyboard_hint.text = LocalizationManager.t("keyboard_hint")
    _cookie_access.accessibility_name = LocalizationManager.t("tap_hint")
    _cookie_access.tooltip_text = LocalizationManager.t("tap_hint")
    _language_button.text = current_locale.to_upper()
    _refresh_sound_button()
    _refresh_session()
    if settings_panel != null:
        settings_panel.refresh()
    if language_selector != null:
        language_selector.refresh()
    LocalizationManager.apply_direction(self)


func _refresh_sound_button() -> void:
    if _sound_button == null:
        return
    _sound_button.icon = ICON_SOUND_ON if SettingsManager.sound_enabled else ICON_SOUND_OFF
    _sound_button.modulate = Color.WHITE if SettingsManager.sound_enabled else Color(1, 1, 1, 0.62)
    var label := LocalizationManager.t("sound_on") if SettingsManager.sound_enabled else LocalizationManager.t("sound_off")
    _sound_button.tooltip_text = label
    _sound_button.accessibility_name = label


func _refresh_session() -> void:
    _session_label.text = "" if session <= 0 else "%s %d" % [LocalizationManager.t("session_counter"), session]


func _on_sound_pressed() -> void:
    AudioManager.play_click()
    SettingsManager.set_sound_enabled(not SettingsManager.sound_enabled)


func open_settings() -> void:
    AudioManager.play_click()
    settings_panel.open()


func open_language_selector() -> void:
    AudioManager.play_click()
    language_selector.open()


func close_modals() -> void:
    if language_selector != null and language_selector.visible:
        language_selector.close()
    if settings_panel != null and settings_panel.visible:
        settings_panel.close()


func is_modal_open() -> bool:
    return (settings_panel != null and settings_panel.visible) or (language_selector != null and language_selector.visible)


func set_state(value: int) -> void:
    state = value
    _refresh_state()


func _refresh_state() -> void:
    if _actions == null:
        return
    var idle := state == STATE_IDLE
    var displaying := state == STATE_FORTUNE_DISPLAY
    _cookie_access.visible = idle
    _cookie_access.disabled = not idle
    _actions.visible = displaying
    _hint.visible = idle
    _keyboard_hint.visible = idle and get_viewport_rect().size.x >= 560.0
    if idle:
        _hint.text = LocalizationManager.t("tap_hint")
        _keyboard_hint.text = LocalizationManager.t("keyboard_hint")
    _refresh_session()


func set_session(value: int) -> void:
    session = value
    _refresh_session()


func set_cookie_hit_rect(center: Vector2, radius: float) -> void:
    if _cookie_access == null:
        return
    var side := radius * 2.0
    _cookie_access.position = center - Vector2(side, side) * 0.5
    _cookie_access.size = Vector2(side, side)
    _cookie_access.pivot_offset = Vector2(side, side) * 0.5


func show_fortune(text: String, locale: String, animate := true) -> void:
    current_text = text
    current_locale = locale
    if animate:
        slip.reveal(text, locale, reduced_motion)
    else:
        slip.set_fortune(text, locale)


func update_fortune(text: String, locale: String) -> void:
    current_text = text
    current_locale = locale
    slip.update_fortune(text, locale)


func hide_fortune(reduced := false, instant := false) -> void:
    current_text = ""
    slip.hide_slip(reduced, instant)


func show_toast(message: String, duration := 2.2) -> void:
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    _toast_label.text = message
    var viewport_width := get_viewport_rect().size.x
    _toast_label.custom_minimum_size.x = clampf(viewport_width - 140.0, 160.0, 460.0)
    _toast.reset_size()
    _toast.size = _toast.get_combined_minimum_size()
    _toast_height = _toast.size.y
    _position_toast()
    _toast.visible = true
    _toast.modulate.a = 0.0
    _toast_tween = create_tween()
    _toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.16)
    _toast_tween.tween_interval(duration)
    _toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.28)
    _toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _layout() -> void:
    if _topbar == null or not is_inside_tree():
        return
    var viewport_size := get_viewport_rect().size
    var width := viewport_size.x
    var height := viewport_size.y
    var margin := 20.0 if width >= 600.0 else 9.0
    var compact := width < 480.0
    _topbar.position = Vector2(margin, margin)
    _topbar.size = Vector2(width - margin * 2.0, 66.0 if not compact else 58.0)
    _title.add_theme_font_override("font", LocalizationManager.title_font())
    _title.add_theme_font_size_override("font_size", 36 if width > 1100.0 else 30 if width > 700.0 else 25 if width > 480.0 else 20 if width > 360.0 else 18)
    _mark.visible = width >= 370.0
    _mark.add_theme_font_size_override("font_size", 22 if width > 480.0 else 17)
    _subtitle.visible = width >= 720.0
    _session_label.visible = width >= 520.0
    _subtitle.text = LocalizationManager.t("app_subtitle")
    _language_button.text = "" if width < 430.0 else current_locale.to_upper()
    _language_button.custom_minimum_size.x = 48.0 if width < 430.0 else 74.0

    var bottom_height := 120.0 if not compact else 104.0
    var bottom_width := width - margin * 2.0
    var bottom_margin := 16.0 if compact else margin
    _bottom.position = Vector2(margin, height - bottom_height - bottom_margin)
    _bottom.size = Vector2(bottom_width, bottom_height)
    _keyboard_hint.visible = state == STATE_IDLE and width >= 560.0 and height >= 620.0
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
    if compact:
        _hint.add_theme_font_size_override("font_size", 15)
        var hint_height := 60.0
        _hint.position = Vector2(0, bottom_height - hint_height)
        _hint.size = Vector2(bottom_width, hint_height)
    else:
        _hint.add_theme_font_size_override("font_size", 16)
        var hint_height := 24.0
        var hint_y := bottom_height - (58.0 if _keyboard_hint.visible else 34.0)
        _hint.position = Vector2(0, hint_y)
        _hint.size = Vector2(bottom_width, hint_height)
    _keyboard_hint.position = Vector2(0, bottom_height - 20.0)
    _keyboard_hint.size = Vector2(bottom_width, 18.0)
    var action_height := 100.0 if width < 380.0 else 46.0
    _actions.size = Vector2(bottom_width, action_height)
    _actions.position = Vector2(0, bottom_height - action_height)
    _actions.size = Vector2(bottom_width, action_height)
    if width < 380.0:
        _sound_button.custom_minimum_size.x = 44.0
        _settings_button.custom_minimum_size.x = 44.0
        _language_button.custom_minimum_size.x = 44.0
    _position_toast()
    if settings_panel != null and settings_panel.visible:
        settings_panel._layout()
    if language_selector != null and language_selector.visible:
        language_selector._layout()


func _position_toast() -> void:
    if _toast == null or not _toast.visible:
        return
    var viewport_size := get_viewport_rect().size
    _toast.position = Vector2((viewport_size.x - _toast.size.x) * 0.5, viewport_size.y - 166.0 - _toast.size.y)
