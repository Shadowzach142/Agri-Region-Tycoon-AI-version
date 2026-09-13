# BuildingManager.gd
# Handles farm infrastructure, storage limits, machinery speed bonuses, and worker housing capacity.

extends Node

signal building_purchased(building_type: String)
signal tech_unlocked(tech_type: String)
signal storage_updated(total_capacity: int, used_capacity: int)
signal worker_hired(total_workers: int)

var placed_buildings: Dictionary = {} # "x_y" or building_type -> count
var purchased_buildings: Dictionary = {} # building_type -> count
var unlocked_techs: Array = []

var total_storage_capacity: int = 0
var used_storage: int = 0

var worker_capacity: int = 1
var active_workers: int = 1

func _ready() -> void:
	pass

func buy_building(building_type: String) -> bool:
	var b_data: Dictionary = Data.get_building(building_type)
	if b_data.is_empty():
		return false

	var cost: int = int(b_data.get("cost", 500))
	if not EconomyManager.deduct_cash(cost):
		return false

	purchased_buildings[building_type] = purchased_buildings.get(building_type, 0) + 1
	placed_buildings[building_type] = placed_buildings.get(building_type, 0) + 1

	var storage_limit: int = int(b_data.get("storage_limit", 0))
	if storage_limit > 0:
		total_storage_capacity += storage_limit
		storage_updated.emit(total_storage_capacity, used_storage)

	var capacity_add: int = int(b_data.get("worker_capacity", 0))
	if capacity_add > 0:
		worker_capacity += capacity_add

	building_purchased.emit(building_type)
	return true

func buy_tech(tech_type: String) -> bool:
	var t_data: Dictionary = Data.get_tech(tech_type)
	if t_data.is_empty():
		return false

	if unlocked_techs.has(tech_type):
		return false # Already owned

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
	return purchased_buildings.get(building_type, 0) > 0

func get_worker_speed_multiplier() -> float:
	if has_tech("combine_harvester"):
		return 3.5
	elif has_tech("kuliglig"):
		return 1.8
	return 1.0

func has_cold_storage() -> bool:
	return has_building("cold_storage") or has_building("climate_silo")

func get_storage_status() -> Dictionary:
	return {"capacity": total_storage_capacity, "used": used_storage}
