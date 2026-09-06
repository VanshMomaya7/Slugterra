extends Node

const STARTER_DATA: SlugData = preload("res://data/slugs/infurnus.tres")
var owned_slugs: Dictionary = {}
var belt_ids: Array[StringName] = []
var _next_shot_id: int = 1


func _ready() -> void:
	ensure_starter_slug()


func ensure_starter_slug() -> void:
	if owned_slugs.has(&"burpy"):
		return
	var burpy := SlugInstance.new()
	burpy.instance_id = &"burpy"
	burpy.nickname = "Burpy"
	burpy.data = STARTER_DATA
	owned_slugs[burpy.instance_id] = burpy
	belt_ids.resize(SlugBelt.SLOT_COUNT)
	belt_ids[0] = burpy.instance_id


func allocate_shot_id() -> int:
	var shot_id := _next_shot_id
	_next_shot_id += 1
	return shot_id


func _physics_process(delta: float) -> void:
	# Collection, rather than every belt view, is the sole cooldown clock owner.
	for instance: SlugInstance in owned_slugs.values():
		instance.tick_cooldown(delta)
