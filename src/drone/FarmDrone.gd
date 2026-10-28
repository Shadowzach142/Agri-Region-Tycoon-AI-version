# FarmDrone.gd
# Automated Farm Drone — remote-controlled from the worker hotbar "Drone" slot.
#
# The player drags a rectangular ZONE on the farm; the drone then flies around visibly
# and keeps working that zone indefinitely until recalled:
#   Lv.1 (Plow Drone)      — plows every untilled / flood-receded plot in the zone
#   Lv.2 (Seeder Drone)    — + plants the crop chosen in the Seeds slot (seeds are charged normally)
#   Lv.3 (Harvester Drone) — + harvests fully RIPE crops, stores them, then re-plows & re-plants
#
# It uses the exact same FarmGrid actions as human workers (plow_tile / plant_crop / harvest_tile),
# so spoilage, storage limits, perennial regrowth, seed cost and the Farm Chronicle all behave identically.
#
# Art: drawn procedurally in pixel-art style (see draw_drone_art). To use your own sprite, drop a PNG at
#      res://assets/sprites/drone/drone.png — it will automatically replace the procedural body.

class_name FarmDrone
extends Node2D

enum State { IDLE, FLYING, WORKING }

const FLY_SPEED: float = 300.0          # px/s at 1x game speed
const HOVER_HEIGHT: float = 44.0        # px the drone floats above the ground
const WORK_TIME: Dictionary = {
	"plow": 0.55,
	"plant": 0.55,
	"water": 0.50,
	"spray": 0.60,
	"harvest": 1.0,
	"clear": 1.2
}
const RESCAN_SECONDS: float = 1.5
const SPRITE_PATH: String = "res://assets/sprites/drone/drone.png"
const SPRITE_SHEET_PATH: String = "res://assets/sprites/Machine/Drones.png"
static var _sheet_tex: Texture2D = null
const SPRITE_SCALE: float = 3.0

const BODY_BLACK := Color(0.04, 0.05, 0.07)
const BODY_DARK  := Color(0.17, 0.20, 0.25)
const BODY_MID   := Color(0.31, 0.35, 0.42)
const BODY_LIGHT := Color(0.55, 0.61, 0.68)
const LEVEL_ACCENT: Array[Color] = [
	Color(0.55, 0.61, 0.68),
	Color(0.36, 0.88, 0.42),   # Lv.1 plow  — green
	Color(1.00, 0.78, 0.25),   # Lv.2 seed  — amber
	Color(1.00, 0.46, 0.26),   # Lv.3 harvest — orange
]
const JOB_COLORS: Dictionary = {
	"plow": Color(0.78, 0.58, 0.32),
	"plant": Color(0.45, 0.95, 0.45),
	"water": Color(0.25, 0.75, 1.0),
	"spray": Color(0.35, 1.0, 0.55),
	"harvest": Color(1.0, 0.82, 0.25),
	"clear": Color(0.95, 0.35, 0.35),
}
const JOB_LABELS: Dictionary = {
	"plow": "PLOWING",
	"plant": "SEEDING",
	"water": "WATERING",
	"spray": "TREATING",
	"harvest": "HARVESTING",
	"clear": "CLEARING"
}

# Automation Directives Toggles (Configurable via Drone Command Deck)
var auto_plow: bool = true
var auto_plant: bool = true
var auto_water: bool = true
var auto_spray: bool = true
var auto_harvest: bool = true
var auto_clear: bool = false
var ipm_method: String = "chemical"

var drone_index: int = 1
var hangar_ref: Node = null
var berth_offset: Vector2 = Vector2.ZERO
var is_selected: bool = false
var zone_center_pos: Vector2 = Vector2.ZERO

var farm_grid: Node2D = null
var zone: Array[Vector2i] = []
var zone_set: Dictionary = {}
var zone_rect: Rect2i = Rect2i()
var crop_type: String = "palay"

var state: int = State.IDLE
var job: Dictionary = {}
var jobs_done: int = 0
var status_text: String = "Standing by"

var _level: int = 0
var _work_timer: float = 0.0
var _scan_cooldown: float = 0.0
var _rotor_phase: float = 0.0
var _bob: float = 0.0
var _claw_open: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _blocked_reason: String = ""
var _custom_tex: Texture2D = null
var _zone_layer: Node2D = null
var _home_set: bool = false

