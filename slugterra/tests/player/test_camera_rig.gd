extends GdUnitTestSuite
## Camera profiles, look clamping and aim resolution.

const RIG_SCENE := "res://scenes/prefabs/player/camera_rig.tscn"

var _rig: CameraRig


func before_test() -> void:
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as CameraRig
	add_child(_rig)


func after_test() -> void:
	if is_instance_valid(_rig):
		_rig.queue_free()


func test_scene_wires_its_three_profiles() -> void:
	assert_object(_rig.explore_profile).is_not_null()
	assert_object(_rig.aim_profile).is_not_null()
	assert_object(_rig.duel_profile).is_not_null()


func test_starts_in_the_explore_profile() -> void:
	assert_str(String(_rig.get_profile_id())).is_equal("explore")
	assert_float(_rig.spring_arm.spring_length).is_equal_approx(
		_rig.explore_profile.arm_length, 0.01
	)


func test_aim_profile_pulls_the_camera_in_and_over_the_shoulder() -> void:
	_rig.set_profile(CameraRig.PROFILE_AIM, 0.0)
	_rig._process(0.0)

	assert_float(_rig.spring_arm.spring_length).is_equal_approx(
		_rig.aim_profile.arm_length, 0.01
	)
	assert_float(_rig.get_camera().fov).is_equal_approx(_rig.aim_profile.fov, 0.01)
	assert_float(_rig.get_camera().position.x).is_greater(0.1)
	# Aiming must actually tighten the framing, or the profile is cosmetic.
	assert_float(_rig.aim_profile.arm_length).is_less(_rig.explore_profile.arm_length)
	assert_float(_rig.aim_profile.fov).is_less(_rig.explore_profile.fov)


func test_profile_blend_moves_gradually_then_settles() -> void:
	var start := _rig.spring_arm.spring_length
	_rig.set_profile(CameraRig.PROFILE_AIM, 0.4)

	_rig._process(0.1)
	var midway := _rig.spring_arm.spring_length
	assert_float(midway).is_less(start)
	assert_float(midway).is_greater(_rig.aim_profile.arm_length)

	for i in 30:
		_rig._process(0.05)
	assert_float(_rig.spring_arm.spring_length).is_equal_approx(
		_rig.aim_profile.arm_length, 0.01
	)


func test_profile_changed_signal_fires() -> void:
	var seen: Array[StringName] = []
	_rig.profile_changed.connect(func(id: StringName) -> void: seen.append(id))
	_rig.set_profile(CameraRig.PROFILE_AIM, 0.0)
	assert_array(seen).contains([&"aim"])


func test_unknown_profile_falls_back_instead_of_crashing() -> void:
	_rig.set_profile(&"nonexistent", 0.0)
	_rig._process(0.0)
	assert_float(_rig.spring_arm.spring_length).is_greater(0.0)


func test_pitch_is_clamped_to_the_profile_limits() -> void:
	_rig.add_look(0.0, 10000.0)
	_rig._process(0.0)
	assert_float(_rig.pivot.rotation.x).is_less_equal(
		deg_to_rad(_rig.explore_profile.pitch_max_deg) + 0.001
	)

	_rig.add_look(0.0, -20000.0)
	_rig._process(0.0)
	assert_float(_rig.pivot.rotation.x).is_greater_equal(
		deg_to_rad(_rig.explore_profile.pitch_min_deg) - 0.001
	)


func test_yaw_rotates_the_rig_and_is_unclamped() -> void:
	_rig.add_look(90.0, 0.0)
	_rig._process(0.0)
	assert_float(absf(_rig.rotation.y)).is_equal_approx(deg_to_rad(90.0), 0.001)


## Yaw basis must stay level, or looking down would shorten the player's stride.
func test_yaw_basis_ignores_pitch() -> void:
	_rig.add_look(45.0, 40.0)
	_rig._process(0.0)

	var basis := _rig.get_yaw_basis()
	var forward := -basis.z
	assert_float(forward.y).is_equal_approx(0.0, 0.0001)
	assert_float(forward.length()).is_equal_approx(1.0, 0.0001)


func test_aim_point_falls_back_to_max_distance_on_a_miss() -> void:
	# Nothing is in the scene to hit, so the ray must report the far point.
	var point := _rig.get_aim_point(100.0)
	var expected := _rig.get_aim_origin() + _rig.get_aim_direction() * 100.0
	assert_vector(point).is_equal_approx(expected, Vector3.ONE * 0.01)


func test_aim_direction_is_normalised() -> void:
	_rig.add_look(30.0, 20.0)
	_rig._process(0.0)
	assert_float(_rig.get_aim_direction().length()).is_equal_approx(1.0, 0.0001)


func test_occlusion_fade_leaves_the_mesh_opaque_with_a_clear_arm() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var visual := Node3D.new()
	visual.add_child(mesh)
	add_child(visual)

	_rig.visual_root = visual
	_rig._collect_fadeable(visual)
	_rig._process(0.0)

	assert_float(mesh.transparency).is_equal_approx(0.0, 0.001)
	visual.queue_free()
