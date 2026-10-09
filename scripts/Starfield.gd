extends Node2D
class_name Starfield

## Parallax starfield drawn in camera space. Attach as a child of the Camera2D so
## it follows the view and wraps infinitely as the camera moves.

@export var count: int = 160
@export var parallax: float = 0.28

var _stars: Array = []


func _ready() -> void:
	randomize()
	for i in count:
		var t := randf()
		var b := lerpf(0.35, 1.0, t * t)   # more dim stars than bright
		_stars.append({
			"u": randf(),
			"v": randf(),
			"size": lerpf(0.8, 2.4, t),
			"color": Color(0.78, 0.86, 1.0, b * 0.85),
		})


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp := get_viewport_rect().size
	var shift: Vector2 = cam.global_position * parallax
	for s in _stars:
		var x: float = (s.u - 0.5) * vp.x - shift.x
		var y: float = (s.v - 0.5) * vp.y - shift.y
		x = fposmod(x + vp.x * 0.5, vp.x) - vp.x * 0.5
		y = fposmod(y + vp.y * 0.5, vp.y) - vp.y * 0.5
		draw_circle(Vector2(x, y), s.size, s.color)
