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
var carried_crop:    String     = "" # crop type currently being carried to storage depot

# Wander sub-state
var wander_target_pixel: Vector2 = Vector2.ZERO
var wander_wait_timer:   float   = 0.0
var is_wandering:        bool    = false

# ---------------------------------------------------------------------------
# Animation State & Textures (32x32 retro pixel farmer)
# ---------------------------------------------------------------------------
const ANIM_FRAME_DURATION: float = 0.16 # Base seconds per animation frame

var _anim_timer:       float  = 0.0
var _anim_frame_idx:   int    = 0
var _current_anim:     String = "idle"
var _is_facing_left:   bool   = false

const ANIM_FRAMES: Dictionary = {
	"idle": [
		preload("res://assets/sprites/farmer/idle.png")
	],
	"walk": [
		preload("res://assets/sprites/farmer/walk_0.png"),
		preload("res://assets/sprites/farmer/walk_1.png"),
		preload("res://assets/sprites/farmer/walk_2.png"),
		preload("res://assets/sprites/farmer/walk_3.png")
	],
	"till": [
		preload("res://assets/sprites/farmer/till_0.png"),
		preload("res://assets/sprites/farmer/till_1.png"),
		preload("res://assets/sprites/farmer/till_2.png"),
		preload("res://assets/sprites/farmer/till_3.png")
	],
	"harvest": [
		preload("res://assets/sprites/farmer/harvest_0.png"),
		preload("res://assets/sprites/farmer/harvest_1.png"),
		preload("res://assets/sprites/farmer/harvest_2.png"),
		preload("res://assets/sprites/farmer/harvest_3.png")
	]
}

# ---------------------------------------------------------------------------
# Visual Variants (Clothes, Hat, Skin Tones)
# ---------------------------------------------------------------------------
const NUM_VARIANTS: int = 8

const VARIANT_NAMES: Array[String] = [
	"Denim Blue",    # Variant 0 (Classic Starter)
	"Ruby Red",      # Variant 1
	"Forest Green",  # Variant 2
	"Indigo Violet", # Variant 3
	"Harvest Amber", # Variant 4
	"Tropical Teal", # Variant 5
	"Coral Rose",    # Variant 6
	"Khaki Earth"    # Variant 7
]

const VARIANT_DIRS: Array[String] = [
	"variant_0",
	"variant_1",
	"variant_2",
	"variant_3",
	"variant_4",
	"variant_5",
	"variant_6",
	"variant_7"
]

static var _variant_frames_cache: Dictionary = {}

@export var variant_id: int = 0:
	set(val):
		variant_id = posmod(val, NUM_VARIANTS)
		_current_frames = get_frames_for_variant(variant_id)
		_update_sprite_texture()

var _current_frames: Dictionary = {}

static func get_frames_for_variant(v_id: int) -> Dictionary:
	var v_idx: int = posmod(v_id, NUM_VARIANTS)
	if _variant_frames_cache.has(v_idx):
		return _variant_frames_cache[v_idx]

	if v_idx == 0:
		_variant_frames_cache[0] = ANIM_FRAMES
		return ANIM_FRAMES

	var dir_name: String = VARIANT_DIRS[v_idx]
	var base_path: String = "res://assets/sprites/farmer/variants/%s/" % dir_name

	var f_dict: Dictionary = {
		"idle": [
			load(base_path + "idle.png")
		],
		"walk": [
			load(base_path + "walk_0.png"),
			load(base_path + "walk_1.png"),
			load(base_path + "walk_2.png"),
			load(base_path + "walk_3.png")
		],
		"till": [
			load(base_path + "till_0.png"),
			load(base_path + "till_1.png"),
			load(base_path + "till_2.png"),
			load(base_path + "till_3.png")
		],
		"harvest": [
			load(base_path + "harvest_0.png"),
			load(base_path + "harvest_1.png"),
			load(base_path + "harvest_2.png"),
			load(base_path + "harvest_3.png")
		]
	}
	_variant_frames_cache[v_idx] = f_dict
	return f_dict

func set_variant(new_variant: int) -> void:
	variant_id = new_variant

func cycle_variant() -> void:
	variant_id = (variant_id + 1) % NUM_VARIANTS

