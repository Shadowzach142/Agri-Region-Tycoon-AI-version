# Farmer.gd
# Autonomous AI worker entity with individual task assignment and selection support.
#
# State Machine:  IDLE -> MOVING -> WORKING -> DEPOSITING -> IDLE
# Supports:
#   - Individual click selection & Ctrl+click multi-selection
#   - Dedicated personal task queue (assigned_tasks)
#   - Tactical selection brackets / ring rendered via _draw()
#   - Auto-priority: assigned tasks executed before global unassigned tasks

extends CharacterBody2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const BASE_MOVE_SPEED: float = 180.0
const WORK_DURATION:   float = 1.2       # In-game seconds per action
const WANDER_RADIUS:   int   = 2         # Max tile radius to wander from idle spot

# ---------------------------------------------------------------------------
# Identification & Selection
# ---------------------------------------------------------------------------
var worker_id:   int    = 1
var worker_name: String = "Worker 1"

var is_selected: bool = false:
	set(val):
		is_selected = val
		queue_redraw()
		_update_status_label()

# Dedicated personal task queue assigned by the player
var assigned_tasks: Array = []

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var state:           int        = FarmerStateMachine.WorkerState.IDLE
var current_task:    Dictionary = {}
var target_grid_pos: Vector2i   = Vector2i(-1, -1)
var work_timer:      float      = 0.0
var active_vehicle:  String     = "" # "" | "kuliglig" | "combine_harvester"

# Wander sub-state
var wander_target_pixel: Vector2 = Vector2.ZERO
var wander_wait_timer:   float   = 0.0
var is_wandering:        bool    = false

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var farm_grid:    Node2D     = get_parent().get_node_or_null("FarmGrid")
@onready var status_label: Label      = (get_node_or_null("FarmerLabel") if has_node("FarmerLabel") else find_child("*Label*", true, false)) as Label
@onready var sprite:       CanvasItem = (get_node_or_null("FarmerSprite") if has_node("FarmerSprite") else find_child("*Sprite*", true, false)) as CanvasItem

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("farmers")
	z_index = 10  # Match standing object layer for natural Y-sorting behind/in front of buildings and trees

	# Initialize worker ID from node name
	if name.begins_with("Farmer_"):
		var parts := name.split("_")
		if parts.size() > 1:
			worker_id = int(parts[1])
	elif name == "Farmer":
		worker_id = 1
	worker_name = "Worker %d" % worker_id

	if sprite and sprite is Control:
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	TimeManager.period_changed.connect(func(_p, _n): queue_redraw())
	TimeManager.hour_changed.connect(func(_h): queue_redraw())
	if BuildingManager.has_signal("machinery_updated"):
		BuildingManager.machinery_updated.connect(func(_lvl): _update_vehicle_state())

	_update_status_label()

# ---------------------------------------------------------------------------
# Visual Selection Ring & Mobile Machinery
# ---------------------------------------------------------------------------
func _draw() -> void:
	if active_vehicle == "kuliglig":
		_draw_kuliglig()
	elif active_vehicle == "combine_harvester":
		_draw_combine_harvester()
	else:
		# Ground shadow beneath worker feet in 2:1 isometric projection
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 14.0, Color(0.0, 0.0, 0.0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Handheld kerosene lantern at night (gasera)
		if TimeManager.is_night():
			var lantern_p := Vector2(11, 0)
			draw_circle(lantern_p, 20.0, Color(1.0, 0.85, 0.35, 0.18))
			draw_circle(lantern_p, 9.0, Color(1.0, 0.90, 0.45, 0.40))
			draw_circle(lantern_p, 3.0, Color(1.0, 0.98, 0.75, 0.95))
			draw_rect(Rect2(lantern_p.x - 2.5, lantern_p.y - 1.5, 5.0, 6.0), Color(0.24, 0.18, 0.12, 0.85))
			draw_line(lantern_p + Vector2(0, -6), lantern_p + Vector2(0, -1.5), Color(0.38, 0.30, 0.20, 0.9), 1.2)

	if not is_selected:
		return

	# Glowing tactical gold 2:1 isometric ellipse ring
	var gold := Color(1.0, 0.88, 0.20, 0.95)
	var glow := Color(1.0, 0.95, 0.50, 0.40)
	var center := Vector2(0, 8)

	draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 36, glow, 4.0)
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 36, gold, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4 Tactical brackets
	var b_x: float = 24.0
	var b_y: float = 12.0
	var b_len: float = 6.0
	draw_line(center + Vector2(-b_len, -b_y - 2), center + Vector2(b_len, -b_y - 2), gold, 2.0)
	draw_line(center + Vector2(-b_len, b_y + 2), center + Vector2(b_len, b_y + 2), gold, 2.0)
	draw_line(center + Vector2(-b_x - 2, -b_len * 0.5), center + Vector2(-b_x - 2, b_len * 0.5), gold, 2.0)
	draw_line(center + Vector2(b_x + 2, -b_len * 0.5), center + Vector2(b_x + 2, b_len * 0.5), gold, 2.0)

