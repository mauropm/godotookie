extends Node
## Coordinates shell pieces and one-shot effects. No nodes are created per crack.

@onready var _left: Sprite2D = get_parent().get_node("Visual/LeftPiece")
@onready var _right: Sprite2D = get_parent().get_node("Visual/RightPiece")
@onready var _effects: Node2D = get_parent().get_node("Effects")


func play_crack(reduced: bool, low_effects: bool) -> void:
    var base_delay := 0.0 if reduced else 0.025
    _left.crack(-1, 0.0, reduced, low_effects)
    _right.crack(1, base_delay, reduced, low_effects)
    _effects.burst(reduced, low_effects)


func reset() -> void:
    _left.reset_piece()
    _right.reset_piece()
    _effects.clear()
