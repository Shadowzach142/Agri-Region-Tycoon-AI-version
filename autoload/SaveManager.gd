# SaveManager.gd
# Comprehensive save and load manager for Agri-Region Tycoon.
# Persists all farm state: region, game mode, economy, time, weather,
# market inventories, buildings, tiles, obstacles, and leaderboard scores.
# Supports 5 manual save slots plus an dedicated Autosave slot.

extends Node

signal save_completed(slot_index: int, success: bool, message: String)
signal load_completed(slot_index: int, success: bool, message: String)
signal slots_updated()

const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 5
const AUTOSAVE_SLOT: int = 0

var pending_save_data: Dictionary = {}

func _ready() -> void:
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

func get_slot_path(slot_index: int) -> String:
	if slot_index == AUTOSAVE_SLOT:
		return SAVE_DIR + "autosave.json"
	return SAVE_DIR + "slot_%d.json" % slot_index

func has_save(slot_index: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_index))

## Returns metadata summary of a save slot without loading the entire tile array
func get_slot_meta(slot_index: int) -> Dictionary:
	var path := get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}

	var data: Dictionary = json.data
	return data.get("meta", {})

## Returns metadata for all slots (0 = Autosave, 1..MAX_SLOTS)
func get_all_slots_meta() -> Dictionary:
	var result: Dictionary = {}
	for i in range(MAX_SLOTS + 1):
		result[i] = get_slot_meta(i)
	return result

func has_pending_save_data() -> bool:
	return not pending_save_data.is_empty()

