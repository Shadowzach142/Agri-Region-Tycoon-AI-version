# BuildingManager.gd
# Handles farm infrastructure, storage limits, machinery bonuses, placed buildings, and worker housing capacity.
# Supports WoW / Clash of Clans building mechanics (placement, construction timers, level upgrades).

extends Node

signal building_purchased(building_type: String)
signal tech_unlocked(tech_type: String)
signal storage_updated(total_capacity: int, used_capacity: int)
signal worker_hired(total_workers: int)
signal building_placed(building: Node)

var placed_buildings: Array = []          # Array of placed Building instances
var purchased_buildings: Dictionary = {} # building_type -> count (for backward compatibility)
var unlocked_techs: Array = []

var total_storage_capacity: int = 1000
var used_storage: int = 0

var worker_capacity: int = 1
var active_workers: int = 1

func _ready() -> void:
	pass

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
	var new_storage: int = 1000
	var new_workers: int = 1

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
			new_workers += lvl

	total_storage_capacity = new_storage
	worker_capacity = new_workers

	storage_updated.emit(total_storage_capacity, used_storage)
	worker_hired.emit(active_workers)

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

	var cost: int = int(t_data.get("cost", 800))
	if not EconomyManager.deduct_cash(cost):
		return false

	unlocked_techs.append(tech_type)
	tech_unlocked.emit(tech_type)
	return true

func hire_worker() -> bool:
	if active_workers >= worker_capacity:
		return false # Need Bahay Kubo for more worker housing

	var hire_cost: int = 200
	if not EconomyManager.deduct_cash(hire_cost):
		return false

	active_workers += 1
	worker_hired.emit(active_workers)
	return true

func has_tech(tech_type: String) -> bool:
	return unlocked_techs.has(tech_type)

func has_building(building_type: String) -> bool:
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == building_type and b.state == b.BuildingState.ACTIVE:
			return true
	return false

func get_worker_speed_multiplier() -> float:
	var mult: float = 1.0
	if has_tech("combine_harvester"):
		mult = 3.5
	elif has_tech("kuliglig"):
		mult = 1.8

	# Machine Garage level speed bonus
	for b in placed_buildings:
		if is_instance_valid(b) and b.building_type == "machine_garage" and b.state == b.BuildingState.ACTIVE:
			mult += 0.10 + (b.level - 1) * 0.15
			break

	return mult

func has_cold_storage() -> bool:
	return has_building("cold_storage") or has_building("climate_silo")

func get_storage_status() -> Dictionary:
	return {"capacity": total_storage_capacity, "used": used_storage}
