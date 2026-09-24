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

# Wander sub-state
var wander_target_pixel: Vector2 = Vector2.ZERO
var wander_wait_timer:   float   = 0.0
var is_wandering:        bool    = false

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var farm_grid:    Node2D = get_parent().get_node_or_null("FarmGrid")
@onready var status_label: Label  = $FarmerLabel
@onready var sprite:       ColorRect = $FarmerSprite

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("farmers")
	z_index = 50  # Render worker and selection ring above tiles

	# Initialize worker ID from node name
	if name.begins_with("Farmer_"):
		var parts := name.split("_")
		if parts.size() > 1:
			worker_id = int(parts[1])
	elif name == "Farmer":
		worker_id = 1
	worker_name = "Worker %d" % worker_id

	if sprite:
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_update_status_label()

# ---------------------------------------------------------------------------
# Visual Selection Ring (Drawn above tiles around the worker)
# ---------------------------------------------------------------------------
func _draw() -> void:
	if not is_selected:
		return

	# Glowing tactical gold circle and corner brackets
	var gold := Color(1.0, 0.88, 0.20, 0.95)
	var glow := Color(1.0, 0.95, 0.50, 0.40)
	var center := Vector2(0, 4)

	# Outer subtle glow ring + inner solid ring
	draw_arc(center, 24.0, 0.0, TAU, 36, glow, 4.0)
	draw_arc(center, 22.0, 0.0, TAU, 36, gold, 2.5)

	# 4 RTS tactical brackets
	var b_dist: float = 20.0
	var b_len:  float = 8.0
	# Top-Left
	draw_line(center + Vector2(-b_dist, -b_dist), center + Vector2(-b_dist + b_len, -b_dist), gold, 2.0)
	draw_line(center + Vector2(-b_dist, -b_dist), center + Vector2(-b_dist, -b_dist + b_len), gold, 2.0)
	# Top-Right
	draw_line(center + Vector2(b_dist, -b_dist), center + Vector2(b_dist - b_len, -b_dist), gold, 2.0)
	draw_line(center + Vector2(b_dist, -b_dist), center + Vector2(b_dist, -b_dist + b_len), gold, 2.0)
	# Bottom-Left
	draw_line(center + Vector2(-b_dist, b_dist), center + Vector2(-b_dist + b_len, b_dist), gold, 2.0)
	draw_line(center + Vector2(-b_dist, b_dist), center + Vector2(-b_dist, b_dist - b_len), gold, 2.0)
	# Bottom-Right
	draw_line(center + Vector2(b_dist, b_dist), center + Vector2(b_dist - b_len, b_dist), gold, 2.0)
	draw_line(center + Vector2(b_dist, b_dist), center + Vector2(b_dist, b_dist - b_len), gold, 2.0)

# ---------------------------------------------------------------------------
# Task Assignment API
# ---------------------------------------------------------------------------
## Assigns a task specifically to this worker.
func assign_task(task: Dictionary) -> void:
	assigned_tasks.append(task)
	# If currently idle or wandering, interrupt and execute immediately
	if state == FarmerStateMachine.WorkerState.IDLE:
		_start_next_task()
	else:
		_update_status_label()

func clear_assigned_tasks() -> void:
	assigned_tasks.clear()
	_update_status_label()

func has_task_at(pos: Vector2i, type: String = "") -> bool:
	if target_grid_pos == pos and (type == "" or current_task.get("type", "") == type):
		return true
	for t in assigned_tasks:
		if t.get("position", Vector2i(-1, -1)) == pos:
			if type == "" or t.get("type", "") == type:
				return true
	return false

# ---------------------------------------------------------------------------
# Process — main state dispatch
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
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
		wander_target_pixel   = FarmerMovement.random_wander_pixel(my_gpos, WANDER_RADIUS, farm_grid)
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
	_update_status_label()

# ---------------------------------------------------------------------------
# MOVING — walk toward the task tile
# ---------------------------------------------------------------------------
func _tick_moving(dt: float) -> void:
	var target_pixel: Vector2 = FarmerMovement.grid_to_pixel_center(target_grid_pos, farm_grid)
	var speed_mult: float     = BuildingManager.get_worker_speed_multiplier()
	var move_speed: float     = BASE_MOVE_SPEED * speed_mult

	var arrived: bool = FarmerMovement.step_toward(self, target_pixel, move_speed, dt)
	if arrived:
		state      = FarmerStateMachine.WorkerState.WORKING
		work_timer = WORK_DURATION / speed_mult
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
			_finish_cycle()

		"plant":
			farm_grid.plant_crop(target_grid_pos, current_task.get("crop_type", "palay"))
			_finish_cycle()

		"water":
			farm_grid.water_tile(target_grid_pos, float(current_task.get("amount", 25.0)))
			_finish_cycle()

		"spray_pest":
			farm_grid.spray_pest(target_grid_pos, current_task.get("method", "chemical"))
			_finish_cycle()

		"harvest":
			farm_grid.harvest_tile(target_grid_pos)
			# Walk produce to the depot before returning to next task
			state = FarmerStateMachine.WorkerState.DEPOSITING
			_update_status_label()

		"clear_obstacle":
			farm_grid.clear_obstacle(target_grid_pos)
			_finish_cycle()

		_:
			_finish_cycle()

# ---------------------------------------------------------------------------
# DEPOSITING — walk to the depot at tile (0, 0)
# ---------------------------------------------------------------------------
func _tick_depositing(dt: float) -> void:
	var depot_local: Vector2  = Vector2(FarmerMovement.TILE_PIXEL_SIZE / 2.0, FarmerMovement.TILE_PIXEL_SIZE / 2.0)
	var depot_pixel: Vector2  = farm_grid.to_global(depot_local) if farm_grid else depot_local
	var speed_mult: float     = BuildingManager.get_worker_speed_multiplier()
	var move_speed: float     = BASE_MOVE_SPEED * speed_mult

	if FarmerMovement.step_toward(self, depot_pixel, move_speed, dt):
		_finish_cycle()

# ---------------------------------------------------------------------------
# Shared helpers & Status label
# ---------------------------------------------------------------------------
func _finish_cycle() -> void:
	current_task    = {}
	target_grid_pos = Vector2i(-1, -1)

	if not assigned_tasks.is_empty():
		_start_next_task()
	else:
		state = FarmerStateMachine.WorkerState.IDLE
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

	var prefix: String = "⭐ " if is_selected else ""
	var queue_txt: String = " (+%d)" % assigned_tasks.size() if assigned_tasks.size() > 0 else ""

	status_label.text = "%s%s: %s%s" % [prefix, worker_name, base_txt, queue_txt]

	if is_selected:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	else:
		status_label.remove_theme_color_override("font_color")