func set_directive_mode(mode: String) -> void:
	match mode:
		"auto_loop":
			auto_plow = true
			auto_plant = true
			auto_water = true
			auto_spray = true
			auto_harvest = true
			auto_clear = false
		"plow":
			auto_plow = true
			auto_plant = false
			auto_water = false
			auto_spray = false
			auto_harvest = false
			auto_clear = false
		"plant":
			auto_plow = false
			auto_plant = true
			auto_water = false
			auto_spray = false
			auto_harvest = false
			auto_clear = false
		"water":
			auto_plow = false
			auto_plant = false
			auto_water = true
			auto_spray = false
			auto_harvest = false
			auto_clear = false
		"harvest":
			auto_plow = false
			auto_plant = false
			auto_water = false
			auto_spray = false
			auto_harvest = true
			auto_clear = false
	_scan_cooldown = 0.0

func set_ipm_method(method: String) -> void:
	if method == "spray_biological" or method == "biological":
		ipm_method = "biological"
	else:
		ipm_method = "chemical"

func get_drone_name() -> String:
	return "Drone #%d" % drone_index

func set_crop(new_crop: String) -> void:
	if Data.CROPS.has(new_crop):
		crop_type = new_crop
		_scan_cooldown = 0.0
		var disp: String = str(Data.get_crop(crop_type).get("display_name", crop_type))
		LogManager.log_event("crops", "🛸 Drone #%d assigned crop set to %s." % [drone_index, disp], "🛸", Color(0.40, 0.85, 1.0))
		if is_instance_valid(_zone_layer):
			_zone_layer.queue_redraw()

func _ready() -> void:
	name = "FarmDrone"
	z_index = 195
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(SPRITE_PATH):
		_custom_tex = load(SPRITE_PATH) as Texture2D

	_zone_layer = ZoneOverlay.new()
	_zone_layer.drone = self
	_zone_layer.name = "DroneZoneOverlay"
	_zone_layer.z_index = 190
	_zone_layer.z_as_relative = false
	if farm_grid:
		farm_grid.add_child.call_deferred(_zone_layer)
	BuildingManager.building_placed.connect(func(_b): _refresh_level())
	BuildingManager.drone_commissioned.connect(func(_d): _refresh_level())
	_refresh_level()

func _exit_tree() -> void:
	if is_instance_valid(_zone_layer):
		if _zone_layer.get_parent() == null:
			_zone_layer.free()
		else:
			_zone_layer.queue_free()

# ---------------------------------------------------------------------------
# Public API (called by FarmGrid / PlantHotbar)
# ---------------------------------------------------------------------------
func deploy(tiles: Array, crop: String) -> void:
	zone.clear()
	zone_set.clear()
	var min_p := Vector2i(100000, 100000)
	var max_p := Vector2i(-1, -1)
	for p in tiles:
		if farm_grid.is_tile_unlocked(p):
			zone.append(p)
			zone_set[p] = true
			min_p = Vector2i(mini(min_p.x, p.x), mini(min_p.y, p.y))
			max_p = Vector2i(maxi(max_p.x, p.x), maxi(max_p.y, p.y))
	if zone.is_empty():
		return
	zone_rect = Rect2i(min_p, max_p - min_p + Vector2i.ONE)
	if not crop.is_empty() and Data.CROPS.has(crop):
		crop_type = crop
	elif crop_type.is_empty():
		crop_type = "palay"

	# Calculate center position in isometric world coordinates
	var center_gx: float = float(min_p.x + max_p.x) * 0.5
	var center_gy: float = float(min_p.y + max_p.y) * 0.5
	zone_center_pos = Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (center_gx - center_gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (center_gx + center_gy) * FarmerMovement.HALF_H
	)

	job = {}
	state = State.IDLE
	_scan_cooldown = 0.0
	_work_timer = 0.0
	status_text = "Zone received"
	var cur_lvl: int = get_level()
	var tasks_desc: String = ["", "plow", "plow + plant", "plow + plant + harvest"][clampi(cur_lvl, 0, 3)]
	var crop_name: String = str(Data.get_crop(crop_type).get("display_name", crop_type))
	var crop_note: String = (" • crop: %s" % crop_name) if cur_lvl >= 2 else ""
	LogManager.log_event("crops", "🛸 Drone #%d deployed to %d×%d field (%d plots) — auto %s%s." % [drone_index, zone_rect.size.x, zone_rect.size.y, zone.size(), tasks_desc, crop_note], "🛸", Color(0.45, 0.85, 1.0))
	AudioManager.play_ui("click")
	if is_instance_valid(_zone_layer):
		_zone_layer.queue_redraw()

