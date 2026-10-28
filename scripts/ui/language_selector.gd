# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Control
## Searchable, flag-labelled language picker with keyboard support.

signal closed

var _panel: PanelContainer
var _title: Label
var _close_button: Button
var _search: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Label
var _rows: Array[Dictionary] = []
var _refreshing := false


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()
    resized.connect(_layout)
    LocalizationManager.locale_changed.connect(func(_code: String) -> void: refresh())
    call_deferred("_layout")


func _build() -> void:
    var dim := ColorRect.new()
    dim.color = Color(0.10, 0.06, 0.03, 0.52)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)

    _panel = PanelContainer.new()
    _panel.name = "LanguageCard"
    add_child(_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    _panel.add_child(box)

    var header := HBoxContainer.new()
    box.add_child(header)
    _title = Label.new()
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title.add_theme_font_size_override("font_size", 26)
    _title.add_theme_color_override("font_color", FortuneTheme.INK)
    header.add_child(_title)
    _close_button = Button.new()
    _close_button.text = "×"
    _close_button.custom_minimum_size = Vector2(42, 42)
    _close_button.add_theme_font_size_override("font_size", 24)
    _close_button.pressed.connect(close)
    header.add_child(_close_button)

    _search = LineEdit.new()
    _search.custom_minimum_size = Vector2(0, 48)
    _search.clear_button_enabled = true
    _search.text_changed.connect(_filter)
    _search.text_submitted.connect(func(_text: String) -> void: _focus_first())
    _search.gui_input.connect(_on_search_gui_input)
    box.add_child(_search)

    _scroll = ScrollContainer.new()
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(_scroll)
    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 6)
    _scroll.add_child(_list)

    _empty = Label.new()
    _empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _empty.add_theme_color_override("font_color", FortuneTheme.MUTED)
    _empty.visible = false
    box.add_child(_empty)

    for meta in LocalizationManager.locales:
        if not meta is Dictionary:
            continue
        var code := str(meta.get("code", ""))
        if code.is_empty():
            continue
        var row := Button.new()
        row.custom_minimum_size = Vector2(0, 48)
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.autowrap_mode = TextServer.AUTOWRAP_OFF
        row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row.clip_text = true
        row.focus_mode = Control.FOCUS_ALL
        row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        row.set_meta("bidi_auto", true)
        row.add_theme_font_size_override("font_size", 17)
        row.pressed.connect(_select.bind(code))
        row.focus_entered.connect(_scroll_to_row.bind(row))
        _list.add_child(row)
        var data := {"code": code, "button": row, "meta": meta}
        _rows.append(data)


func _scroll_to_row(row: Button) -> void:
    if _scroll != null:
        _scroll.ensure_control_visible(row)


func open() -> void:
    visible = true
    _search.text = ""
    _filter("")
    refresh()
    _layout()
    _search.grab_focus()


func close() -> void:
    visible = false
    closed.emit()


func refresh() -> void:
    if _panel == null:
        return
    _refreshing = true
    _title.text = LocalizationManager.t("language")
    _search.placeholder_text = LocalizationManager.t("search_languages")
    _search.accessibility_name = LocalizationManager.t("search_languages")
    _search.tooltip_text = LocalizationManager.t("search_languages")
    _close_button.tooltip_text = LocalizationManager.t("close")
    _close_button.accessibility_name = LocalizationManager.t("close")
    _empty.text = LocalizationManager.t("no_results")
    for entry in _rows:
        var code := str(entry["code"])
        var meta: Dictionary = entry["meta"]
        var row: Button = entry["button"]
        var flag := str(meta.get("flag", "🌐"))
        var native := str(meta.get("native_name", code))
        var english := str(meta.get("english_name", code))
        var selected := LocalizationManager.current_locale == code
        var label := "%s   %s  ·  %s" % [flag, native, english]
        if selected:
            label = "%s   %s  ·  %s   ✓" % [flag, native, english]
        row.text = label
        row.tooltip_text = "%s — %s" % [native, english]
        row.accessibility_name = "%s: %s, %s" % [LocalizationManager.t("language"), native, english]
        row.add_theme_font_override("font", LocalizationManager.ui_font(code))
        row.add_theme_color_override("font_color", FortuneTheme.GOLD_DEEP if selected else FortuneTheme.INK)
        row.add_theme_color_override("font_hover_color", FortuneTheme.INK)
        row.add_theme_color_override("font_pressed_color", FortuneTheme.INK)
        row.add_theme_color_override("font_focus_color", FortuneTheme.INK)
    _refreshing = false


func _filter(query: String) -> void:
    var needle := query.strip_edges().to_lower()
    var shown := 0
    for entry in _rows:
        var row: Button = entry["button"]
        var meta: Dictionary = entry["meta"]
        var haystack := "%s %s %s" % [
            str(meta.get("native_name", "")),
            str(meta.get("english_name", "")),
            str(entry["code"]),
        ]
        var matches := needle.is_empty() or haystack.to_lower().contains(needle)
        row.visible = matches
        if matches:
            shown += 1
    _empty.visible = shown == 0


func _on_search_gui_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_down"):
        _focus_first()
        get_viewport().set_input_as_handled()


func _focus_first() -> void:
    for entry in _rows:
        var row: Button = entry["button"]
        if row.visible:
            row.grab_focus()
            return


func _select(code: String) -> void:
    AudioManager.play_click()
    LocalizationManager.set_language(code, true)
    close()


func _layout() -> void:
    if _panel == null or not is_inside_tree():
        return
    var size := get_viewport_rect().size
    var width := clampf(size.x - 36.0, 290.0, 640.0)
    var height := clampf(size.y - 48.0, 380.0, 650.0)
    _panel.size = Vector2(width, height)
    _panel.position = Vector2((size.x - width) * 0.5, (size.y - height) * 0.5)