# ---------------------------------------------------------------------------
# Task Assignment API
# ---------------------------------------------------------------------------
## Assigns a task specifically to this worker.
func assign_task(task: Dictionary) -> void:
	assigned_tasks.append(task)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	# If currently idle or wandering, interrupt and execute immediately
	if state == FarmerStateMachine.WorkerState.IDLE:
		_start_next_task()
	else:
		_update_status_label()

func clear_assigned_tasks() -> void:
	assigned_tasks.clear()
	current_task = {}
	target_grid_pos = Vector2i(-1, -1)
	if state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING:
		state = FarmerStateMachine.WorkerState.IDLE
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	TaskManager.tasks_changed.emit()
	_update_status_label()

func has_task_at(pos: Vector2i, type: String = "") -> bool:
	if not current_task.is_empty() and (type == "" or current_task.get("type", "") == type):
		if _task_covers_tile(current_task, pos):
			return true
	for t in assigned_tasks:
		if type == "" or t.get("type", "") == type:
			if _task_covers_tile(t, pos):
				return true
	return false

func _task_covers_tile(task: Dictionary, pos: Vector2i) -> bool:
	var tpos: Vector2i = task.get("position", Vector2i(-1, -1))
	if tpos == pos:
		return true
	if task.get("type", "") == "plant":
		var c_name: String = task.get("crop_type", "")
		if not c_name.is_empty():
			var c_data: Dictionary = Data.get_crop(c_name)
			var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
			if fp.x > 1 or fp.y > 1:
				if pos.x >= tpos.x and pos.x < tpos.x + fp.x and pos.y >= tpos.y and pos.y < tpos.y + fp.y:
					return true
	return false

# ---------------------------------------------------------------------------
# Process — main state dispatch
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if active_vehicle != "" or is_wandering or state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING:
		queue_redraw()

	var speed_scale: float = TimeManager.get_speed_scale()
	if speed_scale <= 0.0:
		return  # Paused

	var dt: float = delta * speed_scale

	match state:
		FarmerStateMachine.WorkerState.IDLE:       _tick_idle(dt)
		FarmerStateMachine.WorkerState.MOVING:     _tick_moving(dt)
		FarmerStateMachine.WorkerState.WORKING:    _tick_working(dt)
		FarmerStateMachine.WorkerState.DEPOSITING: _tick_depositing(dt)

# ---------------------------------------------------------------------------
# IDLE — check for tasks, otherwise wander
# ---------------------------------------------------------------------------
func _tick_idle(dt: float) -> void:
	# 1. Check personal assigned tasks first
	if not assigned_tasks.is_empty():
		_start_next_task()
		return

	# 2. Check global task queue if no personal tasks
	var my_grid_pos: Vector2i = FarmerMovement.pixel_to_grid(global_position, farm_grid)
	var task: Dictionary = TaskManager.get_next_task_for_farmer(my_grid_pos)
	if not task.is_empty():
		_execute_task(task)
		return

	# 3. No task — wander slowly
	if wander_wait_timer > 0.0:
		wander_wait_timer -= dt
		_update_status_label()
		return

	if not is_wandering:
		var my_gpos: Vector2i = FarmerMovement.pixel_to_grid(global_position, farm_grid)
		var target_pos := my_gpos
		for _attempt in range(6):
			var offset := Vector2i(randi_range(-WANDER_RADIUS, WANDER_RADIUS), randi_range(-WANDER_RADIUS, WANDER_RADIUS))
			var cand := my_gpos + offset
			if farm_grid and farm_grid.has_method("is_tile_unlocked") and farm_grid.is_tile_unlocked(cand):
				target_pos = cand
				break
		wander_target_pixel   = FarmerMovement.grid_to_pixel_center(target_pos, farm_grid)
		is_wandering          = true

	_update_status_label()
	var wander_speed: float = (BASE_MOVE_SPEED * 0.5) * BuildingManager.get_worker_speed_multiplier()
	var arrived: bool = FarmerMovement.step_toward(self, wander_target_pixel, wander_speed, dt)
	if arrived:
		is_wandering      = false
		wander_wait_timer = randf_range(1.5, 4.0)

