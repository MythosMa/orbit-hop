extends Node2D

## Root of the game. Builds the world + UI in code, owns the state machine,
## orbital/flight math, procedural level generation and scoring.

const FLY_SPEED := 660.0
const STANDOFF := 20.0        # orbit radius = planet.radius + STANDOFF
const MAX_FLIGHT := 1700.0    # flew this far without capture -> miss

enum State { MENU, PLAY, OVER }
enum ShipMode { ORBIT, FLY, DEAD }

# ---- world ----
var _world: Node2D
var _cam: Camera2D
var _trail: Line2D
var _ship: Ship
var _stars: Starfield
var _planets: Array[Planet] = []

# ---- ship motion ----
var _mode: int = ShipMode.ORBIT
var _current: Planet
var _launch_from: Planet = null
var _orbit_angle: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _fly_dist: float = 0.0
var _trail_pts: Array[Vector2] = []

# ---- progression ----
var _state: int = State.MENU
var _score: int = 0
var _combo: int = 0
var _best: int = 0
var _next_index: int = 0
var _shake: float = 0.0
var _over_at: int = 0

# ---- ui ----
var _score_label: Label
var _combo_label: Label
var _scrim: TextureRect
var _menu: Control
var _over: Control
var _over_score: Label
var _over_best: Label
var _over_new: Label
var _combo_tween: Tween


func _ready() -> void:
	randomize()
	Sfx.init(self)
	_best = SaveData.best()
	_register_input()
	_build_camera()
	_build_world()
	_build_ui()
	_reset_world()
	_state = State.MENU
	_show_menu()


# ------------------------------------------------------------------ setup

func _register_input() -> void:
	if not InputMap.has_action("tap"):
		InputMap.add_action("tap")
	InputMap.action_erase_events("tap")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("tap", mb)
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	InputMap.action_add_event("tap", k)
	var k2 := InputEventKey.new()
	k2.keycode = KEY_ENTER
	InputMap.action_add_event("tap", k2)


func _build_camera() -> void:
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	_cam.enabled = true
	add_child(_cam)
	_stars = Starfield.new()
	_cam.add_child(_stars)


func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)
	_trail = Line2D.new()
	_trail.width = 7.0
	_trail.default_color = Color(0.55, 0.85, 1.0, 0.5)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_world.add_child(_trail)
	_ship = Ship.new()
	_world.add_child(_ship)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = ""
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _dim_backdrop(parent: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)


func _center(node: Label, y_offset: float, width: float) -> void:
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.set_anchors_preset(Control.PRESET_CENTER)
	node.position = Vector2(-width * 0.5, y_offset)
	node.size = Vector2(width, 110.0)


func _full_rect(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = load("res://fonts/ui.ttf")
	root.theme = th
	layer.add_child(root)

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 4
	gtex.height = 64
	_scrim = TextureRect.new()
	_scrim.texture = gtex
	_scrim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_scrim.size = Vector2(_scrim.size.x, 260)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_scrim)

	_score_label = _make_label(64, Color(1, 1, 1, 0.95))
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.position = Vector2(-200, 60)
	_score_label.size = Vector2(400, 80)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_score_label)

	_combo_label = _make_label(28, Color(0.55, 0.85, 1, 0.9))
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position = Vector2(-200, 140)
	_combo_label.size = Vector2(400, 40)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_combo_label)

	_menu = _build_menu_panel(root)
	_over = _build_over_panel(root)


func _build_menu_panel(parent: Control) -> Control:
	var panel := _full_rect(parent)
	_dim_backdrop(panel)

	var title := _make_label(76, Color(1, 1, 1, 0.97))
	title.text = "轨道跳跃"
	_center(title, -160, 500)
	panel.add_child(title)

	var tag := _make_label(24, Color(0.6, 0.8, 1, 0.85))
	tag.text = "一次点击  ·  无尽星轨"
	_center(tag, -60, 500)
	panel.add_child(tag)

	var hint := _make_label(30, Color(1, 1, 1, 0.8))
	hint.text = "轻触  ·  点击  ·  空格"
	_center(hint, 90, 500)
	panel.add_child(hint)

	var best := _make_label(24, Color(1, 1, 1, 0.5))
	best.name = "BestLine"
	best.text = ("最佳  %d" % _best) if _best > 0 else ""
	_center(best, 160, 500)
	panel.add_child(best)

	var tip := _make_label(20, Color(1, 1, 1, 0.4))
	tip.text = "沿切线发射，跃向下一颗星球\n计分：抵达 +1；正穿星心 = 完美 再 +1\n分数越高，星轨越快、捕捉圈越小"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.position = Vector2(-340, -150)
	tip.size = Vector2(680, 110)
	panel.add_child(tip)

	return panel


