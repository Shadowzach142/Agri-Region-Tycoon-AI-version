# BuildingManager.gd
# Handles farm infrastructure, storage limits, machinery bonuses, placed buildings, and worker housing capacity.
# Supports WoW / Clash of Clans building mechanics (placement, construction timers, level upgrades).

extends Node

signal building_purchased(building_type: String)
signal tech_unlocked(tech_type: String)
signal storage_updated(total_capacity: int, used_capacity: int)
signal worker_hired(total_workers: int)
signal worker_capacity_changed(total_capacity: int, active_workers: int)
signal building_placed(building: Node)
signal drone_commissioned(total_drones: int)
signal weather_station_updated(level: int)
signal irrigation_updated(level: int)
signal machinery_updated(level: int)
signal bayanihan_updated(level: int)
signal directive_changed(parcel_id: String, directive: Dictionary)
signal sprinklers_updated(active_count: int, capacity: int)
signal batch_processed(facility_name: String, input_crop: String, input_qty: int, outputs: Array)

var placed_buildings: Array = []          # Array of placed Building instances
var purchased_buildings: Dictionary = {}		 # building_type -> count (for backward compatibility)
var unlocked_techs: Array = []
var bayanihan_directives: Dictionary = {} # parcel_id -> {"mode": String, "crop": String}

var total_storage_capacity: int = 200
var used_storage: int = 0

var worker_capacity: int = 1
var active_workers: int = 1
var active_drones: int = 0

func _ready() -> void:
	if TimeManager.has_signal("hour_changed"):
		TimeManager.hour_changed.connect(_on_hour_changed)

# ---------------------------------------------------------------------------
# Placed Building Registry
# ---------------------------------------------------------------------------
func register_building(building: Node) -> void:
	if not placed_buildings.has(building):
		placed_buildings.append(building)
		purchased_buildings[building.building_type] = purchased_buildings.get(building.building_type, 0) + 1
		recalculate_bonuses()
		building_placed.emit(building)

func unregister_building(building: Node) -> void:
	if placed_buildings.has(building):
		placed_buildings.erase(building)
		var cnt: int = purchased_buildings.get(building.building_type, 1)
		purchased_buildings[building.building_type] = max(0, cnt - 1)
		recalculate_bonuses()

func is_tile_occupied_by_building(pos: Vector2i) -> bool:
	return get_building_at_tile(pos) != null

func get_building_at_tile(pos: Vector2i) -> Node:
	for b in placed_buildings:
		if not is_instance_valid(b):
			continue
		var fp: Vector2i = b.footprint
		var gp: Vector2i = b.grid_pos
		if pos.x >= gp.x and pos.x < gp.x + fp.x and pos.y >= gp.y and pos.y < gp.y + fp.y:
			return b
	return null

## Recalculate all storage and housing capacity based on active placed buildings & upgrades
func recalculate_bonuses() -> void:
	var new_storage: int = 0
	var new_workers: int = 0

	# Clean up any freed building instances
	placed_buildings = placed_buildings.filter(func(b): return is_instance_valid(b))

	for b in placed_buildings:
		# Only active completed buildings grant perks
		if b.state != b.BuildingState.ACTIVE:
			continue

		var b_data := Data.get_building(b.building_type)
		var lvl: int = b.level

		# Storage capacity
		var base_storage: int = int(b_data.get("storage_limit", 0))
		if base_storage > 0:
			new_storage += int(base_storage * (1.0 + (lvl - 1) * 1.0))

		# Worker capacity
		var base_workers: int = int(b_data.get("worker_capacity", 0))
		if base_workers > 0:
			new_workers += lvl * base_workers

	total_storage_capacity = new_storage if not placed_buildings.is_empty() else 200
	worker_capacity = max(new_workers, 1)

	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr and m_mgr.has_method("get_total_stored_units"):
		used_storage = m_mgr.get_total_stored_units()

	storage_updated.emit(total_storage_capacity, used_storage)
	worker_hired.emit(active_workers)
	worker_capacity_changed.emit(worker_capacity, active_workers)
	drone_commissioned.emit(active_drones)
	weather_station_updated.emit(get_weather_station_level())
	irrigation_updated.emit(get_irrigation_level())
	machinery_updated.emit(get_machine_garage_level())
	bayanihan_updated.emit(get_bayanihan_center_level())
	sprinklers_updated.emit(get_active_sprinkler_count(), get_sprinkler_capacity())

