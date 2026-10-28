extends Node2D
## Restrained golden aura behind the cookie.

var hovered := false
var _time := 0.0
var _reduced := false


func _ready() -> void:
    z_index = -4


func set_hover(value: bool) -> void:
    hovered = value


func set_reduced(value: bool) -> void:
    _reduced = value
    if _reduced:
        queue_redraw()


func _process(delta: float) -> void:
    _time += delta
    if not _reduced:
        queue_redraw()


func _draw() -> void:
    var pulse := 0.5 + 0.5 * sin(_time * 1.05)
    var target := 0.34 if hovered else 0.15
    var strength := target + pulse * (0.03 if hovered else 0.025)
    for i in range(22):
        var t := float(i) / 21.0
        var radius := lerpf(300.0, 95.0, t)
        draw_circle(Vector2.ZERO, radius, Color(1.0, 0.82, 0.43, 0.0028 * strength * (0.4 + t * 0.9)))