## Captures full game state into a dictionary
func capture_game_state(slot_name: String = "") -> Dictionary:
	var tree := get_tree()
	var farm_grid = tree.root.find_child("FarmGrid", true, false)
	var farmer = tree.root.find_child("Farmer", true, false)

	# 1. Metadata
	var region_key: String = Data.current_region
	var r_meta: Dictionary = Data.get_region(region_key)
	var region_display: String = r_meta.get("display_name", region_key.capitalize())
	var mode: String = Data.game_mode
	var mode_title: String = "Career Tycoon" if mode == "career" else "Timed Campaign"

	var datetime_dict := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d %02d:%02d" % [
		datetime_dict.year, datetime_dict.month, datetime_dict.day,
		datetime_dict.hour, datetime_dict.minute
	]

	var meta: Dictionary = {
		"title": slot_name if slot_name != "" else "%s - Day %d" % [region_display, TimeManager.current_day],
		"date": date_str,
		"timestamp": Time.get_unix_time_from_system(),
		"region_key": region_key,
		"region_display": region_display,
		"game_mode": mode,
		"game_mode_title": mode_title,
		"season_days": Data.selected_season_days,
		"day": TimeManager.current_day,
		"hour": TimeManager.current_hour,
		"cash": EconomyManager.cash,
		"points": LeaderboardManager.current_points
	}

	# 2. Economy
	var economy: Dictionary = {
		"cash": EconomyManager.cash
	}

	# 3. Time
	var time_state: Dictionary = {
		"day": TimeManager.current_day,
		"hour": TimeManager.current_hour,
		"elapsed_seconds": TimeManager._elapsed,
		"is_freeplay_mode": TimeManager.is_freeplay_mode,
		"speed_scale": TimeManager.get_speed_scale()
	}

	# 4. Weather
	var weather: Dictionary = {
		"climate": WeatherManager.current_climate,
		"effective_temp": WeatherManager.get_effective_temperature(),
		"effective_hum": WeatherManager.get_effective_humidity(),
		"active_disaster": WeatherManager.active_disaster
	}

	# 5. Leaderboard / Score
	var leaderboard: Dictionary = {
		"points": LeaderboardManager.current_points,
		"combo": LeaderboardManager.current_combo,
		"max_combo": LeaderboardManager.max_combo,
		"run_units_sold": LeaderboardManager.run_units_sold,
		"run_grade_a": LeaderboardManager.run_grade_a,
		"run_deliveries": LeaderboardManager.run_deliveries,
		"highest_single_sale_pts": LeaderboardManager.highest_single_sale_pts
	}

	# 6. Market
	var market: Dictionary = {
		"stored_inventory": MarketManager.stored_inventory.duplicate(true),
		"price_history": MarketManager.price_history.duplicate(true)
	}

	# 7. Building Manager
	var buildings_array: Array = []
	for b in BuildingManager.placed_buildings:
		if is_instance_valid(b):
			buildings_array.append({
				"type": b.building_type,
				"grid_pos": [b.grid_pos.x, b.grid_pos.y],
				"footprint": [b.footprint.x, b.footprint.y],
				"level": b.level,
				"state": b.state,
				"progress_timer": b.progress_timer,
				"duration": b.duration,
				"assigned_crops": b.assigned_crops.duplicate() if "assigned_crops" in b else [],
				"used_storage": b.used_storage if "used_storage" in b else 0,
				"is_flipped": b.is_flipped if "is_flipped" in b else false
			})

	var building_manager_data: Dictionary = {
		"active_workers": BuildingManager.active_workers,
		"worker_capacity": BuildingManager.worker_capacity,
		"active_drones": BuildingManager.active_drones,
		"unlocked_techs": BuildingManager.unlocked_techs.duplicate(),
		"buildings": buildings_array
	}

	# 8. FarmGrid (unlocked parcels, world seed, tiles)
	var farm_grid_data: Dictionary = {}
	if farm_grid:
		var grid_tiles: Array = []
		var size: Vector2i = farm_grid.GRID_SIZE
		grid_tiles.resize(size.x)
		for x in range(size.x):
			grid_tiles[x] = []
			for y in range(size.y):
				var t: FarmTile = farm_grid.tiles[x][y]
				grid_tiles[x].append({
					"s": t.state,
					"m": t.soil_moisture,
					"c": t.crop_type,
					"g": t.growth_progress,
					"h": t.health,
					"q": t.quality,
					"y": t.yield_quantity,
					"f": t.freshness,
					"p": t.pest_type,
					"o": t.obstacle_type,
					"fe": t.soil_fertility,
					"w": t.hours_waterlogged,
					"rg": t.is_regrowing,
					"mr": t.is_multi_tile_root,
					"mp": [t.multi_tile_root_pos.x, t.multi_tile_root_pos.y]
				})

		var seed_val: int = 0
		if farm_grid.renderer and farm_grid.renderer.ground_sprites:
			seed_val = farm_grid.renderer.ground_sprites.world_seed

		farm_grid_data = {
			"unlocked_parcels": farm_grid.unlocked_parcels.duplicate(),
			"world_seed": seed_val,
			"tiles": grid_tiles
		}

	# 9. Farmer position
	var farmer_data: Dictionary = {}
	if farmer:
		farmer_data["pos"] = [farmer.global_position.x, farmer.global_position.y]

	return {
		"meta": meta,
		"economy": economy,
		"time": time_state,
		"weather": weather,
		"leaderboard": leaderboard,
		"market": market,
		"building_manager": building_manager_data,
		"farm_grid": farm_grid_data,
		"farmer": farmer_data
	}

## Saves game state into a file
func save_game(slot_index: int, slot_name: String = "") -> bool:
	_ensure_save_directory()
	var state := capture_game_state(slot_name)
	var path := get_slot_path(slot_index)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err_msg := "Failed to open save file for writing: " + path
		push_error("[SaveManager] " + err_msg)
		save_completed.emit(slot_index, false, err_msg)
		return false

	var json_str := JSON.stringify(state, "\t")
	file.store_string(json_str)
	file.close()

	var msg := "Saved game to Slot %d" % slot_index if slot_index > 0 else "Autosaved game"
	print("[SaveManager] " + msg)
	LogManager.log_event("finance", "💾 " + msg, "💾", Color(0.4, 0.8, 1.0))
	save_completed.emit(slot_index, true, msg)
	slots_updated.emit()
	return true

## Loads game state from slot and triggers scene load
func load_game(slot_index: int) -> bool:
	var path := get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		var err := "Save slot %d does not exist" % slot_index
		push_error("[SaveManager] " + err)
		load_completed.emit(slot_index, false, err)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		var err := "Could not open save file: " + path
		load_completed.emit(slot_index, false, err)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		var err := "Corrupt save file in slot %d" % slot_index
		load_completed.emit(slot_index, false, err)
		return false

	pending_save_data = json.data
	var meta: Dictionary = pending_save_data.get("meta", {})

	# Set global session parameters before scene transition
	Data.current_region = meta.get("region_key", "cotabato")
	Data.game_mode = meta.get("game_mode", "career")
	Data.selected_season_days = meta.get("season_days", 60)

	print("[SaveManager] Stored pending save for %s (%s, Day %d). Transitioning to MainGame..." % [
		meta.get("region_display", "Farm"),
		Data.game_mode,
		meta.get("day", 1)
	])

	load_completed.emit(slot_index, true, "Loading " + meta.get("title", "Save Slot"))
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
	return true