## Returns the primary active storage building (Bodega, Silo, etc.) or null
func get_first_storage_building() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.state == b.BuildingState.ACTIVE:
			var b_data := Data.get_building(b.building_type)
			if int(b_data.get("storage_limit", 0)) > 0:
				return b
	return null

## Returns the primary worker housing building (Bahay Kubo) or null
func get_first_housing_building() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.state == b.BuildingState.ACTIVE:
			var b_data := Data.get_building(b.building_type)
			if int(b_data.get("worker_capacity", 0)) > 0:
				return b
	return null

func get_constructing_buildings(b_type: String = "") -> Array:
	var list: Array = []
	for b in placed_buildings:
		if is_instance_valid(b) and b.state == b.BuildingState.CONSTRUCTING:
			if b_type == "" or b.building_type == b_type:
				list.append(b)
	return list

func has_constructing_building(b_type: String) -> bool:
	return get_constructing_buildings(b_type).size() > 0

func get_building_construction_time_remaining(b_type: String) -> float:
	var buildings := get_constructing_buildings(b_type)
	if buildings.is_empty():
		return 0.0
	var min_rem: float = 999999.0
	for b in buildings:
		var rem: float = maxf(0.0, b.duration - b.progress_timer)
		if rem < min_rem:
			min_rem = rem
	return min_rem

func get_upgrade_cost(building_type: String, current_level: int) -> int:
	var b_data := Data.get_building(building_type)
	var base_cost: int = int(b_data.get("cost", 300))
	return int(base_cost * (1.2 + current_level * 0.4))

func get_upgrade_time(building_type: String, current_level: int) -> float:
	var b_data := Data.get_building(building_type)
	var base_time: float = float(b_data.get("build_time", 20.0))
	return base_time * (1.0 + current_level * 0.5)

# ---------------------------------------------------------------------------
# Tech & Workers
# ---------------------------------------------------------------------------
func buy_tech(tech_type: String) -> bool:
	var t_data: Dictionary = Data.get_tech(tech_type)
	if t_data.is_empty():
		return false

	if unlocked_techs.has(tech_type):
		return false

	# Prerequisite chain (e.g. Drone Lv.2 requires Drone Lv.1)
	var prereq: String = str(t_data.get("requires", ""))
	if not prereq.is_empty() and not unlocked_techs.has(prereq):
		return false

	var cost: int = int(t_data.get("cost", 800))
	if not EconomyManager.deduct_cash(cost):
		return false

	unlocked_techs.append(tech_type)
	tech_unlocked.emit(tech_type)
	return true

## Returns the owned Farm Drone level derived from the placed & upgraded Drone Command Hangar:
## 0 = no active hangar, 1 = plow, 2 = +plant, 3 = +harvest
func get_drone_level() -> int:
	var max_lvl: int = 0
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "drone_station" and b.state == b.BuildingState.ACTIVE:
			max_lvl = maxi(max_lvl, b.level)
	if max_lvl > 0:
		return clampi(max_lvl, 1, 3)

	# Fallback check for legacy unlocked tech
	if unlocked_techs.has("farm_drone_3"):
		return 3
	if unlocked_techs.has("farm_drone_2"):
		return 2
	if unlocked_techs.has("farm_drone_1"):
		return 1
	return 0

func get_drone_station() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "drone_station" and b.state == b.BuildingState.ACTIVE:
			return b
	return null

func has_drone_station() -> bool:
	return get_drone_station() != null

func get_drone_capacity() -> int:
	if not has_drone_station():
		return 0
	return active_workers

func can_commission_drone() -> bool:
	if not has_drone_station():
		return false
	return active_drones < active_workers

func commission_drone(cost: int = 350) -> bool:
	if not can_commission_drone():
		return false
	if not EconomyManager.deduct_cash(cost):
		return false
	active_drones += 1
	drone_commissioned.emit(active_drones)
	return true

# ---------------------------------------------------------------------------
# Meteorological Telemetry & Weather Stations
# ---------------------------------------------------------------------------
func get_weather_station() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "weather_station" and b.state == b.BuildingState.ACTIVE:
			return b
	return null

func has_weather_station() -> bool:
	return get_weather_station() != null

