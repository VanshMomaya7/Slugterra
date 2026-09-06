extends VelocimorphEffect


func create_packet(instance: SlugInstance, request: LaunchRequest, shot_id: int, point: Vector3) -> DamagePacket:
	var packet := super.create_packet(instance, request, shot_id, point)
	packet.status_to_apply = &"burning"
	packet.status_duration = 3.0
	return packet
