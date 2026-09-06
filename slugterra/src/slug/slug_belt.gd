class_name SlugBelt extends Node

signal active_changed(index: int, instance: SlugInstance)
signal slots_changed()

const SLOT_COUNT: int = 6
@export var use_player_collection: bool = true
var active_index: int = 0
var _slots: Array[SlugInstance] = []


func _ready() -> void:
	_slots.resize(SLOT_COUNT)
	if use_player_collection:
		GameState.ensure_starter_slug()
		for index in range(mini(SLOT_COUNT, GameState.belt_ids.size())):
			_slots[index] = GameState.owned_slugs.get(GameState.belt_ids[index])
	slots_changed.emit()
	active_changed.emit(active_index, get_active())


func _physics_process(_delta: float) -> void:
	var owner_body := get_parent() as Node3D
	if owner_body == null:
		return
	for instance in _slots:
		if instance != null:
			instance.last_return_position = owner_body.global_position + Vector3.UP


func get_slot(index: int) -> SlugInstance:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


func get_active() -> SlugInstance:
	return get_slot(active_index)


func select(index: int) -> void:
	if get_slot(index) == null or index == active_index:
		return
	active_index = index
	active_changed.emit(index, get_active())


func cycle(direction: int) -> void:
	if direction == 0:
		return
	var step := 1 if direction > 0 else -1
	for distance in range(1, SLOT_COUNT + 1):
		var index := posmod(active_index + distance * step, SLOT_COUNT)
		if get_slot(index) != null:
			select(index)
			return


func equip(index: int, instance: SlugInstance) -> bool:
	if _slots.size() != SLOT_COUNT:
		_slots.resize(SLOT_COUNT)
	if index < 0 or index >= SLOT_COUNT:
		return false
	if instance != null:
		for other in range(SLOT_COUNT):
			if other != index and _slots[other] != null and _slots[other].instance_id == instance.instance_id:
				return false
	if _slots[index] != null and not _slots[index].is_ready():
		return false
	_slots[index] = instance
	if use_player_collection:
		GameState.belt_ids.resize(SLOT_COUNT)
		GameState.belt_ids[index] = instance.instance_id if instance != null else &""
	slots_changed.emit()
	active_changed.emit(active_index, get_active())
	return true