func _build_over_panel(parent: Control) -> Control:
	var panel := _full_rect(parent)
	_dim_backdrop(panel)

	var title := _make_label(52, Color(1.0, 0.72, 0.72, 0.95))
	title.text = "飘走了"
	_center(title, -180, 500)
	panel.add_child(title)

	_over_score = _make_label(96, Color(1, 1, 1, 0.97))
	_over_score.text = "0"
	_center(_over_score, -70, 500)
	panel.add_child(_over_score)

	var cap := _make_label(22, Color(1, 1, 1, 0.45))
	cap.text = "抵达星球"
	_center(cap, 40, 500)
	panel.add_child(cap)

	_over_new = _make_label(30, Color(1.0, 0.85, 0.4, 0.95))
	_over_new.text = "新纪录"
	_center(_over_new, 90, 500)
	_over_new.visible = false
	panel.add_child(_over_new)

	_over_best = _make_label(26, Color(1, 1, 1, 0.6))
	_over_best.text = "最佳  0"
	_center(_over_best, 140, 500)
	panel.add_child(_over_best)

	var retry := _make_label(30, Color(0.6, 0.85, 1, 0.9))
	retry.text = "点击重试"
	_center(retry, 230, 500)
	panel.add_child(retry)

	panel.visible = false
	return panel


# ------------------------------------------------------------------ world gen

func _reset_world() -> void:
	for p in _planets:
		p.queue_free()
	_planets.clear()
	_trail_pts.clear()
	_trail.points = PackedVector2Array()
	_next_index = 0

	var first := _make_planet(Vector2.ZERO, 74.0)
	_planets.append(first)
	_current = first
	_orbit_angle = -PI / 2.0
	_mode = ShipMode.ORBIT
	_ship.visible = true

	_ensure_planets_ahead()
	_snap_camera_to_ship()


func _make_planet(pos: Vector2, radius: float) -> Planet:
	var p := Planet.new()
	p.position = pos
	p.radius = radius
	p.idx = _next_index
	_next_index += 1
	p.capture_pad = lerpf(38.0, 26.0, _difficulty())
	p.ang_speed = lerpf(3.2, 6.4, _difficulty()) * randf_range(0.9, 1.15)
	p.orbit_dir = 1 if randi_range(0, 1) == 0 else -1
	p.body_color = _planet_body(p.idx)
	p.accent = _accent_color()
	_world.add_child(p)
	return p


func _difficulty() -> float:
	return clampf(_score * 0.035, 0.0, 1.0)


func _accent_color() -> Color:
	# Confined cool hue range (cyan -> blue -> soft violet), low saturation.
	var hue := lerpf(0.52, 0.72, _difficulty())
	return Color.from_hsv(hue, 0.34, 1.0)


func _planet_body(idx: int) -> Color:
	var v := 0.84 + 0.06 * sin(idx * 1.7)
	return Color(v * 0.94, v * 0.96, v, 1.0)


func _ensure_planets_ahead() -> void:
	var last: int = _planets[_planets.size() - 1].idx if _planets.size() > 0 else _current.idx
	while last < _current.idx + 3:
		var from: Planet = _planets[_planets.size() - 1]
		var nxt := _spawn_next(from)
		_planets.append(nxt)
		last = nxt.idx
	_cull_behind()


func _spawn_next(from: Planet) -> Planet:
	var diff := _difficulty()
	var radius := lerpf(68.0, 34.0, diff) + randf_range(-7.0, 7.0)
	radius = maxf(26.0, radius)

	# Centre-to-centre distance grows with difficulty but always stays reachable.
	var min_dist := from.radius + radius + 2.0 * STANDOFF + 40.0
	var dist := maxf(min_dist, lerpf(210.0, 380.0, diff) + randf_range(-15.0, 45.0))

	# Wander within an upward-ish cone so the run keeps climbing.
	var a := -PI / 2.0 + randf_range(-0.95, 0.95)
	var dir := Vector2(cos(a), sin(a))
	var pos := from.position + dir * dist
	return _make_planet(pos, radius)


func _cull_behind() -> void:
	for i in range(_planets.size() - 1, -1, -1):
		if _planets[i].idx < _current.idx - 2:
			_planets[i].queue_free()
			_planets.remove_at(i)


# ------------------------------------------------------------------ flow

func _show_menu() -> void:
	_menu.visible = true
	_over.visible = false
	_score_label.visible = false
	_combo_label.visible = false
	_scrim.visible = false
	var b := _menu.get_node_or_null("BestLine")
	if b:
		b.text = ("最佳  %d" % _best) if _best > 0 else ""


func _start_game() -> void:
	_score = 0
	_combo = 0
	_shake = 0.0
	_reset_world()
	_state = State.PLAY
	_menu.visible = false
	_over.visible = false
	_score_label.visible = true
	_combo_label.visible = true
	_scrim.visible = true
	_update_hud(false)
	Sfx.ui()


