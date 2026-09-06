class_name VelocimorphEffect extends RefCounted


func create_packet(instance: SlugInstance, request: LaunchRequest, shot_id: int, point: Vector3) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.source = request.source if is_instance_valid(request.source) else null
	packet.source_id = request.source_id
	packet.shot_id = shot_id
	packet.element = instance.data.element
	packet.base_power = instance.data.base_power
	packet.experience_tier = instance.experience_tier()
	packet.impact_point = point
	return packet
