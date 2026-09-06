class_name LaunchRequest extends RefCounted

var instance: SlugInstance
var source: Node3D
var source_id: StringName
var muzzle_transform: Transform3D = Transform3D.IDENTITY
var direction: Vector3 = Vector3.FORWARD
var speed_mps: float = 20.0
var parent: Node
