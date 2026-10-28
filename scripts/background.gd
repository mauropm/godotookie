# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node2D
## Hand-drawn parchment scene background. Static; redraws only on resize.

const PAPER_TOP := Color("#fbf3e2")
const PAPER_BOTTOM := Color("#ead0a7")
const GOLD := Color("#c4893b")

var _size := Vector2(1280, 720)
var _specks: Array[Dictionary] = []


func _ready() -> void:
    z_index = -20
    var rng := RandomNumberGenerator.new()
    rng.seed = 381234
    for i in range(140):
        _specks.append({
            "p": Vector2(rng.randf(), rng.randf()),
            "l": rng.randf_range(0.4, 1.4),
            "a": rng.randf_range(0.018, 0.06),
            "r": rng.randf_range(-0.7, 0.7),
        })
    get_viewport().size_changed.connect(_on_resized)
    _on_resized()


func _on_resized() -> void:
    _size = get_viewport_rect().size
    queue_redraw()


func _draw() -> void:
    var width := maxf(_size.x, 1.0)
    var height := maxf(_size.y, 1.0)
    var bands := 72
    for i in range(bands):
        var t := float(i) / float(bands - 1)
        var color := PAPER_TOP.lerp(PAPER_BOTTOM, pow(t, 1.08))
        draw_rect(Rect2(0.0, height * t, width, height / float(bands) + 1.0), color)

    var center := Vector2(width * 0.5, height * 0.46)
    var glow_radius := minf(width, height) * 0.58
    for i in range(30):
        var t := float(i) / 29.0
        var radius := glow_radius * (1.0 - t * 0.72)
        draw_circle(center, radius, Color(1.0, 0.87, 0.58, 0.006 + t * 0.0035))

    # Faint concentric table setting behind the cookie.
    draw_arc(center, minf(width, height) * 0.31, 0.0, TAU, 160, Color(GOLD, 0.11), 1.3, true)
    draw_arc(center, minf(width, height) * 0.345, 0.0, TAU, 160, Color(GOLD, 0.065), 1.0, true)
    var dashes := 48
    for i in range(dashes):
        if i % 2 == 0:
            var angle := TAU * float(i) / float(dashes)
            var p1 := center + Vector2(cos(angle), sin(angle)) * minf(width, height) * 0.29
            var p2 := center + Vector2(cos(angle), sin(angle)) * minf(width, height) * 0.295
            draw_line(p1, p2, Color(GOLD, 0.14), 1.0)

    # Paper grain.
    for speck in _specks:
        var point := Vector2(float(speck["p"].x) * width, float(speck["p"].y) * height)
        var direction := Vector2(cos(float(speck["r"])), sin(float(speck["r"]))) * float(speck["l"])
        draw_line(point, point + direction, Color(0.38, 0.26, 0.14, float(speck["a"])), 1.0)

    # Fine border and corner flourishes.
    var inset := clampf(minf(width, height) * 0.022, 12.0, 30.0)
    var border := Color(GOLD, 0.22)
    draw_line(Vector2(inset, inset), Vector2(width - inset, inset), border, 1.0)
    draw_line(Vector2(width - inset, inset), Vector2(width - inset, height - inset), border, 1.0)
    draw_line(Vector2(width - inset, height - inset), Vector2(inset, height - inset), border, 1.0)
    draw_line(Vector2(inset, height - inset), Vector2(inset, inset), border, 1.0)
    var flourish := clampf(minf(width, height) * 0.055, 24.0, 70.0)
    var corner_color := Color(GOLD, 0.26)
    draw_arc(Vector2(inset, inset), flourish, 0.0, PI * 0.5, 24, corner_color, 1.2, true)
    draw_arc(Vector2(width - inset, inset), flourish, PI * 0.5, PI, 24, corner_color, 1.2, true)
    draw_arc(Vector2(width - inset, height - inset), flourish, PI, PI * 1.5, 24, corner_color, 1.2, true)
    draw_arc(Vector2(inset, height - inset), flourish, PI * 1.5, TAU, 24, corner_color, 1.2, true)

    # Delicate corner diamonds.
    for pos in [Vector2(inset, inset), Vector2(width - inset, inset), Vector2(width - inset, height - inset), Vector2(inset, height - inset)]:
        var diamond := PackedVector2Array([pos + Vector2(0, -5), pos + Vector2(5, 0), pos + Vector2(0, 5), pos + Vector2(-5, 0)])
        draw_colored_polygon(diamond, Color(GOLD, 0.28))
