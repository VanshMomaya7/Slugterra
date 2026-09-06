class_name SlugInstance extends Resource

enum Availability { READY, IN_FLIGHT, DUD_WAIT, RETURNING, COOLDOWN, GHOULED }

var instance_id: StringName
var nickname: String = ""
var data: SlugData
var experience: int = 0
var energy: float = 100.0
var trust: float = 100.0
var fatigue: float = 0.0
var is_ghouled: bool = false
var availability: Availability = Availability.READY
var cooldown_remaining: float = 0.0
var active_shot_id: int = 0
var last_return_position: Vector3 = Vector3.ZERO


func is_ready() -> bool:
	return data != null and not is_ghouled and availability == Availability.READY and active_shot_id == 0


func experience_tier() -> int:
	if experience >= 600:
		return 3
	if experience >= 300:
		return 2
	if experience >= 100:
		return 1
	return 0


func mood_icon_key() -> StringName:
	if is_ghouled:
		return &"ghouled"
	if fatigue >= 70.0:
		return &"tired"
	if trust < 30.0:
		return &"wary"
	return &"happy"


func set_availability(value: Availability) -> void:
	if value == availability:
		return
	availability = value
	EventBus.slug_availability_changed.emit(self)


func tick_cooldown(delta: float) -> void:
	if availability != Availability.COOLDOWN:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		set_availability(Availability.GHOULED if is_ghouled else Availability.READY)
