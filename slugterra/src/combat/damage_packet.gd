class_name DamagePacket extends RefCounted

var source: Node3D
var source_id: StringName
var shot_id: int = 0
var element: StringName = &"none"
var base_power: float = 0.0
var experience_tier: int = 0
var status_to_apply: StringName = &""
var status_duration: float = 0.0
var impact_point: Vector3 = Vector3.ZERO
