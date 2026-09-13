# MarketManager.gd
# Handles supply/demand, dynamic pricing, storage inventory, logistics distance costs, and road ROT/spoilage.

extends Node

signal price_updated(crop: String, price: float)
signal inventory_changed()
signal sale_completed(crop: String, revenue: int, net_profit: int, hub_name: String, rot_loss: float)

# Internal tracking of regional market supply per crop
var regional_supply: Dictionary = {}

# Stored crop batches: [{"id": int, "crop": String, "quantity": int, "grade": String, "freshness": float, "is_cold_storage": bool}]
var stored_inventory: Array = []
var _next_batch_id: int = 1

const SUPPLY_PRICE_FACTOR: float = 0.50   # Up to 50% price drop at massive surplus
const DISASTER_PRICE_BOOST: float = 1.80  # Up to 80% price surge during shortages
const SPOILAGE_RATE_PER_HOUR: float = 5.0 # 5% per hour in basic bodega

func _ready() -> void:
	for crop_name in Data.CROPS.keys():
		regional_supply[crop_name] = randi_range(200, 800)

## Add harvested crop batch to farm storage
func add_harvest_to_storage(crop: String, quantity: int, grade: String, freshness: float) -> void:
	var has_cold: bool = BuildingManager.has_cold_storage()
	var batch: Dictionary = {
		"id": _next_batch_id,
		"crop": crop,
		"quantity": quantity,
		"grade": grade,
		"freshness": freshness,
		"is_cold_storage": has_cold,
	}
	_next_batch_id += 1
	stored_inventory.append(batch)
	inventory_changed.emit()

## Called hourly from TimeManager to process spoilage/rot in storage
func process_hourly_spoilage() -> void:
	var updated: bool = false
	var has_cold: bool = BuildingManager.has_cold_storage()

	for batch in stored_inventory:
		if not batch.get("is_cold_storage", false) and not has_cold:
			batch["freshness"] = maxf(batch["freshness"] - SPOILAGE_RATE_PER_HOUR, 0.0)
			updated = true
	if updated:
		inventory_changed.emit()

## Calculate unit price considering quality, freshness, destination distance, and regional supply
func calculate_unit_price(crop: String, grade: String, freshness: float, hub_id: String) -> float:
	var crop_data: Dictionary = Data.get_crop(crop)
	var base_price: float = float(crop_data.get("base_price", 100))
	
	var grade_mult: float = 0.4
	match grade:
		"Grade A": grade_mult = 1.0
		"Grade B": grade_mult = 0.7
		"Grade C": grade_mult = 0.4

	var freshness_factor: float = clampf(freshness / 100.0, 0.1, 1.0)
	
	# Severe ROT discount if produce rots below 25% freshness
	if freshness < 25.0:
		freshness_factor *= 0.35 # 65% loss for rotten produce

	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var hub_multiplier: float = float(hub_data.get("price_multiplier", 1.0))
	
	# Supply impact
	var supply: float = float(regional_supply.get(crop, 500))
	var supply_factor: float = clampf(1.0 - (supply / 10000.0) * SUPPLY_PRICE_FACTOR, 0.5, 1.3)
	
	# Disaster impact
	var disaster_factor: float = 1.0
	if WeatherManager.current_climate != WeatherManager.Climate.NORMAL:
		disaster_factor = DISASTER_PRICE_BOOST

	return base_price * grade_mult * freshness_factor * hub_multiplier * supply_factor * disaster_factor

## Sell a specific stored batch with distance logistics, fuel expenses, and road ROT decay
func sell_stored_batch(batch_index: int, hub_id: String) -> bool:
	if batch_index < 0 or batch_index >= stored_inventory.size():
		return false
	
	var batch: Dictionary = stored_inventory[batch_index]
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var fuel_cost: int = int(hub_data.get("fuel_cost", 0))
	
	if EconomyManager.cash < fuel_cost:
		# Cannot afford transport fuel
		return false

	# Calculate Road ROT / Spoilage during transit
	var road_rot_percent: float = float(hub_data.get("rot_risk_percent", 0.0))
	if BuildingManager.has_cold_storage() or batch.get("is_cold_storage", false):
		road_rot_percent = 0.0 # Cold chain preserves 100% freshness

	var arrival_freshness: float = maxf(batch.freshness - road_rot_percent, 0.0)
	
	var unit_price: float = calculate_unit_price(batch.crop, batch.grade, arrival_freshness, hub_id)
	var gross_revenue: int = int(unit_price * float(batch.quantity))
	
	if arrival_freshness <= 0.0:
		# Total ROT spoilage! Yield was ruined in transit!
		gross_revenue = 0

	var net_profit: int = gross_revenue - fuel_cost

	EconomyManager.deduct_cash(fuel_cost)
	if gross_revenue > 0:
		EconomyManager.add_cash(gross_revenue)

	# Update market supply
	regional_supply[batch.crop] = regional_supply.get(batch.crop, 0) + batch.quantity
	price_updated.emit(batch.crop, unit_price)
	
	var hub_name: String = hub_data.get("display_name", hub_id)
	sale_completed.emit(batch.crop, gross_revenue, net_profit, hub_name, road_rot_percent)

	stored_inventory.remove_at(batch_index)
	inventory_changed.emit()
	return true

func calculate_sale_value(crop: String, grade: String, freshness: float) -> float:
	return calculate_unit_price(crop, grade, freshness, "local_biyahero")

func register_harvest(crop: String, quantity: int) -> void:
	regional_supply[crop] = regional_supply.get(crop, 0) + quantity
