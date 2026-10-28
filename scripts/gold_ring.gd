# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node2D
## Expanding golden ring used at the moment of the crack.

var _radius := 12.0
var _alpha := 0.0
var _tween: Tween


func _ready() -> void:
    z_index = 4
    visible = false


func burst(reduced := false) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    visible = not reduced
    if reduced:
        return
    _radius = 12.0
    _alpha = 0.62
    queue_redraw()
    _tween = create_tween().set_parallel(true)
    _tween.tween_method(_set_radius, 12.0, 220.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_method(_set_alpha, 0.62, 0.0, 0.72)
    _tween.chain().tween_callback(_finish)


func _set_radius(value: float) -> void:
    _radius = value
    queue_redraw()


func _set_alpha(value: float) -> void:
    _alpha = value
    queue_redraw()


func _finish() -> void:
    visible = false


func _draw() -> void:
    if _alpha <= 0.0:
        return
    draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 96, Color(1.0, 0.79, 0.34, _alpha * 0.8), 2.4, true)
    draw_arc(Vector2.ZERO, _radius * 0.94, 0.0, TAU, 96, Color(1.0, 0.94, 0.72, _alpha * 0.45), 1.1, true)