func recall() -> void:
	var had_zone: bool = not zone.is_empty()
	zone.clear()
	zone_set.clear()
	zone_rect = Rect2i()
	zone_center_pos = Vector2.ZERO
	job = {}
	state = State.IDLE
	_work_timer = 0.0
	status_text = "Standing by"
	if had_zone:
		LogManager.log_event("crops", "🛸 Drone #%d recalled to Hangar — field cleared (%d jobs completed)." % [drone_index, jobs_done], "🛸", Color(0.45, 0.85, 1.0))
	if is_instance_valid(_zone_layer):
		_zone_layer.queue_redraw()

func deploy_whole_farm(crop: String = "") -> void:
	if farm_grid == null:
		return
	var all_tiles: Array = []
	for x in range(farm_grid.GRID_SIZE.x):
		for y in range(farm_grid.GRID_SIZE.y):
			var p := Vector2i(x, y)
			if farm_grid.is_tile_unlocked(p):
				all_tiles.append(p)
	deploy(all_tiles, crop if not crop.is_empty() else crop_type)
	LogManager.log_event("crops", "🛸 Farm Drone deployed on Whole Farm Autonomous Patrol (%d plots)!" % zone.size(), "🛸", Color(0.40, 0.88, 1.0))

func get_telemetry() -> Dictionary:
	var data := {
		"level": _level,
		"state": state,
		"state_name": ["IDLE", "FLYING", "WORKING"][clampi(state, 0, 2)],
		"current_action": str(JOB_LABELS.get(job.get("type", ""), "Idle")),
		"crop_type": crop_type,
		"jobs_done": jobs_done,
		"zone_count": zone.size(),
		"is_whole_farm": zone.size() > 50,
		"auto_plow": auto_plow,
		"auto_plant": auto_plant,
		"auto_water": auto_water,
		"auto_spray": auto_spray,
		"auto_harvest": auto_harvest,
		"auto_clear": auto_clear,
		"blocked_reason": _blocked_reason,
		"growing_count": 0,
		"thirsty_count": 0,
		"infected_count": 0,
		"harvestable_count": 0,
		"plowable_count": 0,
		"empty_plowed_count": 0
	}
	if farm_grid != null and "tiles" in farm_grid:
		for p in zone:
			if not farm_grid._is_valid(p):
				continue
			var t: FarmTile = farm_grid.tiles[p.x][p.y]
			if t.state == FarmTile.TileState.HARVESTABLE:
				data["harvestable_count"] += 1
			elif t.state == FarmTile.TileState.GROWING:
				data["growing_count"] += 1
				if t.soil_moisture < 50.0:
					data["thirsty_count"] += 1
			elif t.state == FarmTile.TileState.INFECTED or t.pest_type != "":
				data["infected_count"] += 1
			elif t.state == FarmTile.TileState.PLOWED:
				data["empty_plowed_count"] += 1
			elif farm_grid.is_tile_plowable(p):
				data["plowable_count"] += 1
	return data

func has_zone() -> bool:
	return not zone.is_empty()

func get_level() -> int:
	if Data.game_mode == "sandbox":
		return 3
	return BuildingManager.get_drone_level()

func get_status_line() -> String:
	if get_level() <= 0 or BuildingManager.active_drones < drone_index:
		return "Drone Hangar inactive"
	if zone.is_empty():
		return "Standing by at Hangar — drag a field on your farm"
	var s: String = status_text
	if not _blocked_reason.is_empty() and state == State.IDLE:
		s = _blocked_reason
	return "%s • %d×%d field • %d jobs done" % [s, zone_rect.size.x, zone_rect.size.y, jobs_done]

# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------
func _refresh_level() -> void:
	if Data.game_mode == "sandbox":
		_level = 3
	else:
		_level = BuildingManager.get_drone_level()
	visible = (_level > 0 and BuildingManager.active_drones >= drone_index)

	if _level > 0 and not _home_set and farm_grid:
		_home_set = true
		var b_off: Vector2 = berth_offset if berth_offset != Vector2.ZERO else Vector2(0, -14.0)
		if is_instance_valid(hangar_ref):
			position = hangar_ref.position + b_off
		else:
			var station = BuildingManager.get_drone_station()
			if station and is_instance_valid(station):
				position = station.position + b_off
			else:
				var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(Vector2i(5, 5), Vector2i(1, 1))
				position = (poly[0] + poly[2]) * 0.5

