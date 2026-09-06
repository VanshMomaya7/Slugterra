class_name SlugProjectile extends Node3D

enum State { DORMANT_FLIGHT, TRANSFORMING, VELOCIMORPH, DUD_WAIT, REVERTING, RETURNING, FINISHED }
const TRANSFORM_SECONDS := 0.25
const DUD_SECONDS := 1.5
const REVERT_SECONDS := 0.2
const RETURN_SECONDS := 1.2
const MAX_FLIGHT_SECONDS := 8.0
const MAX_DISTANCE := 250.0
const COLLISION_MASK := 1 | 2 | 4 | 16

var state := State.DORMANT_FLIGHT
var velocity := Vector3.ZERO
var shot_id := 0
var instance: SlugInstance
var transformed := false
var _request: LaunchRequest
var _effect: VelocimorphEffect
var _visual: Node3D
var _state_time := 0.0
var _flight_time := 0.0
var _has_impacted := false
var _finished := false
var _excluded: Array[RID] = []
var _return_from := Vector3.ZERO

func configure(request: LaunchRequest, id: int, effect: VelocimorphEffect) -> void:
	_request = request
	shot_id = id
	instance = request.instance
	_effect = effect
	velocity = request.direction.normalized() * request.speed_mps
	_collect_excludes(request.source)

func _ready() -> void:
	name = "SlugShot_%d" % shot_id
	add_to_group(&"slug_projectiles")
	global_transform = _request.muzzle_transform
	_show_visual(instance.data.dormant_scene)
	set_physics_process(false)

func begin_flight() -> void:
	set_physics_process(true)
	if _request.speed_mps >= instance.data.velocity_threshold:
		transformed = true
		instance.energy = maxf(0.0, instance.energy - instance.data.energy_cost)
		_set_state(State.TRANSFORMING)
		_show_visual(instance.data.velocimorph_scene)
		EventBus.slug_transformed.emit(shot_id, instance)
		TimeController.hitstop(0.06)

func _physics_process(delta: float) -> void:
	if _finished:
		return
	_state_time += delta
	_flight_time += delta if state in [State.DORMANT_FLIGHT, State.TRANSFORMING, State.VELOCIMORPH] else 0.0
	if state in [State.DORMANT_FLIGHT, State.TRANSFORMING, State.VELOCIMORPH]:
		if _flight_time >= MAX_FLIGHT_SECONDS or global_position.distance_to(instance.last_return_position) > MAX_DISTANCE:
			begin_return()
			return
		if not _has_impacted:
			_advance_flight(delta)
		if state == State.TRANSFORMING and _state_time >= TRANSFORM_SECONDS:
			_set_state(State.VELOCIMORPH if not _has_impacted else State.REVERTING)
		elif state == State.VELOCIMORPH and _state_time >= instance.data.velocimorph_duration:
			_set_state(State.REVERTING)
	elif state == State.DUD_WAIT:
		if _state_time >= DUD_SECONDS:
			begin_return()
	elif state == State.REVERTING:
		if _state_time >= REVERT_SECONDS:
			begin_return()
	elif state == State.RETURNING:
		global_position = _return_from.lerp(instance.last_return_position, minf(1.0, _state_time / RETURN_SECONDS))
		if _state_time >= RETURN_SECONDS:
			_finish()
			queue_free()

func _advance_flight(delta: float) -> void:
	var next_position := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, COLLISION_MASK, _excluded)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next_position
	else:
		global_position = hit.position
		resolve_impact(hit.collider as Node, hit.position, hit.normal)

func resolve_impact(collider: Node, point: Vector3, normal := Vector3.UP) -> void:
	if _has_impacted or state not in [State.DORMANT_FLIGHT, State.TRANSFORMING, State.VELOCIMORPH]:
		return
	_has_impacted = true
	if not transformed:
		velocity = velocity.bounce(normal) * 0.15
		_set_state(State.DUD_WAIT)
		instance.set_availability(SlugInstance.Availability.DUD_WAIT)
		EventBus.slug_dud.emit(shot_id, instance)
		return
	var target := _find_damageable(collider)
	if target != null:
		var result := target.receive(_effect.create_packet(instance, _request, shot_id, point))
		EventBus.slug_hit.emit(shot_id, instance, target.get_parent() as Node3D, result)
	_set_state(State.REVERTING)

func recall() -> bool:
	if state != State.DUD_WAIT:
		return false
	begin_return()
	return true

func begin_return() -> void:
	if _finished or state == State.RETURNING:
		return
	_return_from = global_position
	_show_visual(instance.data.dormant_scene)
	_set_state(State.RETURNING)
	instance.set_availability(SlugInstance.Availability.RETURNING)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	state = State.FINISHED
	if instance == null or instance.active_shot_id != shot_id:
		return
	instance.active_shot_id = 0
	if transformed:
		instance.experience += instance.data.experience_per_transform
		instance.cooldown_remaining = instance.data.cooldown
		instance.set_availability(SlugInstance.Availability.COOLDOWN)
		EventBus.slug_experience_gained.emit(instance, instance.data.experience_per_transform, instance.experience)
	else:
		instance.set_availability(SlugInstance.Availability.READY)
	EventBus.slug_returned.emit(shot_id, instance)

func _exit_tree() -> void:
	_finish()

func _set_state(value: State) -> void:
	state = value
	_state_time = 0.0

func _show_visual(scene: PackedScene) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = scene.instantiate() as Node3D
	add_child(_visual)

func _collect_excludes(node: Node) -> void:
	if node is CollisionObject3D:
		_excluded.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_excludes(child)

func _find_damageable(node: Node) -> Damageable:
	var current := node
	for _depth in range(3):
		if not is_instance_valid(current):
			return null
		if current is Damageable:
			return current as Damageable
		var component := current.get_node_or_null("Damageable") as Damageable
		if component != null:
			return component
		current = current.get_parent()
	return null
