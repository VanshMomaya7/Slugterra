extends Node
## All damage passes here. Matchups/cross-status rules expand this boundary in M1.


func resolve(packet: DamagePacket, target: Damageable) -> DamageResult:
	var result := DamageResult.new()
	if packet == null or not is_instance_valid(target):
		return result
	result.remaining_hp = target.hp
	if target.hp <= 0.0:
		result.reason = &"already_dead"
		return result
	if not is_finite(packet.base_power) or packet.base_power < 0.0:
		result.reason = &"invalid_power"
		return result
	result.damage = minf(target.hp, packet.base_power * (1.0 + maxf(0.0, packet.experience_tier) * 0.1))
	target.hp -= result.damage
	result.remaining_hp = target.hp
	result.killed = target.hp <= 0.0
	result.applied = true
	result.reason = &"ok"
	if not result.killed:
		target.apply_status(packet.status_to_apply, packet.status_duration)
	target.damaged.emit(result)
	var body := target.get_parent() as Node3D
	EventBus.damage_dealt.emit(packet, body, result)
	if result.killed:
		target.died.emit()
		EventBus.entity_died.emit(body, packet)
	return result