func _process(delta: float) -> void:
	if farm_grid == null:
		return
	var cur_lvl := get_level()
	if cur_lvl != _level:
		_refresh_level()
	if _level <= 0:
		return

	_rotor_phase += delta * 42.0
	_bob += delta * 3.0
	var sim_delta: float = delta * TimeManager.get_speed_scale()

	match state:
		State.IDLE:
			_claw_open = move_toward(_claw_open, 0.0, delta * 4.0)
			if not zone.is_empty():
				# Smoothly hover and patrol over the center of its designated field
				if zone_center_pos != Vector2.ZERO:
					var hover_sway := Vector2(cos(_bob * 0.7) * 12.0, sin(_bob * 0.5) * 6.0)
					var target_hover: Vector2 = zone_center_pos + hover_sway
					position = position.move_toward(target_hover, FLY_SPEED * 0.5 * sim_delta)

				_scan_cooldown -= sim_delta
				if _scan_cooldown <= 0.0:
					var next_job: Dictionary = _scan_for_job()
					if next_job.is_empty():
						_scan_cooldown = RESCAN_SECONDS
						var crop_disp := str(Data.get_crop(crop_type).get("display_name", crop_type))
						status_text = _blocked_reason if not _blocked_reason.is_empty() else "Hovering & Monitoring (%s)" % crop_disp
					else:
						job = next_job
						_target = _job_target_local(job)
						state = State.FLYING
						status_text = "En route"
			else:
				# No zone assigned: gently hover over its hangar helipad
				var home_target := Vector2.ZERO
				var b_off: Vector2 = berth_offset if berth_offset != Vector2.ZERO else Vector2(0, -14.0)
				if is_instance_valid(hangar_ref):
					home_target = hangar_ref.position + b_off
				elif BuildingManager.get_drone_station():
					home_target = BuildingManager.get_drone_station().position + b_off
				if home_target != Vector2.ZERO:
					var home_sway := Vector2(cos(_bob * 0.5) * 4.0, sin(_bob * 0.4) * 2.0)
					position = position.move_toward(home_target + home_sway, FLY_SPEED * 0.4 * sim_delta)
		State.FLYING:
			var to_target: Vector2 = _target - position
			var step: float = FLY_SPEED * sim_delta
			if to_target.length() <= maxf(step, 0.5):
				position = _target
				if _job_still_valid(job):
					state = State.WORKING
					_work_timer = float(WORK_TIME.get(job.type, 0.6))
					status_text = str(JOB_LABELS.get(job.type, "WORKING"))
				else:
					job = {}
					state = State.IDLE
					_scan_cooldown = 0.0
			else:
				position += to_target.normalized() * step
		State.WORKING:
			_work_timer -= sim_delta
			_claw_open = 1.0 if str(job.get("type", "")) == "harvest" else 0.0
			if _work_timer <= 0.0:
				_complete_job()
				job = {}
				state = State.IDLE
				_scan_cooldown = 0.05

	queue_redraw()
	if is_instance_valid(_zone_layer):
		_zone_layer.queue_redraw()

func _footprint_in_zone(pos: Vector2i, fp: Vector2i) -> bool:
	for dx in range(fp.x):
		for dy in range(fp.y):
			if not zone_set.has(pos + Vector2i(dx, dy)):
				return false
	return true

