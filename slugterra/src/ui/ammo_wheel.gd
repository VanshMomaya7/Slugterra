class_name AmmoWheel
extends Control
## Radial belt selector. Hold `wheel` to open, aim with the mouse, release to
## commit.
##
## Time drops to 0.25x while it is open, per the design doc. That slow-motion is
## pushed onto [code]TimeController[/code] under its own id rather than written
## straight to [member Engine.time_scale], so closing the wheel can never cancel
## a hitstop that started while it was open.
##
## The mouse is captured during play, so there is no cursor position to read.
## Selection integrates relative mouse motion into a stick-like vector instead,
## which is also what makes this work unchanged on a gamepad later.

signal opened()
signal closed(selected_index: int)

const TIME_SCALE_ID: StringName = &"ammo_wheel"
const SLOT_COUNT := 6
## Pixels of travel from centre before a sector counts as chosen. Below this the
## wheel keeps the current slot, so a twitch cannot swap your slug.
const SELECT_DEADZONE := 40.0

@export var wheel_time_scale := 0.25
@export var outer_radius := 150.0
@export var inner_radius := 62.0
@export var pointer_speed := 1.0

@export var sector_color := Color(0.08, 0.10, 0.14, 0.80)
@export var sector_hover := Color(0.24, 0.90, 1.0, 0.32)
@export var sector_empty := Color(0.08, 0.10, 0.14, 0.45)
@export var outline_color := Color(0.55, 0.72, 0.82, 0.5)
@export var text_color := Color(0.90, 0.95, 1.0, 0.95)
@export var pointer_color := Color(0.24, 0.90, 1.0, 0.9)

var _belt: Object
var _blaster: Object
var _open := false
var _pointer := Vector2.ZERO
var _selected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func bind(belt: Object, blaster: Object) -> void:
	_belt = belt
	_blaster = blaster


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not PlayerInput.has(PlayerInput.WHEEL):
		return

	if event.is_action_pressed(PlayerInput.WHEEL):
		open()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released(PlayerInput.WHEEL):
		close()
		get_viewport().set_input_as_handled()
		return

	# While open the wheel owns the mouse, so the camera does not swing around
	# behind it.
	if _open and event is InputEventMouseMotion:
		_pointer += (event as InputEventMouseMotion).relative * pointer_speed
		_pointer = _pointer.limit_length(outer_radius)
		_update_selection()
		queue_redraw()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _open:
		return
	_open = true
	_pointer = Vector2.ZERO
	_selected = _active_index()

	# Charging through the wheel would let the player buy real charge time at a
	# quarter speed, so the charge is dropped outright.
	if _blaster != null and _blaster.has_method("cancel_charge"):
		_blaster.call("cancel_charge")

	TimeController.push_scale(TIME_SCALE_ID, wheel_time_scale)
	visible = true
	set_process(true)
	queue_redraw()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	TimeController.pop_scale(TIME_SCALE_ID)
	visible = false
	set_process(false)

	if _selected >= 0 and _belt != null and _belt.has_method("select"):
		_belt.call("select", _selected)
	closed.emit(_selected)


## Safety net: if this node is removed while open, the slow motion must not be
## left pushed on the stack forever.
func _exit_tree() -> void:
	if _open:
		_open = false
		TimeController.pop_scale(TIME_SCALE_ID)


func _process(_delta: float) -> void:
	queue_redraw()


func _active_index() -> int:
	if _belt == null:
		return -1
	var value: Variant = _belt.get(&"active_index")
	return int(value) if value != null else -1


func _slot(index: int) -> Object:
	if _belt == null or not _belt.has_method("get_slot"):
		return null
	return _belt.call("get_slot", index)


func _update_selection() -> void:
	if _pointer.length() < SELECT_DEADZONE:
		return
	# Screen y grows downward; negate so 0 rad points straight up and the angle
	# grows clockwise, matching the order the sectors are drawn in.
	var span := TAU / SLOT_COUNT
	var angle := atan2(_pointer.x, -_pointer.y)
	# Sectors are drawn centred on their axis (slot 0 straight up), so the
	# buckets have to be shifted half a sector to line up. Without this, aiming
	# at the left half of a wedge selects its neighbour, and a pointer resting
	# exactly on a sector's centre lands on a bucket boundary where float error
	# decides the answer.
	angle = fposmod(angle + span * 0.5, TAU)
	_selected = int(angle / span) % SLOT_COUNT


func _sector_range(index: int) -> Vector2:
	var span := TAU / SLOT_COUNT
	# Rotated back by half a sector so slot 0 is centred on straight up.
	var start := index * span - span * 0.5 - PI * 0.5
	return Vector2(start, start + span)


func _draw() -> void:
	if not _open:
		return

	var centre := size * 0.5
	var font := get_theme_default_font()

	for i in SLOT_COUNT:
		var range_rad := _sector_range(i)
		var points := PackedVector2Array()
		var steps := 12

		for s in steps + 1:
			var a: float = lerpf(range_rad.x, range_rad.y, float(s) / float(steps))
			points.append(centre + Vector2(cos(a), sin(a)) * outer_radius)
		for s in steps + 1:
			var a: float = lerpf(range_rad.y, range_rad.x, float(s) / float(steps))
			points.append(centre + Vector2(cos(a), sin(a)) * inner_radius)

		var instance := _slot(i)
		var fill := sector_color if instance != null else sector_empty
		if i == _selected:
			fill = sector_hover
		draw_colored_polygon(points, fill)
		draw_polyline(points, outline_color, 1.5, true)

		if font == null:
			continue

		var mid_angle := (range_rad.x + range_rad.y) * 0.5
		var label_pos := centre + Vector2(cos(mid_angle), sin(mid_angle)) * (
			(outer_radius + inner_radius) * 0.5
		)
		var label := _slot_label(i, instance)
		draw_string(
			font,
			label_pos - Vector2(46, 0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			92,
			14,
			text_color if instance != null else Color(text_color, 0.45)
		)

	if _pointer.length() >= SELECT_DEADZONE:
		draw_line(centre, centre + _pointer, pointer_color, 2.0)
	draw_circle(centre, 5.0, pointer_color)


func _slot_label(index: int, instance: Object) -> String:
	if instance == null:
		return "%d\nempty" % (index + 1)

	var nickname: Variant = instance.get(&"nickname")
	if nickname != null and String(nickname) != "":
		return "%d\n%s" % [index + 1, String(nickname)]

	var data: Object = instance.get(&"data")
	if data != null:
		var display: Variant = data.get(&"display_name")
		if display != null:
			return "%d\n%s" % [index + 1, String(display)]
	return "%d\n?" % (index + 1)
