extends Node2D
## Reusable, bounded crumb and sparkle burst plus the golden ring.

@onready var _crumbs: GPUParticles2D = $Crumbs
@onready var _sparkles: GPUParticles2D = $Sparkles
@onready var _ring: Node2D = $Ring


func _ready() -> void:
    _build_crumb_particles()
    _build_sparkle_particles()
    _crumbs.visible = false
    _sparkles.visible = false


func _build_crumb_particles() -> void:
    _crumbs.one_shot = true
    _crumbs.explosiveness = 1.0
    _crumbs.lifetime = 1.05
    _crumbs.amount = 54
    _crumbs.texture = load("res://assets/sprites/crumb.svg")
    _crumbs.local_coords = false
    _crumbs.emitting = false
    _crumbs.visibility_rect = Rect2(-260, -200, 680, 620)
    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = 54.0
    material.direction = Vector3(0, -1, 0)
    material.spread = 82.0
    material.initial_velocity_min = 105.0
    material.initial_velocity_max = 315.0
    material.gravity = Vector3(0, 760, 0)
    material.damping_min = 8.0
    material.damping_max = 28.0
    material.scale_min = 0.34
    material.scale_max = 1.18
    material.angular_velocity_min = -430.0
    material.angular_velocity_max = 430.0
    material.angle_min = -180.0
    material.angle_max = 180.0
    material.lifetime_randomness = 0.38
    material.color = Color("#f0c678")
    _crumbs.process_material = material


func _build_sparkle_particles() -> void:
    _sparkles.one_shot = true
    _sparkles.explosiveness = 0.92
    _sparkles.lifetime = 0.9
    _sparkles.amount = 26
    _sparkles.texture = load("res://assets/sprites/sparkle.svg")
    _sparkles.local_coords = false
    _sparkles.emitting = false
    _sparkles.visibility_rect = Rect2(-280, -240, 720, 680)
    var blend := CanvasItemMaterial.new()
    blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _sparkles.material = blend
    var material := ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = 40.0
    material.direction = Vector3(0, -1, 0)
    material.spread = 180.0
    material.initial_velocity_min = 40.0
    material.initial_velocity_max = 180.0
    material.gravity = Vector3(0, 55, 0)
    material.damping_min = 20.0
    material.damping_max = 50.0
    material.scale_min = 0.22
    material.scale_max = 0.76
    material.angular_velocity_min = -90.0
    material.angular_velocity_max = 90.0
    material.lifetime_randomness = 0.3
    material.color = Color(1.0, 0.86, 0.48, 0.92)
    _sparkles.process_material = material


func burst(reduced: bool, low_effects: bool) -> void:
    _ring.burst(reduced)
    if reduced:
        return
    _crumbs.amount = 20 if low_effects else 54
    _sparkles.amount = 8 if low_effects else 26
    _crumbs.visible = true
    _sparkles.visible = true
    _crumbs.restart()
    _crumbs.emitting = true
    _sparkles.restart()
    _sparkles.emitting = true


func clear() -> void:
    _crumbs.emitting = false
    _sparkles.emitting = false
    _crumbs.visible = false
    _sparkles.visible = false
    _ring.visible = false
