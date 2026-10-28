extends Node2D
## Soft multi-pass elliptical shadow under the cookie.

var strength := 1.0


func _ready() -> void:
    z_index = -3


func _draw() -> void:
    for i in range(14):
        var t := float(i) / 13.0
        var radius := lerpf(190.0, 52.0, t)
        var alpha := (0.008 + t * 0.0055) * strength
        draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.32))
        draw_circle(Vector2.ZERO, radius, Color(0.26, 0.14, 0.07, alpha))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