func get_variant_name() -> String:
	return VARIANT_NAMES[variant_id]

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
	z_index = 10  # Ground object layer (Z=10); Y-sorted with crops, other workers, and buildings

	# Initialize worker ID from node name
	if name.begins_with("Farmer_"):
		var parts := name.split("_")
		if parts.size() > 1:
			worker_id = int(parts[1])
	elif name == "Farmer":
		worker_id = 1
	worker_name = "Worker %d" % worker_id

	# Set default visual variant based on worker_id (Worker 1 = variant 0, Worker 2 = variant 1, etc.)
	if variant_id == 0 and worker_id > 1:
		variant_id = (worker_id - 1) % NUM_VARIANTS
	else:
		_current_frames = get_frames_for_variant(variant_id)

	if sprite and sprite is Control:
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprite and sprite is Sprite2D:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		sprite.position = Vector2(0.0, -20.0)
		_update_sprite_texture()
	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_label.z_index = 15  # Keep worker status tag always visible and readable above crops
		status_label.offset_left = -50.0
		status_label.offset_right = 50.0
		status_label.offset_top = -64.0
		status_label.offset_bottom = -46.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_constant_override("outline_size", 3)
		status_label.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.05, 0.95))
		status_label.add_theme_font_size_override("font_size", 13)

	TimeManager.period_changed.connect(func(_p, _n): queue_redraw())
	TimeManager.hour_changed.connect(func(_h): queue_redraw())
	if BuildingManager.has_signal("bayanihan_updated"):
		BuildingManager.bayanihan_updated.connect(func(_lvl): _update_status_label(); queue_redraw())

	_update_status_label()

func _unhandled_input(event: InputEvent) -> void:
	if not is_selected:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			cycle_variant()
			AudioManager.play_farmer("select")
			if TaskManager.get_selected_farmers().size() <= 1:
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Visual Selection Ring & Ground Rendering
# ---------------------------------------------------------------------------
func _draw() -> void:
	# Ground shadow beneath worker feet in 2:1 isometric projection
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Handheld kerosene lantern at night (gasera)
	if TimeManager.is_night():
		var lantern_p := Vector2(-11.0 if _is_facing_left else 11.0, 0.0)
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

func cancel_current_task() -> Dictionary:
	var cancelled := current_task.duplicate()
	current_task = {}
	target_grid_pos = Vector2i(-1, -1)
	work_timer = 0.0
	is_wandering = false
	if state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING:
		state = FarmerStateMachine.WorkerState.IDLE
		_play_anim("idle", 0.0)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	TaskManager.tasks_changed.emit()
	_update_status_label()
	return cancelled

func clear_assigned_tasks() -> Array:
	var cancelled: Array = []
	if not current_task.is_empty():
		cancelled.append(current_task.duplicate())
	cancelled.append_array(assigned_tasks)
	assigned_tasks.clear()
	current_task = {}
	target_grid_pos = Vector2i(-1, -1)
	work_timer = 0.0
	is_wandering = false
	if state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING:
		state = FarmerStateMachine.WorkerState.IDLE
		_play_anim("idle", 0.0)
	if farm_grid and farm_grid.drag_overlay:
		farm_grid.drag_overlay.queue_redraw()
	TaskManager.tasks_changed.emit()
	_update_status_label()
	return cancelled

func cancel_task_at(pos: Vector2i, type: String = "") -> Dictionary:
	var cancelled: Dictionary = {}
	if not current_task.is_empty() and (type == "" or current_task.get("type", "") == type):
		if _task_covers_tile(current_task, pos):
			cancelled = cancel_current_task()
			if not assigned_tasks.is_empty():
				_start_next_task()
			return cancelled
	for i in range(assigned_tasks.size()):
		var t: Dictionary = assigned_tasks[i]
		if type == "" or t.get("type", "") == type:
			if _task_covers_tile(t, pos):
				cancelled = assigned_tasks[i]
				assigned_tasks.remove_at(i)
				if farm_grid and farm_grid.drag_overlay:
					farm_grid.drag_overlay.queue_redraw()
				TaskManager.tasks_changed.emit()
				_update_status_label()
				return cancelled
	return {}

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
	if is_wandering or state == FarmerStateMachine.WorkerState.MOVING or state == FarmerStateMachine.WorkerState.WORKING:
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
		_play_anim("idle", dt)
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
	if is_wandering:
		_play_anim("walk", dt)
		if velocity.x < -1.0:
			_set_facing(true)
		elif velocity.x > 1.0:
			_set_facing(false)

	if arrived:
		is_wandering      = false
		wander_wait_timer = randf_range(1.5, 4.0)
		_play_anim("idle", dt)

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
	_play_anim("walk", dt)
	if velocity.x < -1.0:
		_set_facing(true)
	elif velocity.x > 1.0:
		_set_facing(false)

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

	# Face the task tile
	var target_pixel: Vector2 = FarmerMovement.grid_to_pixel_center(target_grid_pos, farm_grid)
	if target_pixel.x < global_position.x - 2.0:
		_set_facing(true)
	elif target_pixel.x > global_position.x + 2.0:
		_set_facing(false)

	var task_type: String = current_task.get("type", "")
	match task_type:
		"harvest":
			_play_anim("harvest", dt)
		"plow", "clear_obstacle":
			_play_anim("till", dt)
		"plant", "water", "spray_pest":
			_play_anim("harvest", dt)
		_:
			_play_anim("till", dt)

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
			var harvested_crop: String = ""
			if farm_grid != null:
				var t: FarmTile = farm_grid.get_tile(target_grid_pos)
				if t != null:
					harvested_crop = t.crop_type
					if t.multi_tile_root_pos != Vector2i(-1, -1):
						var rt: FarmTile = farm_grid.get_tile(t.multi_tile_root_pos)
						if rt != null:
							harvested_crop = rt.crop_type
			carried_crop = harvested_crop
			farm_grid.harvest_tile(target_grid_pos)
			AudioManager.play_farmer("harvest")
			# Walk produce to the assigned storage depot before returning to next task
			state = FarmerStateMachine.WorkerState.DEPOSITING
			_update_status_label()

		"clear_obstacle":
			farm_grid.clear_obstacle(target_grid_pos)
			AudioManager.play_farmer("chop")
			_finish_cycle()

		_:
			_finish_cycle()

