# Farmer.gd
# Autonomous AI worker entity.
# State Machine: IDLE -> MOVING -> WORKING -> DEPOSITING -> IDLE.
# Fetches jobs from TaskManager, walks to the target grid tile, performs actions with a timer,
# deposits harvested yield into storage, and displays an overhead status label.

extends CharacterBody2D

enum WorkerState {IDLE, MOVING, WORKING, DEPOSITING}

const BASE_MOVE_SPEED: float = 180.0
const TILE_PIXEL_SIZE: int = 64
const WORK_DURATION: float = 1.2 # In-game seconds to perform an action

var state: int = WorkerState.IDLE
var target_grid_pos: Vector2i = Vector2i(-1, -1)
var current_task: Dictionary = {}
var work_timer: float = 0.0

@onready var farm_grid: Node2D = get_parent().get_node_or_null("FarmGrid")
@onready var status_label: Label = $FarmerLabel
@onready var sprite: ColorRect = $FarmerSprite

func _ready() -> void:
	_update_status_display("🧑‍🌾 Ready")

func _process(delta: float) -> void:
	var speed_scale: float = TimeManager.get_speed_scale()
	if speed_scale <= 0.0:
		return # Paused

	var effective_delta: float = delta * speed_scale

	match state:
		WorkerState.IDLE:
			_fetch_task()
		WorkerState.MOVING:
			_move_towards_tile(effective_delta)
		WorkerState.WORKING:
			_process_work(effective_delta)
		WorkerState.DEPOSITING:
			_move_towards_depot(effective_delta)

func _fetch_task() -> void:
	var current_gpos: Vector2i = _pixel_to_grid(global_position)
	var task: Dictionary = TaskManager.get_next_task_for_farmer(current_gpos)
	if task.is_empty():
		_update_status_display("🧑‍🌾 Idle")
		return

	current_task = task
	target_grid_pos = task.get("position", Vector2i.ZERO)
	state = WorkerState.MOVING
	_update_status_display("🏃 Moving...")

func _move_towards_tile(delta: float) -> void:
	var target_pixel: Vector2 = _grid_to_pixel_center(target_grid_pos)
	var dir: Vector2 = target_pixel - global_position
	var dist: float = dir.length()
	var step: float = BASE_MOVE_SPEED * delta

	if dist <= step or dist < 4.0:
		global_position = target_pixel
		state = WorkerState.WORKING
		work_timer = WORK_DURATION
		_update_work_status()
	else:
		velocity = dir.normalized() * BASE_MOVE_SPEED
		global_position += velocity * delta

func _update_work_status() -> void:
	var type: String = current_task.get("type", "")
	match type:
		"plow": _update_status_display("⛏️ Plowing...")
		"plant": _update_status_display("🌱 Planting...")
		"water": _update_status_display("💧 Watering...")
		"spray_pest": _update_status_display("🧪 Spraying...")
		"harvest": _update_status_display("🧺 Harvesting...")
		_: _update_status_display("⚙️ Working...")

func _process_work(delta: float) -> void:
	work_timer -= delta
	if work_timer <= 0.0:
		_complete_task()

func _complete_task() -> void:
	if farm_grid == null:
		_finish_work_cycle()
		return

	var type: String = current_task.get("type", "")
	match type:
		"plow":
			farm_grid.plow_tile(target_grid_pos)
			_finish_work_cycle()
		"plant":
			var crop: String = current_task.get("crop_type", "palay")
			farm_grid.plant_crop(target_grid_pos, crop)
			_finish_work_cycle()
		"water":
			var amount: float = float(current_task.get("amount", 25.0))
			farm_grid.water_tile(target_grid_pos, amount)
			_finish_work_cycle()
		"spray_pest":
			var method: String = current_task.get("method", "chemical")
			farm_grid.spray_pest(target_grid_pos, method)
			_finish_work_cycle()
		"harvest":
			farm_grid.harvest_tile(target_grid_pos)
			# Transition to DEPOSITING state to walk produce to the farm depot
			state = WorkerState.DEPOSITING
			_update_status_display("📦 Depositing...")
		_:
			_finish_work_cycle()

func _move_towards_depot(delta: float) -> void:
	# Depot location: (0, 0) or grid edge
	var depot_pixel: Vector2 = Vector2(32.0, 32.0)
	var dir: Vector2 = depot_pixel - global_position
	var dist: float = dir.length()
	var step: float = BASE_MOVE_SPEED * delta

	if dist <= step or dist < 4.0:
		global_position = depot_pixel
		_finish_work_cycle()
	else:
		velocity = dir.normalized() * BASE_MOVE_SPEED
		global_position += velocity * delta

func _finish_work_cycle() -> void:
	current_task = {}
	target_grid_pos = Vector2i(-1, -1)
	state = WorkerState.IDLE
	_update_status_display("🧑‍🌾 Idle")

func _update_status_display(txt: String) -> void:
	if status_label:
		status_label.text = txt

func _grid_to_pixel_center(gpos: Vector2i) -> Vector2:
	return Vector2(
		gpos.x * TILE_PIXEL_SIZE + TILE_PIXEL_SIZE / 2,
		gpos.y * TILE_PIXEL_SIZE + TILE_PIXEL_SIZE / 2
	)

func _pixel_to_grid(pixel: Vector2) -> Vector2i:
	return Vector2i(int(pixel.x / TILE_PIXEL_SIZE), int(pixel.y / TILE_PIXEL_SIZE))
