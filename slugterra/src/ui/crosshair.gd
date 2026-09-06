class_name Crosshair
extends Control
## A dot while exploring, a reticle while aiming. Drawn rather than textured so
## the greybox build needs no art and the shape stays crisp at any resolution.

@export var color := Color(0.92, 0.96, 1.0, 0.85)
@export var aim_color := Color(0.24, 0.90, 1.0, 0.95)
@export var dot_radius := 2.0
@export var reticle_radius := 11.0
@export var tick_length := 7.0
@export var thickness := 2.0

var _aiming := false
## 0 = explore dot, 1 = full aim reticle.
var _blend := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_aiming(aiming: bool) -> void:
	if _aiming == aiming:
		return
	_aiming = aiming
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if _aiming else 0.0
	_blend = move_toward(_blend, target, delta * 6.0)
	queue_redraw()
	if is_equal_approx(_blend, target):
		set_process(false)


func _draw() -> void:
	var centre := size * 0.5
	var tint := color.lerp(aim_color, _blend)

	draw_circle(centre, dot_radius, tint)

	if _blend <= 0.01:
		return

	var radius := lerpf(dot_radius, reticle_radius, _blend)
	var tick := tick_length * _blend
	var faded := Color(tint.r, tint.g, tint.b, tint.a * _blend)

	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(
			centre + direction * radius,
			centre + direction * (radius + tick),
			faded,
			thickness
		)
