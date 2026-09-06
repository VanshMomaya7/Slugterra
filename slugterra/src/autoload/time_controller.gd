extends Node
## Each system owns its scale key; removing one cannot cancel another.

signal scale_changed(effective: float)
var scales: Dictionary = {}
var _hitstop_generation: int = 0


func push_scale(id: StringName, scale: float) -> void:
	if not is_finite(scale):
		return
	scales[id] = clampf(scale, 0.0, 1.0)
	_refresh()


func pop_scale(id: StringName) -> void:
	scales.erase(id)
	_refresh()


func hitstop(duration_realtime: float, scale: float = 0.05) -> void:
	if duration_realtime <= 0.0:
		return
	_hitstop_generation += 1
	var generation := _hitstop_generation
	push_scale(&"hitstop", scale)
	await get_tree().create_timer(duration_realtime, true, false, true).timeout
	if generation == _hitstop_generation:
		pop_scale(&"hitstop")


func is_hitstopped() -> bool:
	return scales.has(&"hitstop")


func reset() -> void:
	_hitstop_generation += 1
	scales.clear()
	_refresh()


func _refresh() -> void:
	var effective := 1.0
	for scale in scales.values():
		effective = minf(effective, float(scale))
	if not is_equal_approx(effective, Engine.time_scale):
		Engine.time_scale = effective
		scale_changed.emit(effective)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