## Returns the active Weather Station equipment tier:
## 0 = None (Farmer Almanac), 1 = AM Radio Mast, 2 = AWS Station, 3 = Satellite Uplink Dish
func get_weather_station_level() -> int:
	var max_lvl: int = 0
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "weather_station" and b.state == b.BuildingState.ACTIVE:
			max_lvl = maxi(max_lvl, b.level)
	if max_lvl > 0:
		return clampi(max_lvl, 1, 3)

	# Fallback support for legacy unlocked tech
	if unlocked_techs.has("iot_soil_sensor"):
		return 3
	elif unlocked_techs.has("aws_station"):
		return 2
	elif unlocked_techs.has("radio_tower"):
		return 1
	return 0

## Forecast accuracy ratio (0.35 = almanac, 0.60 = radio, 0.90 = AWS, 1.00 = satellite)
func get_forecast_accuracy() -> float:
	match get_weather_station_level():
		1: return 0.60
		2: return 0.90
		3: return 1.00
		_: return 0.35

## Number of reliable future forecast days
func get_forecast_days() -> int:
	match get_weather_station_level():
		1: return 1
		2: return 3
		3: return 7
		_: return 0

## Reaction window seconds before an incoming regional disaster strikes
func get_disaster_warning_time() -> float:
	match get_weather_station_level():
		1: return 8.0
		2: return 12.0
		3: return 18.0
		_: return 5.0

func get_weather_station_tier_name() -> String:
	match get_weather_station_level():
		1: return "AM Radio Mast (Lv.1)"
		2: return "Automated Weather Station (AWS, Lv.2)"
		3: return "Satellite Uplink Dish (Lv.3)"
		_: return "Farmer Almanac"

func get_weather_station_badge() -> String:
	match get_weather_station_level():
		1: return "📻 AM 60%"
		2: return "🌦️ AWS 90%"
		3: return "🛰️ SAT 100%"
		_: return "📜 35%"

func get_weather_station_upgrade_perks(to_level: int) -> String:
	match to_level:
		2: return "+2 Forecast Days (3-Day Outlook) • 90% Radar Accuracy • +4s Disaster Warning"
		3: return "+4 Forecast Days (7-Day Outlook) • 100% Precision Radar • +6s Disaster Warning"
		_: return "Advanced Meteorological Telemetry"

# ---------------------------------------------------------------------------
# Irrigation Infrastructure & Automated Water Towers
# ---------------------------------------------------------------------------
func get_irrigation_tower() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "water_tower" and b.state == b.BuildingState.ACTIVE:
			return b
	return null

func has_irrigation() -> bool:
	return get_irrigation_tower() != null or unlocked_techs.has("drip_irrigation")

## Active irrigation infrastructure level:
## 0 = Manual Pail, 1 = Well Pump, 2 = Elevated Water Tower, 3 = Solar Drip Net
func get_irrigation_level() -> int:
	var max_lvl: int = 0
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "water_tower" and b.state == b.BuildingState.ACTIVE:
			max_lvl = maxi(max_lvl, b.level)
	if max_lvl > 0:
		return clampi(max_lvl, 1, 3)

	# Fallback if bought via legacy tech
	if unlocked_techs.has("drip_irrigation"):
		return 2
	return 0

func get_irrigation_tier_name() -> String:
	match get_irrigation_level():
		1: return "Groundwater Well Pump (Lv.1)"
		2: return "Elevated Water Tower (Lv.2)"
		3: return "Solar Drip Network (Lv.3)"
		_: return "Manual Pail / Timba"

func get_irrigation_badge() -> String:
	match get_irrigation_level():
		1: return "🚰 Well +5%"
		2: return "💧 Tower +12%"
		3: return "☀️ Drip Auto"
		_: return "🪣 Manual"

## Hourly evaporation reduction ratio (0.0 to 0.35)
func get_irrigation_evap_reduction() -> float:
	match get_irrigation_level():
		1: return 0.10
		2: return 0.25
		3: return 0.35
		_: return 0.0

## Target soil moisture for a crop when auto-irrigated
func get_irrigation_target_moisture(req_min: float, req_max: float) -> float:
	match get_irrigation_level():
		1: return minf(req_min + 5.0, 90.0)
		2: return minf(req_min + 12.0, 90.0)
		3: return clampf((req_min + req_max) * 0.52, req_min + 8.0, 85.0)
		_: return req_min