## Deletes a save slot
func delete_slot(slot_index: int) -> bool:
	var path := get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return false

	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		var file_name := "autosave.json" if slot_index == AUTOSAVE_SLOT else "slot_%d.json" % slot_index
		var err := dir.remove(file_name)
		if err == OK:
			slots_updated.emit()
			return true
	return false

## Applies the pending loaded save data to the live scene nodes
func apply_pending_save(farm_grid: Node) -> void:
	if pending_save_data.is_empty():
		return

	print("[SaveManager] Applying loaded save state to live farm...")
	var data := pending_save_data
	pending_save_data = {} # Clear so subsequent reloads don't re-apply

	var meta: Dictionary = data.get("meta", {})

	# 1. Economy
	var eco: Dictionary = data.get("economy", {})
	EconomyManager.cash = eco.get("cash", 250)
	EconomyManager.cash_changed.emit(EconomyManager.cash)

	# 2. Time
	var t_data: Dictionary = data.get("time", {})
	TimeManager.current_day = t_data.get("day", 1)
	TimeManager.current_hour = t_data.get("hour", 7)
	TimeManager._elapsed = t_data.get("elapsed_seconds", (float(TimeManager.current_hour) / 24.0) * TimeManager.DAY_SECONDS)
	TimeManager.is_freeplay_mode = t_data.get("is_freeplay_mode", (Data.game_mode == "career"))
	TimeManager.day_changed.emit(TimeManager.current_day)
	TimeManager.hour_changed.emit(TimeManager.current_hour)
	TimeManager.set_speed_scale(t_data.get("speed_scale", 1.0))

	# 3. Weather
	var w_data: Dictionary = data.get("weather", {})
	WeatherManager.current_climate = w_data.get("climate", 0)
	var temp: float = w_data.get("effective_temp", 31.0)
	var hum: float = w_data.get("effective_hum", 60.0)
	WeatherManager.weather_changed.emit(temp, hum)

	# 4. Leaderboard & Stats
	var lb: Dictionary = data.get("leaderboard", {})
	LeaderboardManager.current_points = lb.get("points", 0)
	LeaderboardManager.current_combo = lb.get("combo", 0)
	LeaderboardManager.max_combo = lb.get("max_combo", 0)
	LeaderboardManager.run_units_sold = lb.get("run_units_sold", 0)
	LeaderboardManager.run_grade_a = lb.get("run_grade_a", 0)
	LeaderboardManager.run_deliveries = lb.get("run_deliveries", 0)
	LeaderboardManager.highest_single_sale_pts = lb.get("highest_single_sale_pts", 0)
	LeaderboardManager.points_changed.emit(LeaderboardManager.current_points, 0, "Loaded Game")

	# 5. Market
	var mkt: Dictionary = data.get("market", {})
	MarketManager.stored_inventory = mkt.get("stored_inventory", [])
	MarketManager.price_history = mkt.get("price_history", {})
	MarketManager._sync_storage_with_building_manager()
	MarketManager.inventory_changed.emit()

	# 6. FarmGrid & Tiles
	var fg_data: Dictionary = data.get("farm_grid", {})
	if farm_grid and not fg_data.is_empty():
		# Restore unlocked parcels
		farm_grid.unlocked_parcels = Array(fg_data.get("unlocked_parcels", ["homestead"]), TYPE_STRING, &"", null)

		# Restore ground seed if present
		if farm_grid.renderer and farm_grid.renderer.ground_sprites:
			farm_grid.renderer.ground_sprites.world_seed = fg_data.get("world_seed", randi())

		# Restore tiles
		var saved_tiles: Array = fg_data.get("tiles", [])
		for x in range(farm_grid.GRID_SIZE.x):
			if x >= saved_tiles.size():
				continue
			for y in range(farm_grid.GRID_SIZE.y):
				if y >= saved_tiles[x].size():
					continue
				var s_tile: Dictionary = saved_tiles[x][y]
				var t: FarmTile = farm_grid.tiles[x][y]
				t.state = s_tile.get("s", FarmTile.TileState.EMPTY)
				t.soil_moisture = s_tile.get("m", 60.0)
				t.crop_type = s_tile.get("c", "")
				t.growth_progress = s_tile.get("g", 0.0)
				t.health = s_tile.get("h", 1.0)
				t.quality = s_tile.get("q", 0)
				t.yield_quantity = s_tile.get("y", 100)
				t.freshness = s_tile.get("f", 100.0)
				t.pest_type = s_tile.get("p", "")
				t.obstacle_type = s_tile.get("o", "")
				t.soil_fertility = s_tile.get("fe", 1.0)
				t.hours_waterlogged = s_tile.get("w", 0)
				t.is_regrowing = s_tile.get("rg", false)
				t.is_multi_tile_root = s_tile.get("mr", false)
				var mp_arr: Array = s_tile.get("mp", [-1, -1])
				if mp_arr.size() >= 2:
					t.multi_tile_root_pos = Vector2i(int(mp_arr[0]), int(mp_arr[1]))

	# 7. Buildings
	var bm_data: Dictionary = data.get("building_manager", {})
	# Clear existing placed buildings (starter buildings spawned in _ready)
	for b in BuildingManager.placed_buildings.duplicate():
		if is_instance_valid(b):
			BuildingManager.unregister_building(b)
			b.queue_free()

	BuildingManager.unlocked_techs = bm_data.get("unlocked_techs", [])

	# Re-instantiate saved buildings
	var b_list: Array = bm_data.get("buildings", [])
	for b_info in b_list:
		var b_type: String = b_info.get("type", "")
		var g_pos := Vector2i(b_info.get("grid_pos", [0, 0])[0], b_info.get("grid_pos", [0, 0])[1])
		var fp := Vector2i(b_info.get("footprint", [2, 2])[0], b_info.get("footprint", [2, 2])[1])

		var building := Building.new()
		building.name = "Building_%s_%d_%d" % [b_type, g_pos.x, g_pos.y]
		building.building_type = b_type
		building.grid_pos = g_pos
		building.footprint = fp
		building.level = b_info.get("level", 1)
		building.state = b_info.get("state", Building.BuildingState.ACTIVE)
		building.progress_timer = b_info.get("progress_timer", 0.0)
		building.duration = b_info.get("duration", 0.0)
		building.assigned_crops = Array(b_info.get("assigned_crops", []), TYPE_STRING, &"", null)
		building.used_storage = int(b_info.get("used_storage", 0))
		building.is_flipped = b_info.get("is_flipped", false)

		farm_grid.add_child(building)

		# Set tile references
		for dx in range(fp.x):
			for dy in range(fp.y):
				var tp := Vector2i(g_pos.x + dx, g_pos.y + dy)
				if farm_grid._is_valid(tp):
					farm_grid.tiles[tp.x][tp.y].building_ref = building

		# Connect signals
		if building.has_signal("clicked") and not building.clicked.is_connected(farm_grid._on_building_clicked):
			building.clicked.connect(farm_grid._on_building_clicked)
		if building.has_signal("demolished") and not building.demolished.is_connected(farm_grid._on_building_demolished):
			building.demolished.connect(farm_grid._on_building_demolished)

		BuildingManager.register_building(building)

	BuildingManager.active_workers = bm_data.get("active_workers", 1)
	BuildingManager.active_drones = bm_data.get("active_drones", 0)
	BuildingManager.recalculate_bonuses()

	# 8. Farmer position
	var farmer_data: Dictionary = data.get("farmer", {})
	if not farmer_data.is_empty():
		var farmer = farm_grid.get_tree().root.find_child("Farmer", true, false)
		if farmer and farmer_data.has("pos"):
			farmer.global_position = Vector2(farmer_data["pos"][0], farmer_data["pos"][1])

	# 9. Refresh visual renderer & signposts
	if farm_grid:
		farm_grid._create_parcel_signposts()
		farm_grid.renderer.update_all(farm_grid.tiles, farm_grid.GRID_SIZE)

	print("[SaveManager] Loaded farm applied successfully!")
	LogManager.log_event("finance", "📂 Resumed farm: " + meta.get("title", ""), "📂", Color(0.3, 0.9, 0.4))
