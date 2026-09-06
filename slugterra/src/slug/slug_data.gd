class_name SlugData extends Resource
## Shared breed definition. Per-owned-slug state belongs to SlugInstance.

@export var id: StringName
@export var display_name: String
@export var element: StringName = &"fire"
@export_range(0.5, 2.0) var mass_factor: float = 1.0
@export var velocity_threshold: float = 44.7
@export var velocimorph_duration: float = 4.0
@export var cooldown: float = 6.0
@export var dormant_scene: PackedScene
@export var velocimorph_scene: PackedScene
@export var effect_script: Script
@export var base_power: float = 25.0
@export var accuracy_cone_deg: float = 1.5
@export var energy_cost: float = 5.0
@export var experience_per_transform: int = 10
@export var ghoul_counterpart: SlugData
@export var can_be_ghouled: bool = true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("Slug id is empty")
	if velocity_threshold <= 0.0 or not is_finite(velocity_threshold):
		errors.append("Velocity threshold must be positive and finite")
	if dormant_scene == null or velocimorph_scene == null:
		errors.append("Both placeholder scene bindings are required")
	if effect_script == null or not effect_script.can_instantiate():
		errors.append("An instantiable effect script is required")
	if cooldown < 0.0 or energy_cost < 0.0 or base_power < 0.0:
		errors.append("Costs, cooldown and power must be nonnegative")
	return errors
