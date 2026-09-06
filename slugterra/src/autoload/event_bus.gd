extends Node
## Transient typed notifications; persistence uses stable content/instance IDs.

signal slug_launched(shot_id: int, instance: SlugInstance, projectile: Node3D)
signal slug_transformed(shot_id: int, instance: SlugInstance)
signal slug_dud(shot_id: int, instance: SlugInstance)
signal slug_hit(shot_id: int, instance: SlugInstance, target: Node3D, result: DamageResult)
signal slug_returned(shot_id: int, instance: SlugInstance)
signal slug_availability_changed(instance: SlugInstance)
signal slug_experience_gained(instance: SlugInstance, amount: int, new_total: int)
signal damage_dealt(packet: DamagePacket, target: Node3D, result: DamageResult)
signal status_applied(target: Node3D, status: StringName, duration: float)
signal status_cleared(target: Node3D, status: StringName)
signal entity_died(target: Node3D, packet: DamagePacket)
