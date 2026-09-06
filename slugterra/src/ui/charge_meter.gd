class_name ChargeMeter
extends Control
## The charge bar, and the most important pixels in the game.
##
## The design doc is explicit that the 100 mph threshold must be rendered as a
## hard marked notch: the player always has to know which side of it they are
## on. Everything here serves that - the fill changes colour the instant it
## crosses, and the notch is drawn from the equipped slug's own threshold run
## back through the charge curve, never from a hardcoded fraction of the bar.

@export var track_color := Color(0.05, 0.07, 0.10, 0.78)
@export var border_color := Color(0.55, 0.72, 0.82, 0.55)
## Fill below the threshold: this shot will dud.
@export var under_color := Color(0.88, 0.36, 0.20, 0.95)
## Fill at or above the threshold: this shot will transform.
@export var over_color := Color(0.24, 0.90, 1.0, 0.98)
@export var notch_color := Color(1, 1, 1, 0.95)
@export var text_color := Color(0.88, 0.94, 0.98, 1.0)

@export var bar_height := 14.0
@export var notch_width := 3.0
@export var font_size := 15

var _charge := 0.0
var _speed_mps := 0.0
var _threshold_marker := 0.588
var _threshold_mps := 44.7
var _active := false
## Held briefly after release so the bar does not vanish before the eye reads it.
var _afterglow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Where the notch sits along the bar, 0..1, plus the speed it represents.
func set_threshold(marker01: float, threshold_mps: float) -> void:
	_threshold_marker = clampf(marker01, 0.0, 1.0)
	_threshold_mps = threshold_mps
	queue_redraw()


func set_charge(charge01: float, speed_mps: float) -> void:
	_charge = clampf(charge01, 0.0, 1.0)
	_speed_mps = speed_mps
	queue_redraw()


func begin() -> void:
	_active = true
	_afterglow = 0.0
	set_process(false)
	queue_redraw()


## Fades the bar out over `hold` seconds of real time.
func finish(hold := 0.35) -> void:
	_active = false
	_afterglow = hold
	set_process(hold > 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	# Unscaled: the meter should fade at the same rate during a hitstop.
	_afterglow = maxf(_afterglow - delta, 0.0)
	if _afterglow <= 0.0:
		set_process(false)
	queue_redraw()


func is_showing() -> bool:
	return _active or _afterglow > 0.0


func _draw() -> void:
	if not is_showing():
		return

	var alpha := 1.0 if _active else clampf(_afterglow / 0.35, 0.0, 1.0)
	var full := Rect2(Vector2.ZERO, size)
	var bar := Rect2(
		Vector2(0.0, size.y - bar_height), Vector2(size.x, bar_height)
	)

	draw_rect(bar, _fade(track_color, alpha), true)

	var clears := _speed_mps >= _threshold_mps
	var fill_color := over_color if clears else under_color

	var fill := Rect2(bar.position, Vector2(bar.size.x * _charge, bar.size.y))
	if fill.size.x > 0.0:
		draw_rect(fill, _fade(fill_color, alpha), true)

	# A soft bloom above the bar once the shot is live, so peripheral vision
	# catches the state change without reading the number.
	if clears and _active:
		var glow := Rect2(
			Vector2(bar.position.x, bar.position.y - 3.0), Vector2(fill.size.x, 3.0)
		)
		draw_rect(glow, _fade(over_color * Color(1, 1, 1, 0.35), alpha), true)

	draw_rect(bar, _fade(border_color, alpha), false, 1.0)

	# The notch. Overhangs the bar so it stays legible against a full fill.
	var notch_x := bar.position.x + bar.size.x * _threshold_marker
	var notch := Rect2(
		Vector2(notch_x - notch_width * 0.5, bar.position.y - 5.0),
		Vector2(notch_width, bar.size.y + 10.0)
	)
	draw_rect(notch, _fade(notch_color, alpha), true)

	_draw_labels(full, bar, notch_x, clears, alpha)


func _draw_labels(
	full: Rect2, bar: Rect2, notch_x: float, clears: bool, alpha: float
) -> void:
	var font := get_theme_default_font()
	if font == null:
		return

	var mph := ChargeConfig.mps_to_mph(_speed_mps)
	var readout := "%d mph" % roundi(mph)
	var readout_color := over_color if clears else under_color
	draw_string(
		font,
		Vector2(bar.position.x, bar.position.y - 12.0),
		readout,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		_fade(readout_color, alpha)
	)

	var verdict := "TRANSFORM" if clears else "DUD"
	draw_string(
		font,
		Vector2(bar.position.x, bar.position.y - 12.0),
		verdict,
		HORIZONTAL_ALIGNMENT_RIGHT,
		bar.size.x,
		font_size,
		_fade(readout_color, alpha)
	)

	# The threshold's own number, parked under the notch.
	var threshold_label := "%d" % roundi(ChargeConfig.mps_to_mph(_threshold_mps))
	draw_string(
		font,
		Vector2(notch_x - 14.0, bar.position.y + bar.size.y + 18.0),
		threshold_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size - 3,
		_fade(text_color * Color(1, 1, 1, 0.8), alpha)
	)


func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
