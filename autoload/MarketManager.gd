# MarketManager.gd
# Handles supply/demand, dynamic pricing, storage inventory, logistics distance costs, and road ROT/spoilage.

extends Node

signal price_updated(crop: String, price: float)
signal inventory_changed()
signal sale_completed(crop: String, revenue: int, net_profit: int, hub_name: String, rot_loss: float)

# Internal tracking of regional market supply and demand per crop
var regional_supply: Dictionary = {}
var regional_demand: Dictionary = {}

# 7-day price history tracking for stock charts: { crop_name: Array[float] }
var price_history: Dictionary = {}

# Stored crop batches: [{"id": int, "crop": String, "quantity": int, "grade": String, "freshness": float, "is_cold_storage": bool}]
var stored_inventory: Array = []
var _next_batch_id: int = 1

const DISASTER_PRICE_BOOST: float = 2.20  # 220% price surge (shortage spike) during regional disasters
const SPOILAGE_RATE_PER_HOUR: float = 5.0 # 5% per hour in basic bodega

func _ready() -> void:
	for crop_name in Data.CROPS.keys():
		regional_supply[crop_name] = randf_range(400.0, 600.0)
		regional_demand[crop_name] = randf_range(450.0, 550.0)
		_init_crop_history(crop_name)
	call_deferred("_sync_storage_with_building_manager")

## Initialize 7 days of realistic price history ending at today's price
func _init_crop_history(crop_name: String) -> void:
	var base: float = float(Data.get_crop(crop_name).get("base_price", 100))
	var hist: Array[float] = []
	var curr_price: float = get_benchmark_price(crop_name)
	
	# Generate 6 preceding days with natural fluctuation around base price
	var running_p: float = curr_price * randf_range(0.88, 1.12)
	for i in range(6):
		var drift: float = randf_range(-0.08, 0.08)
		running_p = clampf(running_p * (1.0 + drift), base * 0.55, base * 1.65)
		hist.append(roundf(running_p))
	hist.append(roundf(curr_price))
	price_history[crop_name] = hist

## Pure standard benchmark market price (100% baseline, Grade A, 100% fresh)
func get_benchmark_price(crop_name: String) -> float:
	return calculate_unit_price(crop_name, "Grade A", 100.0, "market_index")

## Returns copy of 7-day price history array for a crop
func get_price_history(crop_name: String) -> Array:
	if not price_history.has(crop_name):
		_init_crop_history(crop_name)
	return price_history[crop_name].duplicate()

## Returns price change metrics: { current, previous, diff, percent, is_up }
func get_price_change(crop_name: String) -> Dictionary:
	var hist: Array = get_price_history(crop_name)
	var current_p: float = hist[-1] if hist.size() > 0 else get_benchmark_price(crop_name)
	var prev_p: float = hist[-2] if hist.size() > 1 else current_p
	var diff: float = current_p - prev_p
	var pct: float = (diff / maxf(prev_p, 1.0)) * 100.0
	return {
		"current": current_p,
		"previous": prev_p,
		"diff": diff,
		"percent": pct,
		"is_up": diff >= 0.0,
	}

## Returns total units of a crop in stored inventory
func get_stored_units_for_crop(crop_name: String) -> int:
	var total: int = 0
	for b in stored_inventory:
		if b.get("crop", "") == crop_name:
			total += int(b.get("quantity", 0))
	return total

## Refresh daily market conditions at midnight tick
func refresh_daily_prices() -> void:
	for crop_name in Data.CROPS.keys():
		# Market consumption reduces supply
		var current_s: float = regional_supply.get(crop_name, 500.0)
		regional_supply[crop_name] = maxf(current_s * randf_range(0.85, 0.95), 200.0)
		# Demand shifts slightly each day
		var current_d: float = regional_demand.get(crop_name, 500.0)
		regional_demand[crop_name] = clampf(current_d * randf_range(0.92, 1.08), 300.0, 800.0)
		
		var p: float = get_benchmark_price(crop_name)
		if not price_history.has(crop_name):
			_init_crop_history(crop_name)
		else:
			price_history[crop_name].append(roundf(p))
			if price_history[crop_name].size() > 7:
				price_history[crop_name].pop_front()

		price_updated.emit(crop_name, p)

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
	_sync_storage_with_building_manager()
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

