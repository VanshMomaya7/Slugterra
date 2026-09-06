class_name BeltStrip
extends Control
## The six equipped slugs, their availability, and their cooldown sweeps.
##
## Slugs are characters, not ammo, so a slot has to show more than "loaded".
## Availability is colour-coded and the cooldown drains visibly, which is what
## lets a player understand why a shot was refused instead of reading it as jank.
##
## The belt is Codex's [code]SlugBelt[/code] and is duck-typed here, so the HUD
## still lays out correctly with no belt bound.

const SLOT_COUNT := 6

@export var slot_size := Vector2(52, 52)
@export var slot_gap := 6.0

@export var empty_color := Color(0.10, 0.12, 0.16, 0.70)
@export var ready_color := Color(0.24, 0.90, 1.0, 0.90)
@export var busy_color := Color(0.85, 0.62, 0.20, 0.90)
@export var cooldown_color := Color(0.45, 0.50, 0.58, 0.85)
@export var ghouled_color := Color(0.62, 0.22, 0.75, 0.95)
@export var active_outline := Color(1, 1, 1, 0.95)
@export var text_color := Color(0.88, 0.94, 0.98, 0.95)

var _belt: Object
var _refresh_accumulator := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(
		SLOT_COUNT * slot_size.x + (SLOT_COUNT - 1) * slot_gap, slot_size.y + 18.0
	)


func bind_belt(belt: Object) -> void:
	_belt = belt
	if _belt != null and _belt.has_signal("active_changed"):
		if not _belt.is_connected("active_changed", _on_belt_changed):
			_belt.connect("active_changed", _on_belt_changed)
	if _belt != null and _belt.has_signal("slots_changed"):
		if not _belt.is_connected("slots_changed", _on_slots_changed):
			_belt.connect("slots_changed", _on_slots_changed)
	queue_redraw()


func _on_belt_changed(_index: int, _instance: Object) -> void:
	queue_redraw()


func _on_slots_changed() -> void:
	queue_redraw()


## Cooldown sweeps need a steady repaint, but not a per-frame one. 10 Hz reads
## as continuous and keeps the HUD off the frame budget.
func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator >= 0.1:
		_refresh_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var active_index := -1
	if _belt != null:
		var value: Variant = _belt.get(&"active_index")
		if value != null:
			active_index = int(value)

	for i in SLOT_COUNT:
		var origin := Vector2(i * (slot_size.x + slot_gap), 0.0)
		var rect := Rect2(origin, slot_size)
		var instance := _slot(i)

		draw_rect(rect, _slot_color(instance), true)

		var cooldown := _cooldown_fraction(instance)
		if cooldown > 0.0:
			# Drains downward, so "how much longer" is readable at a glance.
			var height := rect.size.y * cooldown
			draw_rect(
				Rect2(
					Vector2(rect.position.x, rect.position.y + rect.size.y - height),
					Vector2(rect.size.x, height)
				),
				Color(0.02, 0.03, 0.05, 0.55),
				true
			)

		var outline := active_outline if i == active_index else Color(1, 1, 1, 0.18)
		draw_rect(rect, outline, false, 2.0 if i == active_index else 1.0)

		if font == null:
			continue

		draw_string(
			font,
			origin + Vector2(5.0, 15.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(text_color.r, text_color.g, text_color.b, 0.75)
		)

		var label := _slot_label(instance)
		if label != "":
			draw_string(
				font,
				origin + Vector2(4.0, slot_size.y - 8.0),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				slot_size.x - 8.0,
				12,
				text_color
			)


func _slot(index: int) -> Object:
	if _belt == null or not _belt.has_method("get_slot"):
		return null
	return _belt.call("get_slot", index)


func _slot_color(instance: Object) -> Color:
	if instance == null:
		return empty_color
	if bool(instance.get(&"is_ghouled")):
		return ghouled_color

	# Availability mirrors SlugInstance.Availability:
	# 0 READY, 1 IN_FLIGHT, 2 DUD_WAIT, 3 RETURNING, 4 COOLDOWN, 5 GHOULED.
	var availability := int(instance.get(&"availability"))
	match availability:
		0:
			return ready_color
		4:
			return cooldown_color
		5:
			return ghouled_color
		_:
			return busy_color


func _cooldown_fraction(instance: Object) -> float:
	if instance == null:
		return 0.0
	var remaining: Variant = instance.get(&"cooldown_remaining")
	if remaining == null or float(remaining) <= 0.0:
		return 0.0

	var data: Object = instance.get(&"data")
	var total := 6.0
	if data != null:
		var cooldown: Variant = data.get(&"cooldown")
		if cooldown != null and float(cooldown) > 0.0:
			total = float(cooldown)
	return clampf(float(remaining) / total, 0.0, 1.0)


func _slot_label(instance: Object) -> String:
	if instance == null:
		return ""
	var nickname: Variant = instance.get(&"nickname")
	if nickname != null and String(nickname) != "":
		return String(nickname)
	var data: Object = instance.get(&"data")
	if data == null:
		return "?"
	var display: Variant = data.get(&"display_name")
	return String(display) if display != null else "?"