# ---------------------------------------------------------------------------
# Task Execution Transitions
# ---------------------------------------------------------------------------
func _start_next_task() -> void:
	if assigned_tasks.is_empty():
		return
	var task: Dictionary = assigned_tasks.pop_front()
	_execute_task(task)

func _execute_task(task: Dictionary) -> void:
	is_wandering    = false
	current_task    = task
	target_grid_pos = task.get("position", Vector2i.ZERO)
	state           = FarmerStateMachine.WorkerState.MOVING
	_update_vehicle_state()
	_update_status_label()
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	TaskManager.tasks_changed.emit()
	AudioManager.play_farmer("assign")

# ---------------------------------------------------------------------------
# MOVING — walk toward the task tile
# ---------------------------------------------------------------------------
func _tick_moving(dt: float) -> void:
	var target_pixel: Vector2 = FarmerMovement.grid_to_pixel_center(target_grid_pos, farm_grid)
	var speed_mult: float     = BuildingManager.get_worker_speed_multiplier()
	var move_speed: float     = BASE_MOVE_SPEED * speed_mult

	var arrived: bool = FarmerMovement.step_toward(self, target_pixel, move_speed, dt)
	if arrived:
		state = FarmerStateMachine.WorkerState.WORKING
		var dur: float = WORK_DURATION
		var task_type: String = current_task.get("type", "")
		if task_type == "harvest" and farm_grid != null:
			var tile: FarmTile = farm_grid.get_tile(target_grid_pos)
			if tile != null:
				var c_type: String = tile.crop_type
				if tile.multi_tile_root_pos != Vector2i(-1, -1):
					var root_tile: FarmTile = farm_grid.get_tile(tile.multi_tile_root_pos)
					if root_tile != null:
						c_type = root_tile.crop_type
				if not c_type.is_empty():
					var c_data: Dictionary = Data.get_crop(c_type)
					dur = float(c_data.get("harvest_duration", WORK_DURATION))
		work_timer = dur / speed_mult
		_update_status_label()

# ---------------------------------------------------------------------------
# WORKING — count down the action timer then execute
# ---------------------------------------------------------------------------
func _tick_working(dt: float) -> void:
	work_timer -= dt
	if work_timer <= 0.0:
		_complete_task()

func _complete_task() -> void:
	if farm_grid == null:
		_finish_cycle()
		return

	var task_type: String = current_task.get("type", "")

	match task_type:
		"plow":
			farm_grid.plow_tile(target_grid_pos)
			AudioManager.play_farmer("plow")
			_finish_cycle()

		"plant":
			farm_grid.plant_crop(target_grid_pos, current_task.get("crop_type", "palay"))
			AudioManager.play_farmer("plant")
			_finish_cycle()

		"water":
			farm_grid.water_tile(target_grid_pos, float(current_task.get("amount", 25.0)))
			AudioManager.play_farmer("water")
			_finish_cycle()

		"spray_pest":
			farm_grid.spray_pest(target_grid_pos, current_task.get("method", "chemical"))
			AudioManager.play_farmer("spray")
			_finish_cycle()

		"harvest":
			farm_grid.harvest_tile(target_grid_pos)
			AudioManager.play_farmer("harvest")
			# Walk produce to the depot before returning to next task
			state = FarmerStateMachine.WorkerState.DEPOSITING
			if BuildingManager.has_combine_harvester():
				active_vehicle = "combine_harvester"
			_update_status_label()

		"clear_obstacle":
			farm_grid.clear_obstacle(target_grid_pos)
			AudioManager.play_farmer("chop")
			_finish_cycle()

		_:
			_finish_cycle()

# ---------------------------------------------------------------------------
# DEPOSITING — walk to the storage depot (Bodega / Silo)
# ---------------------------------------------------------------------------
func _tick_depositing(dt: float) -> void:
	var depot_gpos := Vector2i(0, 0)
	var storage_b = BuildingManager.get_first_storage_building()
	if storage_b:
		# Entrance is right at the front-center of the storage building
		depot_gpos = storage_b.grid_pos + Vector2i(1, storage_b.footprint.y)
	var depot_pixel: Vector2  = FarmerMovement.grid_to_pixel_center(depot_gpos, farm_grid)
	var speed_mult: float     = BuildingManager.get_worker_speed_multiplier()
	var move_speed: float     = BASE_MOVE_SPEED * speed_mult

	if FarmerMovement.step_toward(self, depot_pixel, move_speed, dt):
		_finish_cycle()

