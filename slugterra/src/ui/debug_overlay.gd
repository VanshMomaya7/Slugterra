class_name DebugOverlay
extends Control
## F3 readout. Exists from M0 because the design doc's performance budget is a
## hard target, and a budget you cannot see is a budget you will miss.

@export var text_color := Color(0.82, 0.92, 1.0, 0.95)
@export var warn_color := Color(1.0, 0.72, 0.25, 0.95)
@export var background := Color(0.02, 0.03, 0.05, 0.62)
@export var font_size := 13
@export var start_visible := false

## From the design doc's budget: 16.6 ms total.
const FRAME_BUDGET_MS := 16.6

var player: Node
var blaster: Object

var _shown := false
var _lines: PackedStringArray = []
var _accumulator := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown = start_visible
	visible = _shown


func _unhandled_input(event: InputEvent) -> void:
	if not PlayerInput.has(PlayerInput.DEBUG_OVERLAY):
		return
	if event.is_action_pressed(PlayerInput.DEBUG_OVERLAY):
		_shown = not _shown
		visible = _shown
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _shown:
		return
	_accumulator += delta
	if _accumulator < 0.2:
		return
	_accumulator = 0.0
	_rebuild()
	queue_redraw()


func _rebuild() -> void:
	_lines.clear()

	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 1.0)
	_lines.append("fps %d   frame %.1f ms / %.1f budget" % [fps, frame_ms, FRAME_BUDGET_MS])
	_lines.append(
		"process %.2f ms   physics %.2f ms"
		% [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		]
	)
	_lines.append(
		"draw calls %d   prims %d   objects %d"
		% [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		]
	)

	if player != null:
		var state: Variant = player.get(&"state")
		if state != null:
			_lines.append("state %s" % PlayerStates.to_name(int(state)))
		var body := player as CharacterBody3D
		if body != null:
			var planar := Vector2(body.velocity.x, body.velocity.z).length()
			_lines.append(
				"speed %.2f m/s   y %.2f   floor %s"
				% [planar, body.velocity.y, str(body.is_on_floor())]
			)
			_lines.append(
				"pos %.1f, %.1f, %.1f"
				% [body.global_position.x, body.global_position.y, body.global_position.z]
			)

	if blaster != null and blaster.has_method("is_charging"):
		var charging := bool(blaster.call("is_charging"))
		var charge := float(blaster.call("get_charge"))
		var speed := float(blaster.call("get_projected_speed"))
		var threshold := float(blaster.call("get_threshold"))
		_lines.append(
			"charge %.2f   %.1f m/s (%d mph)   thr %.1f"
			% [charge, speed, roundi(ChargeConfig.mps_to_mph(speed)), threshold]
			+ ("   CHARGING" if charging else "")
		)
		_lines.append("notch at %.3f" % float(blaster.call("get_threshold_marker")))

	var time_controller := get_node_or_null(^"/root/TimeController")
	if time_controller != null:
		var scales: Variant = time_controller.get(&"scales")
		_lines.append("time_scale %.2f   stack %s" % [Engine.time_scale, str(scales)])

	var missing := PlayerInput.verify()
	if not missing.is_empty():
		_lines.append("INPUT MISSING: %s" % ", ".join(missing))


func _draw() -> void:
	if _lines.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return

	var line_height := font_size + 5
	var box := Rect2(
		Vector2(-6, -4),
		Vector2(size.x, _lines.size() * line_height + 10)
	)
	draw_rect(box, background, true)

	var y := float(font_size)
	for line in _lines:
		var color := warn_color if line.begins_with("INPUT MISSING") else text_color
		draw_string(
			font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
		)
		y += line_height