## Calculate unit price considering quality, freshness, destination distance, and regional supply/demand
func calculate_unit_price(crop: String, grade: String, freshness: float, hub_id: String) -> float:
	var crop_data: Dictionary = Data.get_crop(crop)
	var base_price: float = float(crop_data.get("base_price", 100))
	
	# Quality grade multiplier
	var grade_mult: float = 0.4
	match grade:
		"Grade A": grade_mult = 1.0
		"Grade B": grade_mult = 0.7
		"Grade C": grade_mult = 0.4

	# Solar dryer bonus (+25% quality boost for grains: palay & corn)
	if BuildingManager.has_building("solar_dryer") and (crop == "palay" or crop == "yellow_corn"):
		grade_mult = minf(grade_mult * 1.25, 1.25)

	var freshness_factor: float = clampf(freshness / 100.0, 0.05, 1.0)
	
	# Severe ROT discount if produce rots below 25% freshness
	if freshness < 25.0:
		freshness_factor *= 0.35 # 65% loss for rotting produce

	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var hub_multiplier: float = float(hub_data.get("price_multiplier", 1.0))

	# Night cycle market effect:
	# Local middleman (biyahero) exploits late night off-hours visits with predatory pricing
	if TimeManager.is_night() and hub_id == "local_biyahero":
		hub_multiplier = 0.62 # Off-hours discount down from 0.72
	
	# Demand / Supply ratio
	var supply: float = float(regional_supply.get(crop, 500.0))
	var demand: float = float(regional_demand.get(crop, 500.0))
	var ratio: float = clampf(demand / maxf(supply, 100.0), 0.50, 1.50)
	
	# Regional disaster shortages spike prices up to 200-300%
	var disaster_factor: float = 1.0
	if WeatherManager.current_climate != WeatherManager.Climate.NORMAL:
		disaster_factor = DISASTER_PRICE_BOOST

	return base_price * grade_mult * freshness_factor * ratio * hub_multiplier * disaster_factor

## Sell a specific stored batch with distance logistics, fuel expenses, and road ROT decay
func sell_stored_batch(batch_index: int, hub_id: String) -> bool:
	if batch_index < 0 or batch_index >= stored_inventory.size():
		return false
	
	var batch: Dictionary = stored_inventory[batch_index]
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var fuel_cost: int = int(hub_data.get("fuel_cost", 0))
	var road_rot_percent: float = float(hub_data.get("rot_risk_percent", 0.0))

	# Overnight Logistics: Cool night temperatures reduce road rot by 40%, but require ₱25 night driver fee
	if TimeManager.is_night() and hub_id != "local_biyahero":
		road_rot_percent *= 0.60
		fuel_cost += 25
	
	if EconomyManager.cash < fuel_cost:
		# Cannot afford transport fuel
		return false

	# Calculate Road ROT / Spoilage during transit
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

	# Update market supply: Dumping 50+ units (tons) floods local market, dropping prices up to 50%
	var dump_multiplier: float = 2.5 if batch.quantity >= 50 else 1.0
	regional_supply[batch.crop] = float(regional_supply.get(batch.crop, 500.0)) + float(batch.quantity) * dump_multiplier
	var new_bench_p: float = get_benchmark_price(batch.crop)
	if price_history.has(batch.crop) and price_history[batch.crop].size() > 0:
		price_history[batch.crop][-1] = roundf(new_bench_p)
	price_updated.emit(batch.crop, new_bench_p)
	
	var hub_name: String = hub_data.get("display_name", hub_id)
	sale_completed.emit(batch.crop, gross_revenue, net_profit, hub_name, road_rot_percent)

	# Award end-game leaderboard prestige points
	LeaderboardManager.record_sale(batch.crop, batch.quantity, batch.grade, arrival_freshness, hub_id)

	stored_inventory.remove_at(batch_index)
	_sync_storage_with_building_manager()
	inventory_changed.emit()
	return true

## Returns total units of all crops currently held in farm storage
func get_total_stored_units() -> int:
	var total: int = 0
	for batch in stored_inventory:
		total += int(batch.get("quantity", 0))
	return total

func _sync_storage_with_building_manager() -> void:
	var b_mgr = get_node_or_null("/root/BuildingManager")
	if b_mgr:
		b_mgr.used_storage = get_total_stored_units()
		b_mgr.storage_updated.emit(b_mgr.total_storage_capacity, b_mgr.used_storage)

## Summary of all crops in storage grouped by crop
func get_stored_crop_summary() -> Array:
	var map: Dictionary = {}
	for b in stored_inventory:
		var c: String = b.get("crop", "")
		if not map.has(c):
			map[c] = {"crop": c, "total_quantity": 0, "fresh_sum": 0.0, "batch_count": 0}
		map[c]["total_quantity"] += int(b.get("quantity", 0))
		map[c]["fresh_sum"] += float(b.get("freshness", 100.0)) * float(b.get("quantity", 0))
		map[c]["batch_count"] += 1

	var result: Array = []
	for c in map.keys():
		var entry = map[c]
		var total_q: int = entry["total_quantity"]
		var avg_f: float = entry["fresh_sum"] / maxf(float(total_q), 1.0)
		result.append({
			"crop": c,
			"total_quantity": total_q,
			"avg_freshness": avg_f,
			"batch_count": entry["batch_count"]
		})
	return result