# ---------------------------------------------------------------------------
# Shared helpers, Machinery & Status label
# ---------------------------------------------------------------------------
func _update_vehicle_state() -> void:
	var task_type: String = current_task.get("type", "")
	if task_type == "plow" and BuildingManager.has_kuliglig():
		active_vehicle = "kuliglig"
	elif (task_type == "harvest" or (state == FarmerStateMachine.WorkerState.DEPOSITING and active_vehicle == "combine_harvester")) and BuildingManager.has_combine_harvester():
		active_vehicle = "combine_harvester"
	elif state == FarmerStateMachine.WorkerState.IDLE or is_wandering:
		active_vehicle = ""
	elif task_type != "plow" and task_type != "harvest" and state != FarmerStateMachine.WorkerState.DEPOSITING:
		active_vehicle = ""

	if sprite:
		if active_vehicle == "kuliglig":
			sprite.position = Vector2(6, -10)
		elif active_vehicle == "combine_harvester":
			sprite.position = Vector2(2, -16)
		else:
			sprite.position = Vector2.ZERO
	queue_redraw()

func _finish_cycle() -> void:
	current_task    = {}
	target_grid_pos = Vector2i(-1, -1)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	TaskManager.tasks_changed.emit()

	if not assigned_tasks.is_empty():
		_start_next_task()
	else:
		state = FarmerStateMachine.WorkerState.IDLE
		_update_vehicle_state()
		_update_status_label()

func _update_status_label() -> void:
	if status_label == null:
		return

	var base_txt: String = ""
	match state:
		FarmerStateMachine.WorkerState.IDLE:
			base_txt = FarmerStateMachine.wandering_label() if is_wandering else FarmerStateMachine.ready_label()
		FarmerStateMachine.WorkerState.MOVING:
			base_txt = FarmerStateMachine.moving_label()
		FarmerStateMachine.WorkerState.WORKING:
			base_txt = FarmerStateMachine.work_label(current_task.get("type", ""))
		FarmerStateMachine.WorkerState.DEPOSITING:
			base_txt = FarmerStateMachine.depositing_label()

	var v_prefix: String = ""
	if active_vehicle == "kuliglig":
		v_prefix = "🚜 [Kuliglig] "
	elif active_vehicle == "combine_harvester":
		v_prefix = "🚜 [Harvester] "

	var prefix: String = "⭐ " if is_selected else ""
	var queue_txt: String = " (+%d)" % assigned_tasks.size() if assigned_tasks.size() > 0 else ""

	status_label.text = "%s%s: %s%s%s" % [prefix, worker_name, v_prefix, base_txt, queue_txt]

	if is_selected:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	else:
		status_label.remove_theme_color_override("font_color")