func _scan_for_job() -> Dictionary:
	_blocked_reason = ""
	var best: Dictionary = {}
	var best_score: float = 1.0e9
	var here: Vector2i = FarmerMovement.pixel_to_grid(global_position, farm_grid)

	var crop_data: Dictionary = Data.get_crop(crop_type)
	var crop_fp: Vector2i = crop_data.get("footprint", Vector2i(1, 1))
	var seed_cost: int = int(crop_data.get("seed_cost", 25))
	var can_afford_seeds: bool = EconomyManager.cash >= seed_cost
	var storage_full: bool = BuildingManager.is_storage_full()
	var seen_roots: Dictionary = {}

	for p in zone:
		var tile: FarmTile = farm_grid.tiles[p.x][p.y]
		var root: Vector2i = p
		if tile.multi_tile_root_pos != Vector2i(-1, -1):
			root = tile.multi_tile_root_pos
		var root_t: FarmTile = farm_grid.tiles[root.x][root.y]
		var dist: float = float(absi(p.x - here.x) + absi(p.y - here.y)) * 10.0

		# 1. Lv.2+ — Spray & cure blighted/infected crops (Emergency Priority: Tier 0)
		if auto_spray and _level >= 2 and (root_t.state == FarmTile.TileState.INFECTED or root_t.pest_type != "") and not seen_roots.has(root):
			seen_roots[root] = true
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(root, self):
				pass
			elif EconomyManager.cash < 30:
				_blocked_reason = "Waiting for funds (₱30 treatment)"
			elif not TaskManager.has_task_at(root, "spray_pest"):
				var s_fp: Vector2i = Data.get_crop(root_t.crop_type).get("footprint", Vector2i(1, 1)) if root_t.crop_type != "" else Vector2i(1, 1)
				var score: float = dist + 0.0
				if score < best_score:
					best_score = score
					best = {"type": "spray", "pos": root, "fp": s_fp, "crop": root_t.crop_type}

		# 2. Lv.3 — Harvest fully ripe crops (Tier 1: 1000 base)
		if auto_harvest and _level >= 3 and root_t.crop_type != "" and root_t.state == FarmTile.TileState.HARVESTABLE and not seen_roots.has(root):
			seen_roots[root] = true
			var can_store_crop: bool = BuildingManager.has_storage_for_crop(root_t.crop_type, 100)
			if storage_full or not can_store_crop:
				if storage_full:
					_blocked_reason = "Storage full — sell crops at the Bodega"
				else:
					_blocked_reason = "No storage accepting %s has space" % root_t.crop_type.capitalize()
			elif farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(root, self):
				pass
			elif not TaskManager.has_task_at(root, "harvest"):
				var h_fp: Vector2i = Data.get_crop(root_t.crop_type).get("footprint", Vector2i(1, 1))
				var score: float = dist + 1000.0
				if score < best_score:
					best_score = score
					best = {"type": "harvest", "pos": root, "fp": h_fp, "crop": root_t.crop_type}

		# 3. Lv.1+ — Hydrate thirsty crops (moisture < 50%, Tier 2: 2000 base)
		if auto_water and _level >= 1 and root_t.crop_type != "" and root_t.soil_moisture < 50.0 and root_t.state != FarmTile.TileState.FLOODED and not seen_roots.has(root):
			seen_roots[root] = true
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(root, self):
				pass
			elif not TaskManager.has_task_at(root, "water"):
				var w_fp: Vector2i = Data.get_crop(root_t.crop_type).get("footprint", Vector2i(1, 1))
				var score: float = dist + 2000.0
				if score < best_score:
					best_score = score
					best = {"type": "water", "pos": root, "fp": w_fp, "crop": root_t.crop_type}

		# 4. Lv.2+ — Plant designated crop on plowed soil (Tier 3: 3000 base)
		if auto_plant and _level >= 2 and tile.state == FarmTile.TileState.PLOWED and farm_grid.can_plant_crop(p, crop_type) and _footprint_in_zone(p, crop_fp):
			if not BuildingManager.is_crop_unlocked(crop_type):
				_blocked_reason = "Designated crop %s locked (Agri-Shop)" % crop_type.capitalize()
			elif farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(p, self):
				pass
			elif not can_afford_seeds:
				_blocked_reason = "Waiting for funds (₱%d seed)" % seed_cost
			else:
				var score: float = dist + 3000.0
				if score < best_score:
					best_score = score
					best = {"type": "plant", "pos": p, "fp": crop_fp, "crop": crop_type}

		# 5. Lv.1+ — Plow untilled / receded land (Tier 4: 4000 base)
		if auto_plow and _level >= 1 and farm_grid.is_tile_plowable(p):
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(p, self):
				pass
			else:
				var score: float = dist + 4000.0
				if score < best_score:
					best_score = score
					best = {"type": "plow", "pos": p, "fp": Vector2i(1, 1), "crop": ""}

		# 6. Lv.3+ — Clear obstacles / fallen timber & rocks (Tier 5: 5000 base)
		if auto_clear and _level >= 3 and tile.state == FarmTile.TileState.OBSTACLE:
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(p, self):
				pass
			elif EconomyManager.cash < 50:
				_blocked_reason = "Waiting for funds (₱50 clearing)"
			else:
				var score: float = dist + 5000.0
				if score < best_score:
					best_score = score
					best = {"type": "clear", "pos": p, "fp": Vector2i(1, 1), "crop": ""}

	# If no jobs found, check if work is blocked by hangar capability level
	if best.is_empty() and _blocked_reason.is_empty():
		var has_plowed: bool = false
		var has_harvestable: bool = false
		for p in zone:
			var t_state = farm_grid.tiles[p.x][p.y].state
			if t_state == FarmTile.TileState.PLOWED:
				has_plowed = true
			elif t_state == FarmTile.TileState.HARVESTABLE:
				has_harvestable = true
		if _level < 2 and has_plowed:
			_blocked_reason = "🔒 Sowing locked: Drone is Lv.1 (Hangar Lv.2 required in Shop)"
		elif _level < 3 and has_harvestable:
			_blocked_reason = "🔒 Harvesting locked: Drone is Lv.%d (Hangar Lv.3 required in Shop)" % _level

	return best

func _job_still_valid(j: Dictionary) -> bool:
	if j.is_empty() or not farm_grid.is_tile_unlocked(j.pos):
		return false
	match str(j.type):
		"plow":
			return farm_grid.is_tile_plowable(j.pos)
		"plant":
			return farm_grid.can_plant_crop(j.pos, str(j.crop))
		"water":
			var t: FarmTile = farm_grid.tiles[j.pos.x][j.pos.y]
			return t.crop_type != "" and t.soil_moisture < 50.0 and t.state != FarmTile.TileState.FLOODED
		"spray":
			var t: FarmTile = farm_grid.tiles[j.pos.x][j.pos.y]
			return t.state == FarmTile.TileState.INFECTED or t.pest_type != ""
		"harvest":
			var t: FarmTile = farm_grid.tiles[j.pos.x][j.pos.y]
			return t.state == FarmTile.TileState.HARVESTABLE and t.crop_type != "" and BuildingManager.has_storage_for_crop(t.crop_type, 100)
		"clear":
			var t: FarmTile = farm_grid.tiles[j.pos.x][j.pos.y]
			return t.state == FarmTile.TileState.OBSTACLE
	return false

func _complete_job() -> void:
	if not _job_still_valid(job):
		return
	match str(job.type):
		"plow":
			farm_grid.plow_tile(job.pos)
			AudioManager.play_farmer("plow")
		"plant":
			farm_grid.plant_crop(job.pos, str(job.crop))
			AudioManager.play_farmer("plant")
		"water":
			farm_grid.water_tile(job.pos, 25.0)
			AudioManager.play_farmer("water")
		"spray":
			var method: String = ipm_method if (ipm_method == "biological" and EconomyManager.cash >= 45) else "chemical"
			farm_grid.spray_pest(job.pos, method)
			AudioManager.play_farmer("spray")
		"harvest":
			farm_grid.harvest_tile(job.pos)
			AudioManager.play_farmer("harvest")
		"clear":
			farm_grid.clear_obstacle(job.pos)
			AudioManager.play_farmer("chop")
	jobs_done += 1

func _job_target_local(j: Dictionary) -> Vector2:
	var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(j.pos, j.fp)
	return (poly[0] + poly[2]) * 0.5

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _level <= 0:
		return

	var body: Vector2 = Vector2(0.0, -HOVER_HEIGHT + sin(_bob) * 3.0)

	# Work beam to the ground while operating
	if state == State.WORKING and not job.is_empty():
		var col: Color = JOB_COLORS.get(job.type, Color.WHITE)
		var pulse: float = 0.55 + 0.45 * sin(_rotor_phase * 0.6)
		var beam_col := Color(col.r, col.g, col.b, 0.55 * pulse)
		draw_line(body + Vector2(0, 8), Vector2.ZERO, beam_col, 3.5)
		draw_line(body + Vector2(0, 8), Vector2.ZERO, Color(1, 1, 1, 0.45 * pulse), 1.5)

		# Type-specific work particles & visuals
		match str(job.get("type", "")):
			"water":
				for i in range(3):
					var ang: float = _rotor_phase * 2.0 + float(i) * 2.1
					var p_offset := Vector2(cos(ang) * 6.0, sin(ang) * 3.0)
					draw_circle(p_offset, 2.5, Color(0.35, 0.85, 1.0, 0.65))
			"spray":
				for i in range(3):
					var ang: float = -_rotor_phase * 1.5 + float(i) * 2.1
					var p_offset := Vector2(cos(ang) * 8.0, sin(ang) * 4.0)
					draw_circle(p_offset, 3.0, Color(0.40, 1.0, 0.60, 0.55))
			"clear":
				var sp: float = sin(_rotor_phase * 5.0) * 4.0
				draw_line(body + Vector2(0, 8), Vector2(sp, 0), Color(1.0, 0.4, 0.2, 0.8), 2.0)

	if _custom_tex != null:
		var sz: Vector2 = _custom_tex.get_size() * SPRITE_SCALE
		draw_texture_rect(_custom_tex, Rect2(body - sz * 0.5, sz), false)
	else:
		draw_drone_art(self, body, 3.0, _level, _rotor_phase, _claw_open)

	# Floating status tag
	if state == State.WORKING or state == State.FLYING:
		var label: String = str(JOB_LABELS.get(job.get("type", ""), "")) if state == State.WORKING else "EN ROUTE"
		var font: Font = ThemeDB.fallback_font
		var fsz: int = 11
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var pos: Vector2 = body + Vector2(-w * 0.5, -30.0)
		draw_rect(Rect2(pos + Vector2(-4, -12), Vector2(w + 8, 16)), Color(0.05, 0.07, 0.1, 0.78))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0.75, 0.95, 1.0))

