class_name ShotFeedback
extends Control
## One line of post-shot truth: what speed left the muzzle and what it meant.
##
## The dud band only teaches if the player can see they were under it. This is
## the cheapest possible version of that lesson and it stays useful long after
## the art lands.

@export var transform_color := Color(0.24, 0.90, 1.0, 1.0)
@export var dud_color := Color(0.88, 0.36, 0.20, 1.0)
@export var rejected_color := Color(0.75, 0.75, 0.80, 1.0)
@export var hold_time := 1.1
@export var fade_time := 0.45
@export var font_size := 20

var _text := ""
var _color := Color.WHITE
var _life := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Reports a shot from a [Blaster] release report.
func show_shot(report: Dictionary) -> void:
	var speed := float(report.get("speed_mps", 0.0))
	var mph := roundi(ChargeConfig.mps_to_mph(speed))
	var reason := StringName(report.get("reason", &""))

	if not bool(report.get("accepted", false)):
		show_message(_reason_text(reason), rejected_color)
		return

	if bool(report.get("will_transform", false)):
		var suffix := "  PERFECT" if bool(report.get("perfect", false)) else ""
		show_message("%d mph   TRANSFORM%s" % [mph, suffix], transform_color)
	else:
		show_message("%d mph   DUD" % mph, dud_color)


func show_message(text: String, color: Color) -> void:
	_text = text
	_color = color
	_life = hold_time + fade_time
	set_process(true)
	queue_redraw()


func _reason_text(reason: StringName) -> String:
	match reason:
		&"no_slug":
			return "NO SLUG EQUIPPED"
		&"unavailable":
			return "SLUG NOT READY"
		&"cooldown":
			return "COOLING DOWN"
		&"ghouled":
			return "SLUG IS GHOULED"
		&"launcher_missing":
			return "LAUNCHER UNAVAILABLE"
		&"launch_failed":
			return "LAUNCH FAILED"
		&"not_charging":
			return ""
		_:
			return String(reason).to_upper()


## Unscaled, so feedback reads at the same speed through a hitstop.
func _process(delta: float) -> void:
	_life = maxf(_life - delta, 0.0)
	if _life <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _life <= 0.0 or _text == "":
		return
	var font := get_theme_default_font()
	if font == null:
		return

	var alpha := clampf(_life / fade_time, 0.0, 1.0)
	# Rises slightly as it fades.
	var lift := (1.0 - alpha) * 8.0
	draw_string(
		font,
		Vector2(0.0, size.y - lift),
		_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		font_size,
		Color(_color.r, _color.g, _color.b, _color.a * alpha)
	)
