extends Node2D
class_name Ship

## The player's craft. Nose points along local -Y; set rotation to aim it.

var body_color: Color = Color(0.95, 0.97, 1.0)
var accent: Color = Color(0.5, 0.85, 1.0)


func _draw() -> void:
	# Engine glow behind the craft.
	draw_circle(Vector2(0, 8), 6.0, Color(accent.r, accent.g, accent.b, 0.30))
	var hull := PackedVector2Array([
		Vector2(0, -15), Vector2(10, 11), Vector2(0, 5), Vector2(-10, 11)
	])
	draw_colored_polygon(hull, body_color)
	# Cockpit dot.
	draw_circle(Vector2(0, -4), 2.6, accent)
