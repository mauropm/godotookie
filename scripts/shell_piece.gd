extends Sprite2D
## One independently animated half of the fortune cookie shell.

var _tween: Tween
var _home := Vector2.ZERO


func _ready() -> void:
    _home = position
    centered = true


func crack(direction: int, delay: float, reduced: bool, low_effects: bool) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    z_index = 2 if direction > 0 else 1
    var distance := 72.0 if reduced else 155.0
    var lift := 24.0 if reduced else 96.0
    var fall := 70.0 if reduced else 215.0
    var spin := 0.18 if reduced else (0.65 + 0.18 * absf(float(direction)))
    _tween = create_tween()
    _tween.set_parallel(true)
    _tween.tween_property(self, "position", _home + Vector2(direction * distance * 0.55, -lift), 0.20 if reduced else 0.27) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
    _tween.tween_property(self, "rotation", direction * spin * 0.45, 0.20 if reduced else 0.27) \
        .set_trans(Tween.TRANS_SINE).set_delay(delay)
    _tween.chain().set_parallel(true)
    _tween.tween_property(self, "position", _home + Vector2(direction * distance, fall), 0.55 if reduced else 0.72) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _tween.tween_property(self, "rotation", direction * spin, 0.55 if reduced else 0.72)
    _tween.tween_property(self, "modulate:a", 0.0, 0.34 if reduced else 0.46).set_delay(0.16 if reduced else 0.24)
    _tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.55 if reduced else 0.72)
    if low_effects:
        _tween.set_speed_scale(1.08)
    _tween.chain().tween_callback(_hide_piece)


func _hide_piece() -> void:
    visible = false


func reset_piece() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    position = _home
    rotation = 0.0
    scale = Vector2.ONE
    modulate = Color.WHITE
    visible = true
    z_index = 0