## Sprinklers supported by water pressure: 0 if no tower, 6 at Lv.1, 16 at Lv.2, 999 (unlimited) at Lv.3
func get_sprinkler_capacity() -> int:
	match get_irrigation_level():
		1: return 6
		2: return 16
		3: return 999
		_: return 0

func get_active_sprinkler_count() -> int:
	var count: int = 0
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "sprinkler":
			count += 1
	return count

func can_place_sprinkler() -> bool:
	return has_irrigation() and get_active_sprinkler_count() < get_sprinkler_capacity()

## Sprinkler coverage radius: radius 1 = 3x3 diamond (8 surrounding plots); radius 2 = 5x5 diamond (24 surrounding plots)
func get_sprinkler_radius() -> int:
	return 2 if get_irrigation_level() >= 2 else 1

## True if a given grid tile is covered by any active sprinkler's spray radius
func is_tile_covered_by_sprinkler(tile_pos: Vector2i) -> bool:
	return get_covering_sprinkler(tile_pos) != null

func get_covering_sprinkler(tile_pos: Vector2i) -> Node:
	var rad: int = get_sprinkler_radius()
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "sprinkler" and b.state == b.BuildingState.ACTIVE:
			var d: Vector2i = tile_pos - b.grid_pos
			if absi(d.x) <= rad and absi(d.y) <= rad:
				return b
	return null

func get_all_sprinklers() -> Array:
	var list: Array = []
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "sprinkler" and b.state == b.BuildingState.ACTIVE:
			list.append(b)
	return list

# ---------------------------------------------------------------------------
# Bayanihan Cooperative Center & Communal Field Directives
# ---------------------------------------------------------------------------
func get_bayanihan_center() -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "bayanihan_center" and b.state == b.BuildingState.ACTIVE:
			return b
	return null

func has_bayanihan_center() -> bool:
	return get_bayanihan_center() != null

func get_bayanihan_center_level() -> int:
	var max_lvl: int = 0
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "bayanihan_center" and b.state == b.BuildingState.ACTIVE:
			max_lvl = maxi(max_lvl, b.level)
	return max_lvl

func set_bayanihan_directive(parcel_id: String, directive: Dictionary) -> void:
	bayanihan_directives[parcel_id] = directive
	directive_changed.emit(parcel_id, directive)

func get_bayanihan_directive(parcel_id: String) -> Dictionary:
	return bayanihan_directives.get(parcel_id, {"mode": "manual", "crop": "palay"})

func get_cooperative_tier_name() -> String:
	if get_bayanihan_center_level() > 0:
		return "Biyahero Trading Post"
	return "Independent Labor (Manual)"

func get_cooperative_badge() -> String:
	if get_bayanihan_center_level() > 0:
		return "🤝 Biyahero +%d%%" % int(round(get_biyahero_price_bonus() * 100.0))
	return "⛏️ Manual"

# Backward-compatibility stubs for legacy queries
func get_machine_garage() -> Node: return null
func has_machine_garage() -> bool: return false
func get_machine_garage_level() -> int: return 0
func has_kuliglig() -> bool: return false
func has_combine_harvester() -> bool: return false
func get_machinery_tier_name() -> String: return get_cooperative_tier_name()
func get_machinery_badge() -> String: return get_cooperative_badge()

func hire_worker() -> bool:
	if active_workers >= worker_capacity:
		return false # Need Bahay Kubo for more worker housing

	var hire_cost: int = 200
	if not EconomyManager.deduct_cash(hire_cost):
		return false

	active_workers += 1
	worker_hired.emit(active_workers)
	worker_capacity_changed.emit(worker_capacity, active_workers)
	return true

func has_tech(tech_type: String) -> bool:
	if tech_type == "drip_irrigation" and has_irrigation():
		return true
	if tech_type == "kuliglig" and has_kuliglig():
		return true
	if tech_type == "combine_harvester" and has_combine_harvester():
		return true
	if tech_type == "radio_tower" and get_weather_station_level() >= 1:
		return true
	if tech_type == "aws_station" and get_weather_station_level() >= 2:
		return true
	if tech_type == "iot_soil_sensor" and get_weather_station_level() >= 3:
		return true
	return unlocked_techs.has(tech_type)

func has_building(building_type: String) -> bool:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == building_type and b.state == b.BuildingState.ACTIVE:
			return true
	return false

## True for one-time buildings (tower, weather station, depot, hangar) that are upgraded in place.
func is_unique_building(building_type: String) -> bool:
	return bool(Data.get_building(building_type).get("unique", false))