func _game_over() -> void:
	_state = State.OVER
	_mode = ShipMode.DEAD
	_over_at = Time.get_ticks_msec()
	var new_best := _score > _best
	if new_best:
		_best = _score
	SaveData.record_run(_score, new_best)

	_over_score.text = str(_score)
	_over_best.text = "最佳  %d" % _best
	_over_new.visible = new_best and _score > 0
	_over.visible = true
	_combo_label.visible = false
	_shake = 16.0
	Sfx.fail()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_tap()
		get_viewport().set_input_as_handled()


func _handle_tap() -> void:
	match _state:
		State.MENU:
			_start_game()
		State.PLAY:
			if _mode == ShipMode.ORBIT:
				_launch()
		State.OVER:
			if Time.get_ticks_msec() - _over_at > 550:
				_start_game()


# ------------------------------------------------------------------ motion

func _launch() -> void:
	var radial := Vector2(cos(_orbit_angle), sin(_orbit_angle))
	var tangent := Vector2(-radial.y, radial.x) * _current.orbit_dir
	_vel = tangent.normalized() * FLY_SPEED
	_mode = ShipMode.FLY
	_fly_dist = 0.0
	_launch_from = _current
	_trail_pts.clear()
	Sfx.launch()


func _update_orbit(delta: float) -> void:
	var orbit_r := _current.radius + STANDOFF
	_orbit_angle += _current.ang_speed * _current.orbit_dir * delta
	var radial := Vector2(cos(_orbit_angle), sin(_orbit_angle))
	_ship.position = _current.position + radial * orbit_r
	var tangent := Vector2(-radial.y, radial.x) * _current.orbit_dir
	_ship.rotation = atan2(tangent.x, -tangent.y)


func _update_fly(delta: float) -> void:
	var step := _vel * delta
	_ship.position += step
	_fly_dist += step.length()
	_ship.rotation = atan2(_vel.x, -_vel.y)

	for p in _planets:
		if p == _launch_from:
			continue
		var d := _ship.position.distance_to(p.position)
		if d <= p.radius + p.capture_pad:
			_capture(p, d)
			return

	var from_launch := _ship.position.distance_to(_launch_from.position) if _launch_from != null else 0.0
	if _fly_dist > MAX_FLIGHT or from_launch > MAX_FLIGHT * 0.8:
		_game_over()


func _capture(p: Planet, _entry_dist: float) -> void:
	_current = p
	p.pulse()

	# Impact parameter: perpendicular distance from the planet centre to the
	# flight line. Small = a clean, central hit -> PERFECT.
	var to_centre := p.position - _ship.position
	var impact := absf(to_centre.cross(_vel.normalized()))
	var perfect := impact <= p.radius * 0.42

	var rel := _ship.position - p.position
	_orbit_angle = rel.angle()
	_mode = ShipMode.ORBIT

	_combo += 1
	_score += 1
	if perfect:
		_score += 1

	_shake = 9.0 if perfect else 5.0
	Sfx.capture(_combo, perfect)
	_update_hud(perfect)
	_ensure_planets_ahead()


func _update_hud(perfect: bool) -> void:
	_score_label.text = str(_score)
	var ac := _accent_color()
	ac.a = 0.95
	_score_label.add_theme_color_override("font_color", ac)
	if _combo > 1:
		_combo_label.text = ("完美  x%d" % _combo) if perfect else ("x%d" % _combo)
		_combo_label.modulate = Color(1, 1, 1, 1)
		_pop_combo()
	else:
		_combo_label.text = "完美" if perfect else ""


func _pop_combo() -> void:
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.scale = Vector2(1.35, 1.35)
	if _combo_tween:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _snap_camera_to_ship() -> void:
	_cam.global_position = _ship.position
	_cam.reset_smoothing()


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("tap"):
		_handle_tap()

	match _mode:
		ShipMode.ORBIT:
			_update_orbit(delta)
		ShipMode.FLY:
			_update_fly(delta)

	_update_trail()
	_update_camera(delta)


func _update_trail() -> void:
	if _mode == ShipMode.DEAD:
		_trail.points = PackedVector2Array()
		return
	_trail_pts.push_front(_ship.position)
	var cap := 16 if _mode == ShipMode.FLY else 10
	while _trail_pts.size() > cap:
		_trail_pts.pop_back()
	_trail.points = PackedVector2Array(_trail_pts)
	var ac := _accent_color()
	ac.a = 0.45
	_trail.default_color = ac


func _update_camera(delta: float) -> void:
	var target: Vector2 = _ship.position if _mode == ShipMode.FLY else _current.position
	# Lead the camera slightly toward where the action is heading.
	if _mode == ShipMode.FLY:
		target += _vel.normalized() * 60.0
	_cam.global_position = target
	_cam.zoom = Vector2.ONE * lerpf(1.0, 0.86, _difficulty())

	if _shake > 0.1:
		_cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - delta * 40.0)
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO
