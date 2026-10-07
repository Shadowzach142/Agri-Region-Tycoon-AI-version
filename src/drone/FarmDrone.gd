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
const WORK_TIME: Dictionary = {"plow": 0.55, "plant": 0.55, "harvest": 1.0}
const RESCAN_SECONDS: float = 1.5
const SPRITE_PATH: String = "res://assets/sprites/drone/drone.png"
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
	"harvest": Color(1.0, 0.82, 0.25),
}
const JOB_LABELS: Dictionary = {"plow": "PLOWING", "plant": "SEEDING", "harvest": "HARVESTING"}

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
	crop_type = crop if not crop.is_empty() else "palay"
	job = {}
	state = State.IDLE
	_scan_cooldown = 0.0
	_work_timer = 0.0
	status_text = "Zone received"
	var tasks_desc: String = ["", "plow", "plow + plant", "plow + plant + harvest"][clampi(_level, 0, 3)]
	var crop_name: String = str(Data.get_crop(crop_type).get("display_name", crop_type))
	var crop_note: String = (" • crop: %s" % crop_name) if _level >= 2 else ""
	LogManager.log_event("crops", "🛸 Farm Drone deployed to a %d×%d zone (%d plots) — auto %s%s." % [zone_rect.size.x, zone_rect.size.y, zone.size(), tasks_desc, crop_note], "🛸", Color(0.45, 0.85, 1.0))
	AudioManager.play_ui("click")

func recall() -> void:
	var had_zone: bool = not zone.is_empty()
	zone.clear()
	zone_set.clear()
	zone_rect = Rect2i()
	job = {}
	state = State.IDLE
	_work_timer = 0.0
	status_text = "Standing by"
	if had_zone:
		LogManager.log_event("crops", "🛸 Farm Drone recalled — zone cleared (%d jobs completed)." % jobs_done, "🛸", Color(0.45, 0.85, 1.0))
	if is_instance_valid(_zone_layer):
		_zone_layer.queue_redraw()

func has_zone() -> bool:
	return not zone.is_empty()

func get_level() -> int:
	return _level

func get_status_line() -> String:
	if _level <= 0 or BuildingManager.active_drones <= 0:
		if not BuildingManager.has_drone_station():
			return "No Drone Hangar built — Build one in Shop > Machinery & Drones"
		return "Commission drones in Agri-Shop (Labor tab)"
	if zone.is_empty():
		return "Standing by — drag a zone on your farm"
	var s: String = status_text
	if not _blocked_reason.is_empty() and state == State.IDLE:
		s = _blocked_reason
	return "%s • zone %d×%d • %d jobs done" % [s, zone_rect.size.x, zone_rect.size.y, jobs_done]

# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------
func _refresh_level() -> void:
	_level = BuildingManager.get_drone_level()
	visible = (_level > 0 and BuildingManager.active_drones > 0)
	if _level > 0 and not _home_set and farm_grid:
		_home_set = true
		var station = BuildingManager.get_drone_station()
		if station and is_instance_valid(station):
			var idx: int = 0
			if "drones" in farm_grid:
				idx = farm_grid.drones.find(self)
				if idx < 0:
					idx = 0
			var offset_x: float = float((idx % 3) - 1) * 16.0
			var offset_y: float = float(idx / 3) * 12.0 - 12.0
			position = station.position + Vector2(offset_x, offset_y)
		else:
			var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(Vector2i(5, 5), Vector2i(1, 1))
			position = (poly[0] + poly[2]) * 0.5