func _draw_kuliglig() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var is_moving: bool = (state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING or state == FarmerStateMachine.WorkerState.DEPOSITING)

	# 1. Broad ground shadow in 2:1 isometric projection
	draw_set_transform(Vector2(-4, 10), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var wheel_spin: float = (global_position.x + global_position.y) * 0.12 if is_moving else 0.0
	if state == FarmerStateMachine.WorkerState.WORKING:
		wheel_spin = t * 14.0

	# 2. Sulky cart / footboard where farmer stands
	var sulky_poly := PackedVector2Array([
		Vector2(2, 6), Vector2(18, 14), Vector2(16, 20), Vector2(0, 12)
	])
	draw_colored_polygon(sulky_poly, Color(0.32, 0.35, 0.38))
	draw_polyline(sulky_poly, Color(0.18, 0.20, 0.22), 1.5)

	# Hitch connecting tongue
	draw_line(Vector2(-6, 2), Vector2(8, 10), Color(0.25, 0.28, 0.30), 3.0)

	# 3. Two Large Cleated Iron Cage Wheels (Philippine Rice-Paddy Style)
	var left_wheel_p := Vector2(-16, 6)
	var right_wheel_p := Vector2(4, 16)

	for wp: Vector2 in [left_wheel_p, right_wheel_p]:
		draw_circle(wp, 8.0, Color(0.18, 0.20, 0.22))
		draw_circle(wp, 6.0, Color(0.38, 0.42, 0.46))
		draw_circle(wp, 2.5, Color(0.12, 0.14, 0.16))
		for i in range(6):
			var a: float = wheel_spin + float(i) * TAU / 6.0
			var c_p1: Vector2 = wp + Vector2(cos(a) * 5.0, sin(a) * 5.0)
			var c_p2: Vector2 = wp + Vector2(cos(a) * 9.5, sin(a) * 9.5)
			draw_line(c_p1, c_p2, Color(0.65, 0.70, 0.76), 1.5)

	# 4. Red Diesel Engine Block (Kubota single cylinder)
	var eng_p := Vector2(-10, -2)
	var eng_poly := PackedVector2Array([
		eng_p + Vector2(-9, 4), eng_p + Vector2(9, 4),
		eng_p + Vector2(9, -8), eng_p + Vector2(-9, -8)
	])
	draw_colored_polygon(eng_poly, Color(0.85, 0.20, 0.16))
	draw_polyline(eng_poly, Color(0.45, 0.10, 0.08), 1.5)

	# Spinning belt flywheel
	var fly_p := eng_p + Vector2(7, -2)
	draw_circle(fly_p, 4.0, Color(0.30, 0.34, 0.38))
	draw_line(fly_p, fly_p + Vector2(cos(t * 18.0) * 3.5, sin(t * 18.0) * 3.5), Color(0.80, 0.85, 0.90), 1.2)

	# Front rotary plow blades (churning soil when working)
	var plow_p := Vector2(-22, 10)
	draw_line(eng_p + Vector2(-6, 2), plow_p, Color(0.28, 0.30, 0.32), 2.5)
	draw_circle(plow_p, 3.5, Color(0.45, 0.48, 0.52))
	if state == FarmerStateMachine.WorkerState.WORKING:
		for s in range(3):
			var dust_p := plow_p + Vector2(-randf_range(2, 10), -randf_range(1, 6))
			draw_circle(dust_p, 1.5, Color(0.36, 0.24, 0.14, 0.85))

	# Chrome vertical exhaust pipe & diesel smoke
	var exh_p := eng_p + Vector2(-5, -8)
	draw_line(exh_p, exh_p + Vector2(0, -10), Color(0.75, 0.80, 0.86), 2.0)
	draw_circle(exh_p + Vector2(0, -10), 1.5, Color(0.40, 0.45, 0.50))
	if is_moving:
		var st: float = fmod(t * 3.5, 1.0)
		var sp := exh_p + Vector2(-1.0 - st * 8.0, -11.0 - st * 12.0)
		draw_circle(sp, 2.0 + st * 3.5, Color(0.55, 0.58, 0.62, 0.45 * (1.0 - st)))

	# Handlebars extending to the farmer's hands
	draw_line(eng_p + Vector2(4, -4), Vector2(6, -2), Color(0.20, 0.22, 0.25), 2.0)
	draw_line(eng_p + Vector2(-2, -6), Vector2(2, -6), Color(0.20, 0.22, 0.25), 2.0)

	# Headlight (at night)
	if TimeManager.is_night():
		var hl_p := eng_p + Vector2(-9, 0)
		draw_circle(hl_p, 2.5, Color(1.0, 0.95, 0.60))
		var beam := PackedVector2Array([
			hl_p, hl_p + Vector2(-28, 4), hl_p + Vector2(-24, 18)
		])
		draw_colored_polygon(beam, Color(1.0, 0.95, 0.60, 0.18))

func _draw_combine_harvester() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var is_moving: bool = (state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING or state == FarmerStateMachine.WorkerState.DEPOSITING)

	# 1. Heavy isometric ground shadow
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 32.0, Color(0.0, 0.0, 0.0, 0.40))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Caterpillar Tracks (Twin Rubber Cleated Treads)
	var left_track := PackedVector2Array([
		Vector2(-24, 2), Vector2(0, 14), Vector2(-4, 22), Vector2(-28, 10)
	])
	draw_colored_polygon(left_track, Color(0.12, 0.14, 0.16))
	draw_polyline(left_track, Color(0.06, 0.08, 0.10), 1.5)

	var right_track := PackedVector2Array([
		Vector2(2, -4), Vector2(26, 8), Vector2(22, 16), Vector2(-2, 4)
	])
	draw_colored_polygon(right_track, Color(0.16, 0.18, 0.20))
	draw_polyline(right_track, Color(0.08, 0.10, 0.12), 1.5)

	# Road wheels inside tracks
	for i in range(3):
		var pA := Vector2(-24, 6).lerp(Vector2(-2, 17), float(i) / 2.0)
		draw_circle(pA, 3.5, Color(0.85, 0.72, 0.18))
		draw_circle(pA, 1.5, Color(0.12, 0.14, 0.16))

	# 3. Main Industrial Harvester Chassis Body (Green & Yellow)
	var body_poly := PackedVector2Array([
		Vector2(-18, 2), Vector2(16, -6), Vector2(16, -22), Vector2(-18, -14)
	])
	draw_colored_polygon(body_poly, Color(0.20, 0.52, 0.25))
	draw_polyline(body_poly, Color(0.10, 0.28, 0.12), 1.5)

	# Side yellow branding stripe
	draw_line(Vector2(-16, -6), Vector2(14, -12), Color(0.95, 0.82, 0.18), 2.5)

	# 4. Front Crop Header & Rotating Reel
	var header_p := Vector2(-28, 8)
	draw_line(Vector2(-14, 4), header_p, Color(0.18, 0.40, 0.22), 4.0)

	# Rotating yellow tine reel bar
	var reel_rot: float = t * 10.0 if state == FarmerStateMachine.WorkerState.WORKING else 0.0
	var reel_center := header_p + Vector2(-6, -2)
	draw_circle(reel_center, 6.0, Color(0.92, 0.78, 0.15))
	draw_circle(reel_center, 4.0, Color(0.20, 0.22, 0.25))
	for a in range(4):
		var ang: float = reel_rot + float(a) * PI / 2.0
		var r_end := reel_center + Vector2(cos(ang) * 9.0, sin(ang) * 9.0)
		draw_line(reel_center, r_end, Color(0.95, 0.85, 0.20), 1.5)
		draw_line(r_end, r_end + Vector2(-2, 4), Color(0.60, 0.50, 0.10), 1.2)

	if state == FarmerStateMachine.WorkerState.WORKING:
		for s in range(3):
			var sp := reel_center + Vector2(randf_range(-4, 4), -randf_range(2, 8))
			draw_circle(sp, 1.2, Color(1.0, 0.88, 0.25, 0.85))

	# 5. Elevated Grain Hopper & Unloading Auger Pipe
	var hopper_p := Vector2(8, -18)
	draw_rect(Rect2(hopper_p.x - 6, hopper_p.y - 6, 12, 10), Color(0.85, 0.70, 0.15))
	draw_rect(Rect2(hopper_p.x - 6, hopper_p.y - 6, 12, 10), Color(0.40, 0.30, 0.08), false, 1.2)

	var auger_start := hopper_p + Vector2(2, -4)
	var auger_end := auger_start + Vector2(16, -14)
	draw_line(auger_start, auger_end, Color(0.85, 0.70, 0.15), 3.5)
	draw_circle(auger_end, 2.5, Color(0.25, 0.28, 0.32))

	# 6. Overhead Driver Roll-Bar Canopy Frame
	var roll_bar := PackedVector2Array([
		Vector2(-6, -10), Vector2(-6, -26), Vector2(8, -30), Vector2(8, -14)
	])
	draw_polyline(roll_bar, Color(0.85, 0.75, 0.18), 2.0)
	var sunshade := PackedVector2Array([
		Vector2(-8, -26), Vector2(10, -31), Vector2(14, -28), Vector2(-4, -23)
	])
	draw_colored_polygon(sunshade, Color(0.92, 0.94, 0.96))
	draw_polyline(sunshade, Color(0.45, 0.48, 0.52), 1.2)

	# Vertical exhaust pipe & diesel smoke
	var exh_p := Vector2(12, -22)
	draw_line(exh_p, exh_p + Vector2(0, -12), Color(0.70, 0.75, 0.80), 2.5)
	if is_moving:
		var st: float = fmod(t * 3.0, 1.0)
		var sp := exh_p + Vector2(-1.0 - st * 6.0, -14.0 - st * 16.0)
		draw_circle(sp, 2.5 + st * 4.5, Color(0.50, 0.52, 0.55, 0.40 * (1.0 - st)))

	# Night Work Floodlights
	if TimeManager.is_night():
		var hl1 := Vector2(-22, 2)
		draw_circle(hl1, 3.0, Color(1.0, 0.95, 0.65))
		var beam := PackedVector2Array([
			hl1, hl1 + Vector2(-36, 6), hl1 + Vector2(-28, 26)
		])
		draw_colored_polygon(beam, Color(1.0, 0.95, 0.65, 0.22))