## First placed building of this type in ANY state (constructing, upgrading, active), or null.
func get_building_of_type(building_type: String) -> Node:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == building_type:
			return b
	return null

## True if this building type already exists (including under construction).
func owns_building(building_type: String) -> bool:
	return get_building_of_type(building_type) != null

func get_worker_speed_multiplier() -> float:
	# The Biyahero Trading Post no longer affects worker speed (it is a market buff only).
	return 1.0

## Extra price multiplier when selling to the Local Biyahero (0.0 without an active Trading Post).
func get_biyahero_price_bonus() -> float:
	if has_building("bayanihan_center"):
		return float(Data.get_building("bayanihan_center").get("biyahero_price_bonus", 0.08))
	return 0.0

## True if the Sell Hub is usable (no requirement, or its building is active).
func is_hub_unlocked(hub_id: String) -> bool:
	return Data.is_hub_available(hub_id)

## True once the Field Survey Kit (F-key heatmap) has been purchased.
func has_heatmap() -> bool:
	return unlocked_techs.has("field_survey_kit")

func has_cold_storage() -> bool:
	return has_building("cold_storage") or has_building("climate_silo")

func get_storage_status() -> Dictionary:
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr and m_mgr.has_method("get_total_stored_units"):
		used_storage = m_mgr.get_total_stored_units()
	return {"capacity": total_storage_capacity, "used": used_storage}

func can_store(amount: int = 1) -> bool:
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr and m_mgr.has_method("get_total_stored_units"):
		used_storage = m_mgr.get_total_stored_units()
	return (used_storage + amount) <= total_storage_capacity

func is_storage_full() -> bool:
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr and m_mgr.has_method("get_total_stored_units"):
		used_storage = m_mgr.get_total_stored_units()
	return used_storage >= total_storage_capacity

func get_remaining_storage() -> int:
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr and m_mgr.has_method("get_total_stored_units"):
		used_storage = m_mgr.get_total_stored_units()
	return maxi(total_storage_capacity - used_storage, 0)

## Returns all active storage facility buildings (Bodega, Cold Storage, Climate Silo)
func get_storage_buildings() -> Array:
	var list: Array = []
	for b in placed_buildings:
		if is_instance_valid(b) and b.state == b.BuildingState.ACTIVE:
			if b.has_method("is_storage_building") and b.is_storage_building():
				list.append(b)
			elif int(Data.get_building(b.building_type).get("storage_limit", 0)) > 0:
				list.append(b)
	return list

## Finds the best active storage building that accepts this crop and has space.
## Priority:
## 1. Explicitly assigned storage buildings (where crop is in assigned_crops)
## 2. Cold storage / climate silo for perishable crops
## 3. General unassigned storage buildings with available capacity
func get_best_storage_for_crop(crop_name: String, amount: int = 100) -> Node:
	var candidates := get_storage_buildings()
	if candidates.is_empty():
		return null

	var is_perishable: bool = (crop_name in ["arabica_coffee", "banana", "pineapple", "coconut"])
	var explicit_matches: Array = []
	var general_matches: Array = []

	for b in candidates:
		if not b.has_space(amount):
			continue
		if b.assigned_crops.size() > 0:
			if b.assigned_crops.has(crop_name):
				explicit_matches.append(b)
		else:
			general_matches.append(b)

	# 1. Prefer explicit assignments
	if not explicit_matches.is_empty():
		# If perishable, prefer cold storage within explicit matches
		if is_perishable:
			for b in explicit_matches:
				if b.building_type in ["cold_storage", "climate_silo"]:
					return b
		# Pick the one with the most free space
		explicit_matches.sort_custom(func(a, b):
			var free_a: int = a.get_storage_capacity() - a.used_storage
			var free_b: int = b.get_storage_capacity() - b.used_storage
			return free_a > free_b
		)
		return explicit_matches[0]

	# 2. Prefer cold storage for perishables among general storages
	if is_perishable:
		for b in general_matches:
			if b.building_type in ["cold_storage", "climate_silo"]:
				return b

	# 3. Fallback to general storage with most free space
	if not general_matches.is_empty():
		general_matches.sort_custom(func(a, b):
			var free_a: int = a.get_storage_capacity() - a.used_storage
			var free_b: int = b.get_storage_capacity() - b.used_storage
			return free_a > free_b
		)
		return general_matches[0]

	return null

