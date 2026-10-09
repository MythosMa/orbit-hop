extends Node2D
class_name Planet

## A circular world the ship can orbit and be captured by. Drawn procedurally.

var radius: float = 64.0
var capture_pad: float = 34.0
var ang_speed: float = 3.6      # radians / second while orbiting
var orbit_dir: int = 1          # +1 / -1 spin direction (screen space)
var idx: int = 0

var body_color: Color = Color(0.86, 0.90, 0.97)
var accent: Color = Color(0.5, 0.85, 1.0)

var _pulse: float = 0.0


func pulse() -> void:
	_pulse = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.6)
		queue_redraw()


func _draw() -> void:
	# Gravity capture ring (the aim target).
	var ring_color := Color(accent.r, accent.g, accent.b, 0.10 + 0.20 * _pulse)
	draw_arc(Vector2.ZERO, radius + capture_pad, 0.0, TAU, 56, ring_color, 2.0, true)

	# Body.
	draw_circle(Vector2.ZERO, radius, body_color)

	# Soft inner highlight for a hint of depth.
	draw_circle(Vector2(-radius * 0.22, -radius * 0.22), radius * 0.86, Color(1, 1, 1, 0.05))

	# Rim light.
	var rim := Color(1, 1, 1, 0.30 + 0.55 * _pulse)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, rim, 3.0 + 3.5 * _pulse, true)