## Shared pixel-art drone renderer (also used for the hotbar icon so both always match).
## center: drone center in the canvas item's local space, px: size of one art pixel.
static func draw_drone_art(ci: CanvasItem, center: Vector2, px: float, level: int, rotor_phase: float, claw_open: float) -> void:
	if _sheet_tex == null and ResourceLoader.exists(SPRITE_SHEET_PATH):
		_sheet_tex = load(SPRITE_SHEET_PATH) as Texture2D
	
	if _sheet_tex != null:
		var col: int = clampi(level - 1, 0, 2)
		var row: int = 0 if fmod(rotor_phase, TAU) < PI else 1
		var src_rect := Rect2(float(col * 64), float(row * 48), 64.0, 48.0)
		var s: float = px / 3.0
		var dest_rect := Rect2(center - Vector2(32.0, 24.0) * s, Vector2(64.0, 48.0) * s)
		ci.draw_texture_rect_region(_sheet_tex, dest_rect, src_rect)
		return

	var accent: Color = LEVEL_ACCENT[clampi(level, 0, 3)]
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(center + Vector2(x, y) * px, Vector2(w, h) * px), c)

	# Landing legs / tool rig (under the body)
	if level >= 1:
		r.call(-3.0, 3.0, 1.0, 2.0, BODY_DARK)      # tiller shafts
		r.call(2.0, 3.0, 1.0, 2.0, BODY_DARK)
		r.call(-3.0, 5.0, 1.0, 1.0, Color(0.55, 0.38, 0.22))
		r.call(2.0, 5.0, 1.0, 1.0, Color(0.55, 0.38, 0.22))
	if level >= 3:
		var spread: float = claw_open * 1.5
		r.call(-7.0 - spread, 2.0, 1.0, 4.0, BODY_DARK)  # harvester claws
		r.call(6.0 + spread, 2.0, 1.0, 4.0, BODY_DARK)
		r.call(-7.0 - spread, 5.0, 2.0, 1.0, accent)
		r.call(5.0 + spread, 5.0, 2.0, 1.0, accent)

	# Arms + motors
	r.call(-11.0, -1.0, 6.0, 1.0, BODY_DARK)
	r.call(5.0, -1.0, 6.0, 1.0, BODY_DARK)
	r.call(-12.0, -3.0, 2.0, 3.0, BODY_MID)
	r.call(10.0, -3.0, 2.0, 3.0, BODY_MID)

	# Main body
	r.call(-6.0, -3.0, 12.0, 6.0, BODY_BLACK)
	r.call(-5.0, -2.0, 10.0, 4.0, BODY_MID)
	r.call(-5.0, -2.0, 10.0, 1.0, BODY_LIGHT)
	r.call(-5.0, 1.0, 10.0, 1.0, BODY_DARK)
	r.call(-4.0, 0.0, 8.0, 1.0, accent)
	r.call(-1.0, 2.0, 2.0, 1.0, Color(0.35, 0.92, 1.0))   # camera lens

	# Seed hopper (Lv.2+)
	if level >= 2:
		r.call(-3.0, -6.0, 6.0, 3.0, BODY_BLACK)
		r.call(-2.0, -5.0, 4.0, 2.0, Color(0.46, 0.80, 0.36))
		r.call(-1.0, -6.0, 2.0, 1.0, Color(0.92, 0.86, 0.50))

	# Spinning rotors (translucent disc + crossing blades)
	for rx in [-11.0, 11.0]:
		var rc: Vector2 = center + Vector2(rx, -4.0) * px
		ci.draw_set_transform(rc, 0.0, Vector2(1.0, 0.35))
		ci.draw_circle(Vector2.ZERO, 5.0 * px, Color(0.82, 0.92, 1.0, 0.26))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var a: float = rotor_phase + (0.0 if rx < 0.0 else 1.3)
		var d1: Vector2 = Vector2(cos(a), sin(a) * 0.35) * 5.0 * px
		var d2: Vector2 = Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5) * 0.35) * 5.0 * px
		ci.draw_line(rc - d1, rc + d1, Color(0.92, 0.96, 1.0, 0.9), maxf(px * 0.8, 1.0))
		ci.draw_line(rc - d2, rc + d2, Color(0.92, 0.96, 1.0, 0.7), maxf(px * 0.8, 1.0))

