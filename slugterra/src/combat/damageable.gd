class_name Damageable extends Node

signal damaged(result: DamageResult)
signal died()
signal status_changed(status: StringName, active: bool)

@export var max_hp: float = 100.0
@export var defender_element: StringName = &"none"
var hp: float = 100.0
var statuses: Dictionary = {}


func _ready() -> void:
	reset_health()
	set_physics_process(false)


func receive(packet: DamagePacket) -> DamageResult:
	return CombatResolver.resolve(packet, self)


func reset_health() -> void:
	hp = max_hp
	for status in statuses.keys():
		clear_status(status)


func apply_status(status: StringName, duration: float) -> void:
	if status == &"" or duration <= 0.0:
		return
	statuses[status] = maxf(float(statuses.get(status, 0.0)), duration)
	status_changed.emit(status, true)
	EventBus.status_applied.emit(get_parent() as Node3D, status, duration)
	set_physics_process(true)


func clear_status(status: StringName) -> void:
	if not statuses.erase(status):
		return
	status_changed.emit(status, false)
	EventBus.status_cleared.emit(get_parent() as Node3D, status)
	if statuses.is_empty():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	for status in statuses.keys():
		statuses[status] -= delta
		if statuses[status] <= 0.0:
			clear_status(status)