## Previews total sale value, fuel, rot, and net profit for all stored units of a crop
func preview_crop_sale(crop_name: String, hub_id: String) -> Dictionary:
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var fuel_cost: int = int(hub_data.get("fuel_cost", 0))
	var has_cold: bool = BuildingManager.has_cold_storage()
	var road_rot: float = float(hub_data.get("rot_risk_percent", 0.0))
	var is_night: bool = TimeManager.is_night()
	var night_fee: int = 0

	# Overnight logistics: Cool night highway transit reduces road decay by 40% (+₱25 night driver fee)
	if is_night and hub_id != "local_biyahero":
		road_rot *= 0.60
		night_fee = 25
		fuel_cost += night_fee

	if has_cold:
		road_rot = 0.0

	var total_qty: int = 0
	var total_gross: int = 0
	var total_preview_pts: int = 0
	for b in stored_inventory:
		if b.get("crop", "") == crop_name:
			var arrival_fresh: float = maxf(b.freshness - road_rot, 0.0)
			var unit_p: float = calculate_unit_price(b.crop, b.grade, arrival_fresh, hub_id)
			var gross: int = int(unit_p * float(b.quantity))
			if arrival_fresh <= 0.0:
				gross = 0
			total_gross += gross
			total_qty += int(b.quantity)
			var pts_data = LeaderboardManager.calculate_sale_points(b.crop, int(b.quantity), b.grade, arrival_fresh, hub_id)
			total_preview_pts += int(pts_data.get("total_points", 0))

	var net_profit: int = total_gross - fuel_cost
	return {
		"quantity": total_qty,
		"gross": total_gross,
		"net": net_profit,
		"fuel": fuel_cost,
		"road_rot": road_rot,
		"has_cold": has_cold,
		"is_loss": net_profit < 0,
		"can_afford_fuel": EconomyManager.cash >= fuel_cost,
		"is_night": is_night,
		"night_fee": night_fee,
		"points": total_preview_pts
	}

## Sells all stored batches of a specific crop in one clean action
func sell_all_of_crop(crop_name: String, hub_id: String) -> Dictionary:
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var fuel_cost: int = int(hub_data.get("fuel_cost", 0))
	var has_cold: bool = BuildingManager.has_cold_storage()
	var road_rot: float = float(hub_data.get("rot_risk_percent", 0.0))

	# Overnight logistics: Cool night highway transit reduces road decay by 40% (+₱25 night driver fee)
	if TimeManager.is_night() and hub_id != "local_biyahero":
		road_rot *= 0.60
		fuel_cost += 25

	if has_cold:
		road_rot = 0.0

	if EconomyManager.cash < fuel_cost:
		return {"success": false, "error": "insufficient_fuel", "fuel": fuel_cost}

	var matching_indices: Array[int] = []
	for i in range(stored_inventory.size()):
		if stored_inventory[i].get("crop", "") == crop_name:
			matching_indices.append(i)

	if matching_indices.is_empty():
		return {"success": false, "error": "no_batches"}

	var total_qty: int = 0
	var total_gross: int = 0
	var total_points_earned: int = 0

	for idx in matching_indices:
		var b: Dictionary = stored_inventory[idx]
		var arrival_fresh: float = maxf(b.freshness - road_rot, 0.0)
		var unit_p: float = calculate_unit_price(b.crop, b.grade, arrival_fresh, hub_id)
		var gross: int = int(unit_p * float(b.quantity))
		if arrival_fresh <= 0.0:
			gross = 0
		total_gross += gross
		total_qty += int(b.quantity)

		var earned_pts: int = LeaderboardManager.record_sale(b.crop, int(b.quantity), b.grade, arrival_fresh, hub_id)
		total_points_earned += earned_pts

	var net_profit: int = total_gross - fuel_cost

	EconomyManager.deduct_cash(fuel_cost)
	if total_gross > 0:
		EconomyManager.add_cash(total_gross)

	var dump_multiplier: float = 2.5 if total_qty >= 50 else 1.0
	regional_supply[crop_name] = float(regional_supply.get(crop_name, 500.0)) + float(total_qty) * dump_multiplier
	var new_bench_p: float = get_benchmark_price(crop_name)
	if price_history.has(crop_name) and price_history[crop_name].size() > 0:
		price_history[crop_name][-1] = roundf(new_bench_p)
	price_updated.emit(crop_name, new_bench_p)

	var hub_name: String = hub_data.get("display_name", hub_id)
	sale_completed.emit(crop_name, total_gross, net_profit, hub_name, road_rot)

	matching_indices.reverse()
	for idx in matching_indices:
		stored_inventory.remove_at(idx)

	_sync_storage_with_building_manager()
	inventory_changed.emit()
	return {
		"success": true,
		"quantity": total_qty,
		"gross": total_gross,
		"net": net_profit,
		"fuel": fuel_cost,
		"hub_name": hub_name,
		"points": total_points_earned
	}

func calculate_sale_value(crop: String, grade: String, freshness: float) -> float:
	return calculate_unit_price(crop, grade, freshness, "local_biyahero")

func register_harvest(crop: String, quantity: int) -> void:
	regional_supply[crop] = regional_supply.get(crop, 0) + quantity
