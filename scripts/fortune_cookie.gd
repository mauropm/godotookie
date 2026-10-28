extends Node2D
## The flying cookie, its explicit state machine and orchestrated crack sequence.

signal state_changed(new_state: int, old_state: int)
signal crack_started
signal reveal_requested

enum State { IDLE, ANTICIPATION, CRACKING, FORTUNE_REVEAL, FORTUNE_DISPLAY, RESETTING }
const STATE_NAMES := {
    State.IDLE: "IDLE",
    State.ANTICIPATION: "ANTICIPATION",
    State.CRACKING: "CRACKING",
    State.FORTUNE_REVEAL: "FORTUNE_REVEAL",
    State.FORTUNE_DISPLAY: "FORTUNE_DISPLAY",
    State.RESETTING: "RESETTING",
}

var state: State = State.IDLE
var home_position := Vector2(640, 340)
var hovered := false
var reduced_motion := false
var low_effects := false

@onready var _visual: Node2D = $Visual
@onready var _shadow: Node2D = $Shadow
@onready var _glow: Node2D = $Glow
@onready var _hit_area: Area2D = $HitArea
@onready var _animation: Node = $AnimationController

var _idle_time := 0.0
var _sequence_running := false
var _last_crack_msec := -10000


func _ready() -> void:
    position = home_position
    _hit_area.input_event.connect(_on_hit_area_input_event)
    _hit_area.mouse_entered.connect(_on_hit_area_mouse_entered)
    _hit_area.mouse_exited.connect(_on_hit_area_mouse_exited)
    if SettingsManager != null:
        reduced_motion = SettingsManager.reduced_motion
        low_effects = SettingsManager.low_effects
        SettingsManager.changed.connect(_on_setting_changed)
    _glow.set_reduced(reduced_motion)


func _on_setting_changed(key: String, value: Variant) -> void:
    if key == "reduced_motion" and value is bool:
        reduced_motion = bool(value)
        _glow.set_reduced(reduced_motion)
        if state == State.IDLE:
            _reset_idle_transform()
    elif key == "low_effects" and value is bool:
        low_effects = bool(value)


func set_home_position(value: Vector2) -> void:
    home_position = value
    if state == State.IDLE:
        position = home_position


func request_crack() -> bool:
    var now := Time.get_ticks_msec()
    if state != State.IDLE or _sequence_running:
        return false
    if now - _last_crack_msec < 180:
        return false
    _last_crack_msec = now
    _sequence_running = true
    _set_hover(false)
    _hit_area.input_pickable = false
    _run_crack_sequence()
    return true


func request_reset() -> bool:
    if state != State.FORTUNE_DISPLAY or _sequence_running:
        return false
    _sequence_running = true
    _run_reset_sequence()
    return true


func _run_crack_sequence() -> void:
    _transition(State.ANTICIPATION)
    var anticipation_time := 0.10 if reduced_motion else 0.22
    var tween := create_tween()
    tween.tween_property(_visual, "scale", Vector2(0.91, 0.84), anticipation_time * 0.45) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    if not reduced_motion:
        tween.tween_property(_visual, "rotation", -0.055, anticipation_time * 0.18)
        tween.tween_property(_visual, "rotation", 0.052, anticipation_time * 0.18)
        tween.tween_property(_visual, "rotation", 0.0, anticipation_time * 0.1)
    tween.tween_property(_visual, "scale", Vector2.ONE, anticipation_time * 0.1)
    _shadow.strength = 1.24
    _shadow.queue_redraw()
    await tween.finished

    if not is_inside_tree():
        return
    _transition(State.CRACKING)
    AudioManager.play_crack()
    _animation.play_crack(reduced_motion, low_effects)
    crack_started.emit()

    await get_tree().create_timer(0.30 if reduced_motion else 0.58).timeout
    if not is_inside_tree():
        return
    _transition(State.FORTUNE_REVEAL)
    AudioManager.play_paper()
    reveal_requested.emit()

    await get_tree().create_timer(0.46 if reduced_motion else 0.90).timeout
    if not is_inside_tree():
        return
    AudioManager.play_chime()
    _transition(State.FORTUNE_DISPLAY)
    _sequence_running = false


func _run_reset_sequence() -> void:
    _transition(State.RESETTING)
    await get_tree().create_timer(0.18 if reduced_motion else 0.32).timeout
    if not is_inside_tree():
        return
    _animation.reset()
    _visual.scale = Vector2.ONE
    _visual.rotation = 0.0
    position = home_position
    _shadow.strength = 1.0
    _shadow.queue_redraw()
    _idle_time = 0.0
    _transition(State.IDLE)
    _hit_area.input_pickable = true
    _sequence_running = false


func _transition(next_state: State) -> bool:
    if not is_transition_allowed(state, next_state):
        push_error("Invalid cookie state transition %s -> %s" % [STATE_NAMES[state], STATE_NAMES[next_state]])
        return false
    var previous := state
    state = next_state
    state_changed.emit(state, previous)
    return true


static func is_transition_allowed(from_state: State, to_state: State) -> bool:
    match from_state:
        State.IDLE:
            return to_state == State.ANTICIPATION
        State.ANTICIPATION:
            return to_state == State.CRACKING
        State.CRACKING:
            return to_state == State.FORTUNE_REVEAL
        State.FORTUNE_REVEAL:
            return to_state == State.FORTUNE_DISPLAY
        State.FORTUNE_DISPLAY:
            return to_state == State.RESETTING
        State.RESETTING:
            return to_state == State.IDLE
    return false


func _process(delta: float) -> void:
    if state != State.IDLE:
        return
    _idle_time += delta
    var hover_scale := 0.018 if hovered else 0.0
    if reduced_motion:
        position = home_position
        rotation = 0.0
        _visual.scale = Vector2.ONE * (1.0 + hover_scale)
    else:
        var drift := 4.5
        var float_height := 9.0
        position = home_position + Vector2(
            sin(_idle_time * 0.52) * drift,
            sin(_idle_time * 1.18 + 0.4) * float_height
        )
        rotation = sin(_idle_time * 0.72) * 0.026
        _visual.scale = Vector2.ONE * (1.0 + sin(_idle_time * 1.45) * 0.007 + hover_scale)
    _shadow.strength = 1.0 + sin(_idle_time * 1.18 + 0.4) * 0.05
    _shadow.queue_redraw()


func _reset_idle_transform() -> void:
    position = home_position
    rotation = 0.0
    _visual.rotation = 0.0
    _visual.scale = Vector2.ONE


func _set_hover(value: bool) -> void:
    if hovered == value:
        return
    hovered = value and state == State.IDLE
    _glow.set_hover(hovered)
    Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_ARROW)


func _on_hit_area_mouse_entered() -> void:
    if state == State.IDLE:
        _set_hover(true)


func _on_hit_area_mouse_exited() -> void:
    _set_hover(false)


func _on_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if state != State.IDLE:
        return
    var pressed := false
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
    elif event is InputEventScreenTouch:
        pressed = (event as InputEventScreenTouch).pressed
    if pressed:
        get_viewport().set_input_as_handled()
        request_crack()


func state_name() -> String:
    return str(STATE_NAMES.get(state, "UNKNOWN"))
