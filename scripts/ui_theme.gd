class_name FortuneTheme
extends RefCounted
## Central visual language for the game.

const CREAM := Color("#f8eedb")
const PARCHMENT := Color("#fff8e8")
const PARCHMENT_DEEP := Color("#f4e4c3")
const INK := Color("#4a3322")
const INK_SOFT := Color("#72563e")
const GOLD := Color("#c4893b")
const GOLD_DEEP := Color("#a66824")
const GOLD_PALE := Color("#e9c98d")
const HONEY := Color("#e0a94e")
const TERRACOTTA := Color("#a5522d")
const MUTED := Color("#9a7d5f")
const SHADOW := Color(0.225, 0.129, 0.067, 0.24)


static func build(font: Font) -> Theme:
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 18

    theme.set_color("font_color", "Label", INK)
    theme.set_color("font_shadow_color", "Label", Color(1, 1, 1, 0.25))
    theme.set_constant("shadow_offset_x", "Label", 0)
    theme.set_constant("shadow_offset_y", "Label", 1)
    theme.set_constant("line_spacing", "Label", 4)

    var normal := _button_box(PARCHMENT, GOLD_PALE, 22)
    var hover := _button_box(Color("#fffdf5"), GOLD, 22)
    var pressed := _button_box(Color("#f1ddb5"), GOLD_DEEP, 22)
    var disabled := _button_box(Color("#eee3cf"), Color("#d9cbb6"), 22)
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color(0, 0, 0, 0)
    focus.border_color = GOLD_DEEP
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(14)
    focus.content_margin_left = 4
    focus.content_margin_right = 4
    focus.content_margin_top = 4
    focus.content_margin_bottom = 4

    theme.set_stylebox("normal", "Button", normal)
    theme.set_stylebox("hover", "Button", hover)
    theme.set_stylebox("pressed", "Button", pressed)
    theme.set_stylebox("disabled", "Button", disabled)
    theme.set_stylebox("focus", "Button", focus)
    theme.set_color("font_color", "Button", INK)
    theme.set_color("font_hover_color", "Button", INK)
    theme.set_color("font_pressed_color", "Button", INK)
    theme.set_color("font_focus_color", "Button", INK)
    theme.set_color("font_disabled_color", "Button", MUTED)
    theme.set_color("icon_normal_color", "Button", GOLD_DEEP)
    theme.set_color("icon_hover_color", "Button", INK)
    theme.set_color("icon_pressed_color", "Button", INK)
    theme.set_constant("h_separation", "Button", 8)
    theme.set_font_size("font_size", "Button", 18)
    theme.set_constant("outline_size", "Button", 0)

    var panel := StyleBoxFlat.new()
    panel.bg_color = PARCHMENT
    panel.border_color = GOLD_PALE
    panel.set_border_width_all(1)
    panel.set_corner_radius_all(24)
    panel.shadow_color = SHADOW
    panel.shadow_size = 22
    panel.shadow_offset = Vector2(0, 10)
    panel.content_margin_left = 26
    panel.content_margin_right = 26
    panel.content_margin_top = 22
    panel.content_margin_bottom = 22
    theme.set_stylebox("panel", "PanelContainer", panel)

    var card := parchment_card_style()
    theme.set_stylebox("panel", "ParchmentCard", card)
    theme.set_type_variation("ParchmentCard", "PanelContainer")

    var chip := panel.duplicate() as StyleBoxFlat
    chip.bg_color = Color(0.267, 0.18, 0.11, 0.92)
    chip.border_color = Color(0.77, 0.55, 0.27, 0.5)
    chip.set_corner_radius_all(18)
    chip.shadow_size = 12
    chip.content_margin_left = 20
    chip.content_margin_right = 20
    chip.content_margin_top = 10
    chip.content_margin_bottom = 10
    theme.set_stylebox("panel", "ToastChip", chip)
    theme.set_type_variation("ToastChip", "PanelContainer")

    var edit := _button_box(Color("#fffaf0"), Color("#d7b376"), 22)
    var edit_focus := _button_box(Color("#fffdf7"), GOLD_DEEP, 22)
    theme.set_stylebox("normal", "LineEdit", edit)
    theme.set_stylebox("focus", "LineEdit", edit_focus)
    theme.set_stylebox("read_only", "LineEdit", disabled)
    theme.set_color("font_color", "LineEdit", INK)
    theme.set_color("font_placeholder_color", "LineEdit", MUTED)
    theme.set_color("caret_color", "LineEdit", GOLD_DEEP)
    theme.set_color("selection_color", "LineEdit", Color(0.77, 0.55, 0.27, 0.28))
    theme.set_font_size("font_size", "LineEdit", 17)
    theme.set_constant("minimum_character_width", "LineEdit", 8)

    theme.set_font_size("font_size", "CheckButton", 17)
    theme.set_color("font_color", "CheckButton", INK)
    theme.set_color("font_hover_color", "CheckButton", INK)
    theme.set_color("font_pressed_color", "CheckButton", INK)
    theme.set_color("font_focus_color", "CheckButton", INK)
    var empty := StyleBoxEmpty.new()
    var check_hover := StyleBoxFlat.new()
    check_hover.bg_color = Color(0.77, 0.55, 0.27, 0.07)
    check_hover.set_corner_radius_all(12)
    check_hover.content_margin_left = 6
    check_hover.content_margin_right = 6
    var check_focus := StyleBoxFlat.new()
    check_focus.bg_color = Color(0, 0, 0, 0)
    check_focus.border_color = Color(0.77, 0.55, 0.27, 0.55)
    check_focus.set_border_width_all(1)
    check_focus.set_corner_radius_all(12)
    theme.set_stylebox("normal", "CheckButton", empty)
    theme.set_stylebox("hover", "CheckButton", check_hover)
    theme.set_stylebox("pressed", "CheckButton", empty)
    theme.set_stylebox("hover_pressed", "CheckButton", check_hover)
    theme.set_stylebox("focus", "CheckButton", check_focus)
    theme.set_color("icon_normal_color", "CheckButton", GOLD_DEEP)
    theme.set_color("icon_hover_color", "CheckButton", GOLD)
    theme.set_color("icon_pressed_color", "CheckButton", GOLD_DEEP)

    theme.set_color("font_color", "RichTextLabel", INK)
    theme.set_font_size("normal_font_size", "RichTextLabel", 17)

    theme.set_stylebox("panel", "PopupPanel", panel)
    theme.set_stylebox("panel", "TooltipPanel", chip)
    theme.set_color("font_color", "TooltipLabel", Color("#fff7e6"))
    theme.set_font_size("font_size", "TooltipLabel", 15)

    return theme


static func parchment_card_style() -> StyleBoxFlat:
    var card := StyleBoxFlat.new()
    card.bg_color = Color("#fffaf0")
    card.border_color = Color("#d7b376")
    card.set_border_width_all(2)
    card.set_corner_radius_all(24)
    card.shadow_color = SHADOW
    card.shadow_size = 30
    card.shadow_offset = Vector2(0, 14)
    card.anti_aliasing = true
    return card


static func _button_box(background: Color, border: Color, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(radius)
    box.content_margin_left = 18
    box.content_margin_right = 18
    box.content_margin_top = 10
    box.content_margin_bottom = 10
    box.anti_aliasing = true
    return box
