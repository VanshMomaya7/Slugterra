class_name SlugLauncher extends RefCounted

static func launch(request: LaunchRequest) -> LaunchResult:
	var result := LaunchResult.new()
	if request == null or request.instance == null:
		result.reason = &"no_slug"
		return result
	var instance := request.instance
	if instance.is_ghouled:
		result.reason = &"ghouled"
		return result
	if not instance.is_ready():
		result.reason = &"unavailable"
		return result
	if not is_instance_valid(request.parent) or not request.parent.is_inside_tree():
		result.reason = &"no_parent"
		return result
	if not is_instance_valid(request.source) or not request.source.is_inside_tree():
		result.reason = &"no_source"
		return result
	if request.speed_mps <= 0.0 or request.direction.is_zero_approx() or instance.data == null:
		result.reason = &"invalid_request"
		return result
	var effect := instance.data.effect_script.new() as VelocimorphEffect
	if effect == null:
		result.reason = &"invalid_data"
		return result
	var shot_id := GameState.allocate_shot_id()
	var projectile := SlugProjectile.new()
	projectile.configure(request, shot_id, effect)
	instance.active_shot_id = shot_id
	instance.last_return_position = request.source.global_position + Vector3.UP
	instance.set_availability(SlugInstance.Availability.IN_FLIGHT)
	request.parent.add_child(projectile)
	result.accepted = true
	result.reason = &"ok"
	result.shot_id = shot_id
	result.projectile = projectile
	EventBus.slug_launched.emit(shot_id, instance, projectile)
	projectile.begin_flight()
	return result
