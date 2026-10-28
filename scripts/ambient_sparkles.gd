# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node2D
## Small deterministic ambient sparkles. Node count is fixed.

const GOLD := Color("#d9a344")

var _sparkles: Array[Dictionary] = []
var _time := 0.0
var _center := Vector2(640, 340)
var _radius := 260.0
var _active := true
var _low := false
var _reduced := false


func _ready() -> void:
    z_index = -8
    var rng := RandomNumberGenerator.new()
    rng.seed = 97531
    for i in range(14):
        var angle := rng.randf_range(0.0, TAU)
        var distance := rng.randf_range(0.55, 1.0)
        _sparkles.append({
            "ox": cos(angle) * distance,
            "oy": sin(angle) * distance * 0.72,
            "phase": rng.randf_range(0.0, TAU),
            "speed": rng.randf_range(0.45, 1.05),
            "size": rng.randf_range(1.6, 4.6),
            "alpha": rng.randf_range(0.22, 0.62),
        })
    get_viewport().size_changed.connect(_layout)
    _layout()


func _layout() -> void:
    var size := get_viewport_rect().size
    _center = Vector2(size.x * 0.5, size.y * 0.46)
    _radius = minf(size.x, size.y) * 0.36
    queue_redraw()


func set_reduced(reduced: bool) -> void:
    _reduced = reduced
    _update_state()


func set_low_effects(low: bool) -> void:
    _low = low
    _update_state()


func _update_state() -> void:
    _active = not _reduced
    set_process(_active)
    queue_redraw()


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    if not _active:
        return
    var count := 6 if _low else _sparkles.size()
    for i in range(count):
        var sparkle: Dictionary = _sparkles[i]
        var pulse := 0.5 + 0.5 * sin(_time * float(sparkle["speed"]) + float(sparkle["phase"]))
        var alpha := float(sparkle["alpha"]) * (0.25 + pulse * 0.75)
        var size := float(sparkle["size"]) * (0.65 + pulse * 0.5)
        var pos := _center + Vector2(float(sparkle["ox"]) * _radius, float(sparkle["oy"]) * _radius)
        pos += Vector2(sin(_time * 0.22 + float(sparkle["phase"])) * 4.0, cos(_time * 0.18 + float(sparkle["phase"])) * 3.0)
        var color := Color(GOLD, alpha)
        draw_line(pos + Vector2(-size, 0), pos + Vector2(size, 0), color, 1.0, true)
        draw_line(pos + Vector2(0, -size), pos + Vector2(0, size), color, 1.0, true)
        draw_circle(pos, size * 0.28, Color(1.0, 0.95, 0.75, alpha * 0.9))