# ---------------------------------------------------------------------------
# DEPOSITING — walk to the assigned storage depot (Bodega / Cold Storage / Silo)
# ---------------------------------------------------------------------------
func _tick_depositing(dt: float) -> void:
	var depot_gpos := Vector2i(0, 0)
	var storage_b: Node = null
	if not carried_crop.is_empty():
		storage_b = BuildingManager.get_best_storage_for_crop(carried_crop, 100)
	if storage_b == null:
		storage_b = BuildingManager.get_first_storage_building()

	if storage_b and is_instance_valid(storage_b):
		# Entrance is right at the front-center of the assigned storage building
		depot_gpos = storage_b.grid_pos + Vector2i(1, storage_b.footprint.y)
	var depot_pixel: Vector2  = FarmerMovement.grid_to_pixel_center(depot_gpos, farm_grid)
	var speed_mult: float     = BuildingManager.get_worker_speed_multiplier()
	var move_speed: float     = BASE_MOVE_SPEED * speed_mult

	var arrived: bool = FarmerMovement.step_toward(self, depot_pixel, move_speed, dt)
	_play_anim("walk", dt)
	if velocity.x < -1.0:
		_set_facing(true)
	elif velocity.x > 1.0:
		_set_facing(false)

	if arrived:
		carried_crop = ""
		_finish_cycle()

# ---------------------------------------------------------------------------
# Shared helpers & Status label
# ---------------------------------------------------------------------------
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
		_play_anim("idle", 0.0)
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

	var queue_txt: String = " (+%d)" % assigned_tasks.size() if assigned_tasks.size() > 0 else ""

	status_label.text = "%s%s" % [base_txt, queue_txt]

	if is_selected:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	else:
		status_label.remove_theme_color_override("font_color")

## Returns true if the farmer has completed all tasks and is idle
func is_idle_worker() -> bool:
	return state == FarmerStateMachine.WorkerState.IDLE and assigned_tasks.is_empty() and current_task.is_empty()

# ---------------------------------------------------------------------------
# Animation Helpers
# ---------------------------------------------------------------------------
func _play_anim(anim_name: String, dt: float) -> void:
	if _current_frames.is_empty():
		_current_frames = get_frames_for_variant(variant_id)

	if not _current_frames.has(anim_name):
		anim_name = "idle"

	if _current_anim != anim_name:
		_current_anim = anim_name
		_anim_frame_idx = 0
		_anim_timer = 0.0
		_update_sprite_texture()

	var frames: Array = _current_frames[_current_anim]
	if frames.size() <= 1:
		return

	var speed_mult: float = BuildingManager.get_worker_speed_multiplier()
	var frame_dur: float = max(0.06, ANIM_FRAME_DURATION / speed_mult)
	_anim_timer += dt
	if _anim_timer >= frame_dur:
		_anim_timer -= frame_dur
		_anim_frame_idx = (_anim_frame_idx + 1) % frames.size()
		_update_sprite_texture()

func _update_sprite_texture() -> void:
	if sprite is Sprite2D:
		if _current_frames.is_empty():
			_current_frames = get_frames_for_variant(variant_id)
		var frames: Array = _current_frames.get(_current_anim, _current_frames.get("idle", ANIM_FRAMES["idle"]))
		var idx: int = clamp(_anim_frame_idx, 0, frames.size() - 1)
		sprite.texture = frames[idx]

func _set_facing(facing_left: bool) -> void:
	if _is_facing_left == facing_left:
		return
	_is_facing_left = facing_left
	if sprite is Sprite2D:
		sprite.flip_h = _is_facing_left
	queue_redraw()