## Checks whether there is active storage capacity accepting this specific crop
func has_storage_for_crop(crop_name: String, amount: int = 100) -> bool:
	return get_best_storage_for_crop(crop_name, amount) != null

func is_storage_full_for_crop(crop_name: String, amount: int = 100) -> bool:
	return not has_storage_for_crop(crop_name, amount)

# ---------------------------------------------------------------------------
# Agro-Industrial Milling & Value-Added Automated Processing Loop
# ---------------------------------------------------------------------------
func _on_hour_changed(hour: int) -> void:
	# Automated milling run triggers every 4 in-game hours
	if hour % 4 != 0:
		return
	_process_industrial_facilities()

func _process_industrial_facilities() -> void:
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr == null:
		return

	# Iterate over all placed buildings to check for industrial facilities
	for b in placed_buildings:
		if not is_instance_valid(b) or b.state != b.BuildingState.ACTIVE:
			continue
		var b_data: Dictionary = Data.get_building(b.building_type)
		var recipe: Dictionary = b_data.get("recipe", {})
		if recipe.is_empty():
			continue

		var input_crop: String = str(recipe.get("input_crop", ""))
		var input_qty: int     = int(recipe.get("input_qty", 0))
		var outputs: Array     = recipe.get("outputs", [])

		if input_crop.is_empty() or input_qty <= 0 or outputs.is_empty():
			continue

		# Verify raw crop availability in stored inventory
		if m_mgr.get_stored_units_for_crop(input_crop) >= input_qty:
			# Verify storage capacity headroom
			var total_output_qty: int = 0
			for out_item in outputs:
				total_output_qty += int(out_item.get("qty", 0))
			var net_growth: int = total_output_qty - input_qty
			if net_growth > 0 and not can_store(net_growth):
				continue # Grain silo full

			# Consume raw crop batches (prioritizing lowest freshness first)
			if m_mgr.consume_crop_quantity(input_crop, input_qty):
				var output_summaries: Array[String] = []
				for out_item in outputs:
					var item_name: String = str(out_item.get("item", ""))
					var out_qty: int      = int(out_item.get("qty", 0))
					var prod_d: Dictionary = Data.get_crop(item_name)
					var out_disp: String   = str(prod_d.get("display_name", item_name.capitalize())).split("(")[0].strip_edges()
					var out_icon: String   = str(prod_d.get("icon", "📦"))
					m_mgr.add_processed_to_storage(item_name, out_qty, "Grade A")
					output_summaries.append("%s %d %s" % [out_icon, out_qty, out_disp])

				var b_name: String = str(b_data.get("display_name", b.building_type.capitalize()))
				var b_icon: String = str(b_data.get("icon", "🏭"))
				var in_data: Dictionary = Data.get_crop(input_crop)
				var in_disp: String = str(in_data.get("display_name", input_crop.capitalize())).split("(")[0].strip_edges()
				
				# Log Chronicle Entry
				var log_msg: String = "%s automatically processed %d %s into %s!" % [
					b_name, input_qty, in_disp, ", ".join(output_summaries)
				]
				LogManager.log_event("processing", log_msg, b_icon, Color(0.40, 0.95, 0.65, 1.0))
				AudioManager.play_building("complete")
				batch_processed.emit(b_name, input_crop, input_qty, outputs)

## Validates mid-to-late game prerequisites for establishing agro-industrial processing facilities
func get_processing_prerequisites(facility_type: String) -> Dictionary:
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	var has_land_deed: bool = false
	if farm_grid and "unlocked_parcels" in farm_grid:
		has_land_deed = farm_grid.unlocked_parcels.size() > 1
	var has_storage_cap: bool = (total_storage_capacity >= 400) or has_cold_storage()
	var can_build: bool = has_land_deed and has_storage_cap

	var reasons: Array[String] = []
	if not has_land_deed:
		reasons.append("Requires Land Expansion Deed")
	if not has_storage_cap:
		reasons.append("Requires Lv.2 Silo (400+ cap) or Cold Storage")

	return {
		"allowed": can_build,
		"has_land_deed": has_land_deed,
		"has_storage_cap": has_storage_cap,
		"reasons": reasons,
		"requirement_text": " • ".join(reasons) if not reasons.is_empty() else "All requirements met"
	}