func _process(delta: float) -> void:
	if farm_grid == null:
		return
	if BuildingManager.get_drone_level() != _level:
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
				_scan_cooldown -= sim_delta
				if _scan_cooldown <= 0.0:
					var next_job: Dictionary = _scan_for_job()
					if next_job.is_empty():
						_scan_cooldown = RESCAN_SECONDS
						status_text = _blocked_reason if not _blocked_reason.is_empty() else "Zone idle — waiting for crops"
					else:
						job = next_job
						_target = _job_target_local(job)
						state = State.FLYING
						status_text = "En route"
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
	var can_afford: bool = EconomyManager.cash >= seed_cost
	var storage_full: bool = BuildingManager.is_storage_full()
	var seen_roots: Dictionary = {}

	for p in zone:
		var tile: FarmTile = farm_grid.tiles[p.x][p.y]
		var root: Vector2i = p
		if tile.multi_tile_root_pos != Vector2i(-1, -1):
			root = tile.multi_tile_root_pos
		var root_t: FarmTile = farm_grid.tiles[root.x][root.y]
		var dist: float = float(absi(p.x - here.x) + absi(p.y - here.y)) * 10.0

		# Lv.3 — harvest fully ripe crops only (never early-harvests)
		if _level >= 3 and root_t.crop_type != "" and root_t.state == FarmTile.TileState.HARVESTABLE and not seen_roots.has(root):
			seen_roots[root] = true
			if storage_full:
				_blocked_reason = "Storage full — sell crops at the Bodega"
			elif farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(root, self):
				pass
			elif not TaskManager.has_task_at(root, "harvest"):
				var h_fp: Vector2i = Data.get_crop(root_t.crop_type).get("footprint", Vector2i(1, 1))
				if dist < best_score:
					best_score = dist
					best = {"type": "harvest", "pos": root, "fp": h_fp, "crop": root_t.crop_type}

		# Lv.2 — plant on plowed soil
		if _level >= 2 and tile.state == FarmTile.TileState.PLOWED and farm_grid.can_plant_crop(p, crop_type) and _footprint_in_zone(p, crop_fp):
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(p, self):
				pass
			elif not can_afford:
				_blocked_reason = "Waiting for funds (₱%d seed)" % seed_cost
			elif dist + 1.0 < best_score:
				best_score = dist + 1.0
				best = {"type": "plant", "pos": p, "fp": crop_fp, "crop": crop_type}

		# Lv.1 — plow untilled / receded land
		if _level >= 1 and farm_grid.is_tile_plowable(p):
			if farm_grid.has_method("is_tile_targeted_by_other_drone") and farm_grid.is_tile_targeted_by_other_drone(p, self):
				pass
			elif dist + 2.0 < best_score:
				best_score = dist + 2.0
				best = {"type": "plow", "pos": p, "fp": Vector2i(1, 1), "crop": ""}

	return best

func _job_still_valid(j: Dictionary) -> bool:
	if j.is_empty() or not farm_grid.is_tile_unlocked(j.pos):
		return false
	match str(j.type):
		"plow":
			return farm_grid.is_tile_plowable(j.pos)
		"plant":
			return farm_grid.can_plant_crop(j.pos, str(j.crop))
		"harvest":
			var t: FarmTile = farm_grid.tiles[j.pos.x][j.pos.y]
			return t.state == FarmTile.TileState.HARVESTABLE and t.crop_type != "" and not BuildingManager.is_storage_full()
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
		"harvest":
			farm_grid.harvest_tile(job.pos)
			AudioManager.play_farmer("harvest")
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

	# Ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var body: Vector2 = Vector2(0.0, -HOVER_HEIGHT + sin(_bob) * 3.0)

	# Work beam to the ground while operating
	if state == State.WORKING and not job.is_empty():
		var col: Color = JOB_COLORS.get(job.type, Color.WHITE)
		var pulse: float = 0.55 + 0.45 * sin(_rotor_phase * 0.6)
		var beam_col := Color(col.r, col.g, col.b, 0.55 * pulse)
		draw_line(body + Vector2(0, 8), Vector2.ZERO, beam_col, 3.0)
		draw_line(body + Vector2(0, 8), Vector2.ZERO, Color(1, 1, 1, 0.35 * pulse), 1.0)

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
		var rc: Rect2i = drone.zone_rect
		var x0: float = float(rc.position.x)
		var y0: float = float(rc.position.y)
		var x1: float = float(rc.position.x + rc.size.x)
		var y1: float = float(rc.position.y + rc.size.y)
		var pts := PackedVector2Array([_iso(x0, y0), _iso(x1, y0), _iso(x1, y1), _iso(x0, y1)])

		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		draw_colored_polygon(pts, Color(0.30, 0.80, 1.0, 0.06 + 0.04 * pulse))

		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		draw_polyline(closed, Color(0.40, 0.88, 1.0, 0.55 + 0.35 * pulse), 2.5)

		# Corner brackets so the zone reads as a "drone zone"
		for p in pts:
			draw_circle(p, 4.0, Color(0.55, 0.95, 1.0, 0.95))
			draw_circle(p, 2.0, Color(0.05, 0.15, 0.25, 1.0))

		# Highlight the tile(s) currently being worked
		if not drone.job.is_empty() and drone.state != FarmDrone.State.IDLE:
			var j: Dictionary = drone.job
			var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(j.pos, j.fp)
			var col: Color = FarmDrone.JOB_COLORS.get(j.type, Color.WHITE)
			var working: bool = drone.state == FarmDrone.State.WORKING
			draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.22 + (0.18 * pulse if working else 0.0)))
			var edge := PackedVector2Array(poly)
			edge.append(poly[0])
			draw_polyline(edge, Color(col.r, col.g, col.b, 0.95), 2.5)
