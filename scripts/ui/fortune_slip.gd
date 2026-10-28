# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Control
## Animated parchment fortune slip with locale-aware typography and RTL support.

@onready var _card: Panel = $Card
@onready var _header: Label = $Card/VBox/Header/HeaderLabel
@onready var _header_mark: Label = $Card/VBox/Header/Mark
@onready var _divider: ColorRect = $Card/VBox/Divider
@onready var _fortune: Label = $Card/VBox/FortuneText
@onready var _footer: Label = $Card/VBox/Footer

var _text := ""
var _locale := "en"
var _revealed := false
var _tween: Tween


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_theme_stylebox_override("panel", FortuneTheme.parchment_card_style())
    resized.connect(_layout)
    _apply_typography()
    call_deferred("_layout")


func get_fortune_text() -> String:
    return _text


func is_showing() -> bool:
    return visible


func set_fortune(text: String, locale: String) -> void:
    _text = text
    _locale = locale
    _apply_typography()
    _fortune.text = text
    _layout()


func update_fortune(text: String, locale: String) -> void:
    set_fortune(text, locale)


func reveal(text: String, locale: String, reduced := false) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    visible = true
    set_fortune(text, locale)
    _layout()
    _revealed = true
    var center := _card.position + _card.size * 0.5
    _card.pivot_offset = _card.size * 0.5
    _card.modulate = Color(1, 1, 1, 0)
    _card.scale = Vector2(0.22, 0.07) if not reduced else Vector2(0.96, 0.96)
    _card.rotation = -0.045 if not reduced else 0.0
    _card.position = center - _card.size * 0.5 + Vector2(0, 58 if not reduced else 8)
    _fortune.modulate = Color(1, 1, 1, 0)
    _tween = create_tween()
    _tween.set_parallel(true)
    var duration := 0.22 if reduced else 0.62
    _tween.tween_property(_card, "modulate:a", 1.0, duration * 0.55)
    _tween.tween_property(_card, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(_card, "rotation", 0.0, duration).set_trans(Tween.TRANS_SINE)
    _tween.tween_property(_card, "position", center - _card.size * 0.5, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_property(_fortune, "modulate:a", 1.0, duration * 0.7).set_delay(duration * 0.25)


func hide_slip(reduced := false, instant := false) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _revealed = false
    if instant or not visible:
        visible = false
        return
    var start := _card.position
    _tween = create_tween().set_parallel(true)
    var duration := 0.12 if reduced else 0.26
    _tween.tween_property(_card, "modulate:a", 0.0, duration)
    _tween.tween_property(_card, "scale", Vector2(0.96, 0.94), duration)
    _tween.tween_property(_card, "position", start + Vector2(0, 20), duration)
    _tween.chain().tween_callback(func() -> void: visible = false)


func _layout() -> void:
    if not is_inside_tree():
        return
    var viewport_size := get_viewport_rect().size
    var width := clampf(viewport_size.x - (28.0 if viewport_size.x < 420.0 else 64.0), 270.0, 620.0)
    var height := clampf(viewport_size.y - (250.0 if viewport_size.y < 680.0 else 300.0), 300.0, 430.0)
    var center := Vector2(
        viewport_size.x * 0.5,
        viewport_size.y * (0.455 if viewport_size.x < viewport_size.y else 0.47)
    )
    _card.custom_minimum_size = Vector2.ZERO
    _card.size = Vector2(width, height)
    _card.position = center - _card.size * 0.5
    _card.pivot_offset = _card.size * 0.5
    _apply_typography()


func _apply_typography() -> void:
    if _card == null:
        return
    var font := LocalizationManager.fortune_font(_locale)
    var ui := LocalizationManager.ui_font(_locale)
    var rtl := LocalizationManager.is_rtl(_locale)
    _fortune.add_theme_font_override("font", font)
    _header.add_theme_font_override("font", ui)
    _footer.add_theme_font_override("font", ui)
    _header_mark.add_theme_font_override("font", ui)
    _fortune.add_theme_color_override("font_color", FortuneTheme.INK)
    _header.add_theme_color_override("font_color", FortuneTheme.GOLD_DEEP)
    _footer.add_theme_color_override("font_color", FortuneTheme.MUTED)
    _header_mark.add_theme_color_override("font_color", FortuneTheme.GOLD)
    _fortune.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
    _fortune.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_CENTER
    _fortune.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
    _header.text = LocalizationManager.t("your_fortune").to_upper()
    _footer.text = LocalizationManager.t("fortune_footer").to_upper()
    var group := LocalizationManager.font_group(_locale)
    var cjk := group.begins_with("cjk")
    var font_size := _fit_font_size(_text.length(), cjk)
    _fortune.add_theme_font_size_override("font_size", font_size)
    _fortune.add_theme_constant_override("line_spacing", 7)
    _header.add_theme_font_size_override("font_size", 13)
    _footer.add_theme_font_size_override("font_size", 11)
    _header_mark.add_theme_font_size_override("font_size", 14)


func _fit_font_size(length: int, cjk: bool) -> int:
    var card_width := _card.size.x if _card.size.x > 0.0 else 520.0
    var available_width := card_width - 72.0
    var available_height := (_card.size.y if _card.size.y > 0.0 else 380.0) - 148.0
    var width_factor := 1.0 if cjk else 0.56
    for candidate in [30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16]:
        var estimated_width := float(length) * float(candidate) * width_factor
        var lines := maxf(1.0, ceilf(estimated_width / maxf(available_width, 1.0)))
        var estimated_height := lines * float(candidate) * 1.34
        if estimated_height <= available_height:
            return candidate
    return 16