# ---------------------------------------------------------------------------
# Zone overlay (drawn in FarmGrid-local space, below the drone, above the tiles)
# ---------------------------------------------------------------------------
class ZoneOverlay extends Node2D:
	var drone: FarmDrone = null

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _iso(gx: float, gy: float) -> Vector2:
		return Vector2(
			FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
			FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
		)

	func _draw() -> void:
		if drone == null or not is_instance_valid(drone) or drone.zone.is_empty():
			return
		# Only show highlights for the drone the player is currently using/controlling!
		if not drone.is_selected:
			return
		var rc: Rect2i = drone.zone_rect
		var x0: float = float(rc.position.x)
		var y0: float = float(rc.position.y)
		var x1: float = float(rc.position.x + rc.size.x)
		var y1: float = float(rc.position.y + rc.size.y)
		var pts := PackedVector2Array([_iso(x0, y0), _iso(x1, y0), _iso(x1, y1), _iso(x0, y1)])

		var base_colors: Array[Color] = [
			Color(0.28, 0.82, 1.0),   # Drone 1: Cyan
			Color(1.00, 0.78, 0.25),   # Drone 2: Amber
			Color(0.35, 0.95, 0.55),   # Drone 3: Emerald
			Color(0.85, 0.45, 1.00),   # Drone 4: Purple
			Color(1.00, 0.45, 0.45),   # Drone 5: Coral
		]
		var d_idx: int = maxi(drone.drone_index - 1, 0)
		var c_main: Color = base_colors[d_idx % base_colors.size()]
		var is_sel: bool = drone.is_selected

		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		var bg_alpha: float = 0.10 + 0.08 * pulse
		draw_colored_polygon(pts, Color(c_main.r, c_main.g, c_main.b, bg_alpha))

		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		var border_w: float = 3.2
		var border_alpha: float = 0.80 + 0.20 * pulse
		draw_polyline(closed, Color(c_main.r, c_main.g, c_main.b, border_alpha), border_w)

		# Corner brackets so the zone reads as a high-tech precision zone
		for p in pts:
			draw_circle(p, 4.5, c_main)
			draw_circle(p, 2.0, Color(0.04, 0.08, 0.12, 1.0))

		# Floating Field Identification Tag at top vertex
		var crop_disp: String = str(Data.get_crop(drone.crop_type).get("display_name", drone.crop_type))
		var tag: String = "🛸 %s: %s (Lv.%d)" % [drone.get_drone_name(), crop_disp, drone.get_level()]
		var font: Font = ThemeDB.fallback_font
		var fsz: int = 11
		var tag_w: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var tag_pos: Vector2 = pts[0] + Vector2(-tag_w * 0.5, -20.0)
		draw_rect(Rect2(tag_pos + Vector2(-6, -11), Vector2(tag_w + 12, 16)), Color(0.05, 0.07, 0.12, 0.88))
		draw_rect(Rect2(tag_pos + Vector2(-6, -11), Vector2(tag_w + 12, 16)), c_main, false, 1.2)
		draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, c_main)

		# Highlight the tile(s) currently being hovered / worked with high-contrast task badge
		if not drone.job.is_empty() and drone.state != FarmDrone.State.IDLE:
			var j: Dictionary = drone.job
			var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(j.pos, j.fp)
			var col: Color = FarmDrone.JOB_COLORS.get(j.type, Color.WHITE)
			var working: bool = drone.state == FarmDrone.State.WORKING
			draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.24 + (0.16 * pulse if working else 0.0)))
			var edge := PackedVector2Array(poly)
			edge.append(poly[0])
			draw_polyline(edge, Color(col.r, col.g, col.b, 0.95), 2.5)

			# Crisp in-field task pill over the specific tile
			var job_label: String = str(FarmDrone.JOB_LABELS.get(j.type, "WORKING"))
			if j.type == "plant":
				job_label = "SOWING %s" % crop_disp.to_upper()
			var task_str: String = "⚡ %s" % job_label
			var task_fsz: int = 10
			var task_w: float = font.get_string_size(task_str, HORIZONTAL_ALIGNMENT_CENTER, -1, task_fsz).x
			var tile_center: Vector2 = FarmerMovement.grid_to_pixel_center(j.pos, drone.farm_grid)
			var pill_pos: Vector2 = tile_center + Vector2(-task_w * 0.5, -20.0)
			draw_rect(Rect2(pill_pos + Vector2(-5, -9), Vector2(task_w + 10, 14)), Color(0.04, 0.06, 0.10, 0.90))
			draw_rect(Rect2(pill_pos + Vector2(-5, -9), Vector2(task_w + 10, 14)), col, false, 1.2)
			draw_string(font, pill_pos, task_str, HORIZONTAL_ALIGNMENT_CENTER, -1, task_fsz, Color(1.0, 1.0, 0.85))
