# MarketManager.gd
# Handles per-region supply/demand, dynamic buy/sell pricing, storage inventory, logistics costs, and road ROT/spoilage.

extends Node

signal price_updated(crop: String, price: float)
signal market_region_updated(region_id: String, crop: String, price: float)
signal inventory_changed()
signal sale_completed(crop: String, revenue: int, net_profit: int, hub_name: String, rot_loss: float)

const DISASTER_PRICE_BOOST: float = 1.55  # +55% emergency shortage surge during active disasters
const SPOILAGE_RATE_PER_HOUR: float = 5.0 # 5% baseline freshness decay per hour in uncooled bodega

# External hubs map to real provincial markets so peer/AI volume ripples across shared trade corridors
const HUB_TO_REGION: Dictionary = {
	"tacurong": "sultan_kudarat",
	"koronadal": "south_cotabato",
	"gensan_port": "general_santos",
}

# Per-region market state: { region_id: { "supply": {}, "demand": {}, "history": {} } }
var region_markets: Dictionary = {}

# Active player's region aliases (kept in sync with SaveManager & legacy UI callers)
var regional_supply: Dictionary = {}
var regional_demand: Dictionary = {}
var price_history: Dictionary = {}

# Stored crop batches: [{"id": int, "crop": String, "quantity": int, "grade": String, "freshness": float, "is_cold_storage": bool}]
var stored_inventory: Array = []
var _next_batch_id: int = 1


func _ready() -> void:
	reset_for_new_session()


func _all_commodity_keys() -> Array:
	var keys: Array = []
	keys.append_array(Data.CROPS.keys())
	keys.append_array(Data.PROCESSED_GOODS.keys())
	return keys


func reset_for_new_session() -> void:
	stored_inventory.clear()
	_next_batch_id = 1
	region_markets.clear()

	for r_id in Data.REGIONS.keys():
		_init_single_region_market(r_id)

	_sync_active_aliases()
	call_deferred("_sync_storage_with_building_manager")
	inventory_changed.emit()


func _init_single_region_market(r_id: String) -> void:
	var supply: Dictionary = {}
	var demand: Dictionary = {}
	var history: Dictionary = {}

	for key in _all_commodity_keys():
		var is_proc: bool = Data.is_processed_good(key)
		var base_crop: String = str(Data.get_crop(key).get("source_crop", key)) if is_proc else key
		var is_spec: bool = Data.is_regional_specialty_crop(base_crop, r_id)
		if is_proc:
			supply[key] = randf_range(240.0, 360.0)
			demand[key] = randf_range(340.0, 480.0) if is_spec else randf_range(280.0, 400.0)
		else:
			supply[key] = randf_range(420.0, 560.0) if is_spec else randf_range(360.0, 500.0)
			demand[key] = randf_range(500.0, 620.0) if is_spec else randf_range(420.0, 540.0)

	region_markets[r_id] = {
		"supply": supply,
		"demand": demand,
		"history": history,
	}

	for key in _all_commodity_keys():
		_init_crop_history_for_region(key, r_id)


func _ensure_region_market(r_id: String) -> Dictionary:
	var resolved: String = r_id if Data.REGIONS.has(r_id) else Data.current_region
	if not region_markets.has(resolved):
		_init_single_region_market(resolved)
	return region_markets[resolved]


func _sync_active_aliases() -> void:
	var m: Dictionary = _ensure_region_market(Data.current_region)
	regional_supply = m["supply"]
	regional_demand = m["demand"]
	price_history = m["history"]


func set_active_region(region_id: String) -> void:
	_ensure_region_market(region_id)
	_sync_active_aliases()


## Export/Import helpers for ENet Multiplayer market synchronization & SaveManager compatibility
func export_all_markets() -> Dictionary:
	return region_markets.duplicate(true)


func import_all_markets(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	for r_id in payload.keys():
		var m = payload[r_id]
		if m is Dictionary:
			region_markets[r_id] = {
				"supply": m.get("supply", {}).duplicate(true),
				"demand": m.get("demand", {}).duplicate(true),
				"history": m.get("history", {}).duplicate(true),
			}
	_sync_active_aliases()
	for crop_name in _all_commodity_keys():
		price_updated.emit(crop_name, get_benchmark_price(crop_name))


## Initialize 7 days of realistic price history ending at today's price
func _init_crop_history_for_region(crop_name: String, r_id: String) -> void:
	var m: Dictionary = _ensure_region_market(r_id)
	var base: float = float(Data.get_crop(crop_name).get("base_price", 20))
	var hist: Array[float] = []
	var curr_price: float = get_benchmark_price_for_region(crop_name, r_id)

	var running_p: float = curr_price * randf_range(0.88, 1.12)
	for i in range(6):
		var drift: float = randf_range(-0.08, 0.08)
		running_p = clampf(running_p * (1.0 + drift), base * 0.55, base * 1.65)
		hist.append(_round_price(running_p))
	hist.append(_round_price(curr_price))
	m["history"][crop_name] = hist


func _init_crop_history(crop_name: String) -> void:
	_init_crop_history_for_region(crop_name, Data.current_region)
	_sync_active_aliases()


func _round_price(val: float) -> float:
	# Preserve 0.1 accuracy for low-denomination goods (e.g. Rice Bran ₱6, Palay ₱10)
	return snappedf(val, 0.1)


## Pure standard benchmark market price for active region (Grade A, 100% fresh)
func get_benchmark_price(crop_name: String) -> float:
	return get_benchmark_price_for_region(crop_name, Data.current_region)


func get_benchmark_price_for_region(crop_name: String, region_id: String) -> float:
	return calculate_unit_price_for_region(crop_name, "Grade A", 100.0, "market_index", region_id)


func get_price_history(crop_name: String) -> Array:
	return get_price_history_for_region(crop_name, Data.current_region)


func get_price_history_for_region(crop_name: String, region_id: String) -> Array:
	var m: Dictionary = _ensure_region_market(region_id)
	if not m["history"].has(crop_name):
		_init_crop_history_for_region(crop_name, region_id)
	return m["history"].get(crop_name, []).duplicate()


func get_price_change(crop_name: String) -> Dictionary:
	return get_price_change_for_region(crop_name, Data.current_region)


func get_price_change_for_region(crop_name: String, region_id: String) -> Dictionary:
	var hist: Array = get_price_history_for_region(crop_name, region_id)
	var current_p: float = hist[-1] if hist.size() > 0 else get_benchmark_price_for_region(crop_name, region_id)
	var prev_p: float = hist[-2] if hist.size() > 1 else current_p
	var diff: float = current_p - prev_p
	var pct: float = (diff / maxf(prev_p, 0.1)) * 100.0
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


## Refresh daily market conditions at midnight tick across all 5 provinces
func refresh_daily_prices() -> void:
	_sync_active_aliases()
	var commodities: Array = _all_commodity_keys()
	for r_id in Data.REGIONS.keys():
		var m: Dictionary = _ensure_region_market(r_id)
		var sup_map: Dictionary = m["supply"]
		var dem_map: Dictionary = m["demand"]
		var hist_map: Dictionary = m["history"]
		for crop_name in commodities:
			var cur_s: float = float(sup_map.get(crop_name, 500.0))
			var cur_d: float = float(dem_map.get(crop_name, 500.0))
			# Mean-reverting daily consumption & demand wave so markets cycle realistically
			sup_map[crop_name] = clampf(cur_s * randf_range(0.86, 0.96) + randf_range(15.0, 45.0), 160.0, 1800.0)
			dem_map[crop_name] = clampf(cur_d * randf_range(0.91, 1.09), 260.0, 820.0)

			var p: float = get_benchmark_price_for_region(crop_name, r_id)
			if not hist_map.has(crop_name):
				_init_crop_history_for_region(crop_name, r_id)
			else:
				hist_map[crop_name].append(_round_price(p))
				if hist_map[crop_name].size() > 7:
					hist_map[crop_name].pop_front()

			if r_id == Data.current_region:
				price_updated.emit(crop_name, p)
			market_region_updated.emit(r_id, crop_name, p)


## Dynamic Local Seed Buy Price (reflects regional specialty discounts + live demand)
func get_seed_buy_price(crop_name: String, region_id: String = "") -> int:
	var r_id: String = region_id if region_id != "" else Data.current_region
	var crop_data: Dictionary = Data.get_crop(crop_name)
	var base_seed: float = float(crop_data.get("seed_cost", 35))
	var mods: Dictionary = Data.get_region_modifiers(r_id)
	if Data.is_regional_specialty_crop(crop_name, r_id):
		base_seed *= (1.0 - float(mods.get("specialty_seed_discount", 0.15)))

	var m: Dictionary = _ensure_region_market(r_id)
	var s: float = float(m["supply"].get(crop_name, 500.0))
	var d: float = float(m["demand"].get(crop_name, 500.0))
	# Mild seed cost fluctuation (0.85x .. 1.20x) based on local market demand
	var market_pull: float = clampf(0.85 + 0.35 * clampf(d / maxf(s, 150.0) - 0.5, 0.0, 1.0), 0.85, 1.20)
	return maxi(5, int(round(base_seed * market_pull)))


## Record local seed demand spike when planting plots
func record_seed_purchase(crop_name: String, plots_count: int = 1, region_id: String = "") -> void:
	var r_id: String = region_id if region_id != "" else Data.current_region
	apply_market_trade(r_id, crop_name, 0.0, float(maxi(1, plots_count)) * 3.0, Data.is_multiplayer_match)


## Dynamic Wholesale Ask Price to BUY raw commodities from the player's local market
func get_commodity_buy_price(crop_name: String, region_id: String = "") -> float:
	var r_id: String = region_id if region_id != "" else Data.current_region
	var bench: float = get_benchmark_price_for_region(crop_name, r_id)
	# Ask spread (+22% + ₱1) prevents zero-effort buy/sell money loops while enabling milling/arbitrage
	return _round_price(maxf(bench * 1.22 + 1.0, 2.0))


## Buy raw commodities from local market into farm storage (fluctuates local supply/demand & syncs MP)
func buy_commodity(crop_name: String, quantity: int, region_id: String = "") -> Dictionary:
	if not Data.CROPS.has(crop_name) or quantity <= 0:
		return {"success": false, "error": "invalid_crop"}

	var r_id: String = region_id if region_id != "" else Data.current_region
	var free_space: int = BuildingManager.total_storage_capacity - get_total_stored_units()
	if free_space < quantity:
		return {"success": false, "error": "storage_full", "free_space": maxi(0, free_space)}

	var unit_ask: float = get_commodity_buy_price(crop_name, r_id)
	var total_cost: int = int(ceil(unit_ask * float(quantity)))
	if EconomyManager.cash < total_cost:
		return {"success": false, "error": "insufficient_cash", "cost": total_cost}

	EconomyManager.deduct_cash(total_cost, false)
	add_harvest_to_storage(crop_name, quantity, "Grade A", 100.0)

	# Buying removes local market supply and bids demand up
	apply_market_trade(r_id, crop_name, -float(quantity) * 0.9, float(quantity) * 0.65, Data.is_multiplayer_match)
	AudioManager.play_economy("spend")
	LogManager.log_event(
		"economy",
		"Bought %d %s @ ₱%.1f/u (Total ₱%s)" % [quantity, Data.get_crop(crop_name).get("display_name", crop_name), unit_ask, Utils.format_number(total_cost)],
		"🛒",
		Color(0.95, 0.80, 0.35, 1.0)
	)
	return {
		"success": true,
		"quantity": quantity,
		"unit_price": unit_ask,
		"total_cost": total_cost,
	}


## Apply a local market supply/demand shift and optionally broadcast to MP peers
func apply_market_trade(region_id: String, crop_name: String, delta_supply: float, delta_demand: float, broadcast: bool = false) -> void:
	var r_id: String = region_id if Data.REGIONS.has(region_id) else Data.current_region
	var m: Dictionary = _ensure_region_market(r_id)
	var mods: Dictionary = Data.get_region_modifiers(r_id)

	var adj_supply_delta: float = delta_supply
	if adj_supply_delta > 0.0:
		adj_supply_delta *= float(mods.get("supply_dump_mult", 1.0))

	m["supply"][crop_name] = clampf(float(m["supply"].get(crop_name, 500.0)) + adj_supply_delta, 80.0, 2500.0)
	m["demand"][crop_name] = clampf(float(m["demand"].get(crop_name, 500.0)) + delta_demand, 150.0, 1200.0)

	var new_p: float = get_benchmark_price_for_region(crop_name, r_id)
	if not m["history"].has(crop_name):
		_init_crop_history_for_region(crop_name, r_id)
	elif m["history"][crop_name].size() > 0:
		m["history"][crop_name][-1] = _round_price(new_p)

	if r_id == Data.current_region:
		_sync_active_aliases()
		price_updated.emit(crop_name, new_p)
	market_region_updated.emit(r_id, crop_name, new_p)

	if broadcast and Data.is_multiplayer_match:
		var mp = get_node_or_null("/root/MultiplayerManager")
		if mp and mp.has_method("notify_market_trade"):
			mp.notify_market_trade(r_id, crop_name, delta_supply, delta_demand)


## Add harvested crop batch to farm storage
func add_harvest_to_storage(crop: String, quantity: int, grade: String, freshness: float) -> void:
	var target_b: Node = BuildingManager.get_best_storage_for_crop(crop, quantity)
	var is_cold: bool = false
	var fac_id: int = 0
	var fac_type: String = ""

	if target_b and is_instance_valid(target_b):
		fac_id = target_b.get_instance_id()
		fac_type = target_b.building_type
		is_cold = (target_b.building_type in ["cold_storage", "climate_silo"]) or bool(Data.get_building(target_b.building_type).get("halts_spoilage", false))
		target_b.used_storage += quantity
	else:
		is_cold = BuildingManager.has_cold_storage()

	var batch: Dictionary = {
		"id": _next_batch_id,
		"crop": crop,
		"quantity": quantity,
		"grade": grade,
		"freshness": freshness,
		"is_cold_storage": is_cold,
		"is_processed": false,
		"facility_id": fac_id,
		"facility_type": fac_type,
	}
	_next_batch_id += 1
	stored_inventory.append(batch)
	_sync_storage_with_building_manager()
	inventory_changed.emit()


## Add processed value-added goods to farm storage (shelf-stable, zero rot)
func add_processed_to_storage(item: String, quantity: int, grade: String = "Grade A") -> void:
	var batch: Dictionary = {
		"id": _next_batch_id,
		"crop": item,
		"quantity": quantity,
		"grade": grade,
		"freshness": 100.0,
		"is_cold_storage": true,
		"is_processed": true,
	}
	_next_batch_id += 1
	stored_inventory.append(batch)
	_sync_storage_with_building_manager()
	inventory_changed.emit()


## Consume raw crop from storage for industrial milling (oldest/lowest freshness first)
func consume_crop_quantity(crop_name: String, needed_qty: int) -> bool:
	if get_stored_units_for_crop(crop_name) < needed_qty:
		return false

	var matching_indices: Array[int] = []
	for i in range(stored_inventory.size()):
		if stored_inventory[i].get("crop", "") == crop_name:
			matching_indices.append(i)

	matching_indices.sort_custom(func(a, b):
		return float(stored_inventory[a].get("freshness", 100.0)) < float(stored_inventory[b].get("freshness", 100.0))
	)

	var remaining_needed: int = needed_qty
	var indices_to_remove: Array[int] = []

	for idx in matching_indices:
		var b: Dictionary = stored_inventory[idx]
		var qty: int = int(b.get("quantity", 0))
		if qty <= remaining_needed:
			remaining_needed -= qty
			indices_to_remove.append(idx)
		else:
			b["quantity"] = qty - remaining_needed
			remaining_needed = 0
			break

	indices_to_remove.sort()
	indices_to_remove.reverse()
	for idx in indices_to_remove:
		stored_inventory.remove_at(idx)

	_sync_storage_with_building_manager()
	inventory_changed.emit()
	return true


## Called hourly from TimeManager to process spoilage/rot in storage
func process_hourly_spoilage() -> void:
	var updated: bool = false
	var has_cold: bool = BuildingManager.has_cold_storage()
	var mods: Dictionary = Data.get_region_modifiers(Data.current_region)
	var decay_rate: float = SPOILAGE_RATE_PER_HOUR * float(mods.get("spoilage_mult", 1.0))

	for batch in stored_inventory:
		if batch.get("is_processed", false) or Data.is_processed_good(batch.get("crop", "")):
			continue
		if not batch.get("is_cold_storage", false) and not has_cold:
			batch["freshness"] = maxf(batch["freshness"] - decay_rate, 0.0)
			updated = true
	if updated:
		inventory_changed.emit()
	discard_ruined_batches()


## Removes all fully-rotten (0% freshness) raw batches so they can't block storage/sales.
func discard_ruined_batches(crop_name: String = "") -> int:
	var removed_units: int = 0
	for i in range(stored_inventory.size() - 1, -1, -1):
		var b: Dictionary = stored_inventory[i]
		if b.get("is_processed", false) or Data.is_processed_good(str(b.get("crop", ""))):
			continue
		if crop_name != "" and str(b.get("crop", "")) != crop_name:
			continue
		if float(b.get("freshness", 100.0)) <= 0.0:
			removed_units += int(b.get("quantity", 0))
			stored_inventory.remove_at(i)
	if removed_units > 0:
		_sync_storage_with_building_manager()
		inventory_changed.emit()
		LogManager.log_event("economy", "Discarded %d units of fully rotten produce from storage." % removed_units, "🗑️", Color(0.75, 0.55, 0.40, 1.0))
	return removed_units


## Calculate unit price in the active region
func calculate_unit_price(crop: String, grade: String, freshness: float, hub_id: String) -> float:
	return calculate_unit_price_for_region(crop, grade, freshness, hub_id, Data.current_region)


## Calculate unit price considering quality, freshness, regional modifiers, destination hub & supply/demand
func calculate_unit_price_for_region(crop: String, grade: String, freshness: float, hub_id: String, region_id: String, use_buildings: bool = true) -> float:
	var r_id: String = region_id if Data.REGIONS.has(region_id) else Data.current_region
	var mods: Dictionary = Data.get_region_modifiers(r_id)
	var crop_data: Dictionary = Data.get_crop(crop)
	var base_price: float = float(crop_data.get("base_price", 20))
	var is_proc: bool = Data.is_processed_good(crop)

	var grade_mult: float = 0.4
	match grade:
		"Grade A": grade_mult = 1.0
		"Grade B": grade_mult = 0.7
		"Grade C": grade_mult = 0.4 * float(mods.get("grade_c_price_mult", 1.0))

	# Solar dryer bonus (region-scaled: e.g. Sarangani +35%, default +25%) on grains
	if use_buildings and BuildingManager.has_building("solar_dryer") and (crop == "palay" or crop == "yellow_corn"):
		var dryer_bonus: float = float(mods.get("solar_dryer_bonus", 0.25))
		grade_mult = minf(grade_mult * (1.0 + dryer_bonus), 1.0 + dryer_bonus)

	var freshness_factor: float = 1.0 if is_proc else clampf(freshness / 100.0, 0.05, 1.0)
	if not is_proc and freshness < 25.0:
		freshness_factor *= 0.35

	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var hub_multiplier: float = float(hub_data.get("price_multiplier", 1.0))
	if hub_id == "local_biyahero":
		var biyahero_bonus: float = BuildingManager.get_biyahero_price_bonus() if use_buildings else 0.0
		var night_base: float = 0.62 if TimeManager.is_night() else 0.72
		hub_multiplier = night_base + biyahero_bonus
	elif hub_id in ["koronadal", "gensan_port"]:
		hub_multiplier *= float(mods.get("export_hub_price_mult", 1.0))

	# Regional specialty crop value bonus (also gently lifts derived processed goods)
	var base_crop_key: String = str(crop_data.get("source_crop", crop)) if is_proc else crop
	var region_crop_mult: float = 1.0
	if Data.is_regional_specialty_crop(base_crop_key, r_id):
		var spec_mult: float = float(mods.get("specialty_price_mult", 1.0))
		region_crop_mult = (1.0 + (spec_mult - 1.0) * 0.65) if is_proc else spec_mult

	# Blend local province market with destination hub market when shipping externally
	var local_m: Dictionary = _ensure_region_market(r_id)
	var s_local: float = float(local_m["supply"].get(crop, 500.0))
	var d_local: float = float(local_m["demand"].get(crop, 500.0))
	var ratio_local: float = d_local / maxf(s_local, 100.0)

	var ratio: float = ratio_local
	if HUB_TO_REGION.has(hub_id):
		var dest_r: String = str(HUB_TO_REGION[hub_id])
		var dest_m: Dictionary = _ensure_region_market(dest_r)
		var s_dest: float = float(dest_m["supply"].get(crop, 500.0))
		var d_dest: float = float(dest_m["demand"].get(crop, 500.0))
		var ratio_dest: float = d_dest / maxf(s_dest, 100.0)
		ratio = ratio_dest * 0.70 + ratio_local * 0.30
	ratio = clampf(ratio, 0.55, 1.55)

	# Targeted climate & disaster price effects (instead of uniform +120% on any weather change)
	var disaster_factor: float = 1.0
	if WeatherManager.active_disaster != "":
		disaster_factor = DISASTER_PRICE_BOOST
	elif WeatherManager.current_climate == WeatherManager.Climate.EL_NINO:
		disaster_factor = 1.18 if base_crop_key in ["palay", "banana", "sugarcane"] else 1.08
	elif WeatherManager.current_climate == WeatherManager.Climate.LA_NINA:
		disaster_factor = 1.15 if base_crop_key in ["pineapple", "yellow_corn", "arabica_coffee"] else 1.05

	return base_price * grade_mult * freshness_factor * ratio * hub_multiplier * region_crop_mult * disaster_factor


func _get_hub_logistics(hub_id: String, region_id: String = "") -> Dictionary:
	var r_id: String = region_id if region_id != "" else Data.current_region
	var mods: Dictionary = Data.get_region_modifiers(r_id)
	var hub_data: Dictionary = Data.get_market_hub(hub_id)
	var base_fuel: float = float(hub_data.get("fuel_cost", 0))
	var hub_overrides: Dictionary = mods.get("hub_fuel_overrides", {})
	var fuel_mult: float = float(hub_overrides.get(hub_id, mods.get("fuel_cost_mult", 1.0)))
	var fuel_cost: int = int(round(base_fuel * fuel_mult))

	var has_cold: bool = BuildingManager.has_cold_storage()
	var road_rot: float = float(hub_data.get("rot_risk_percent", 0.0)) * float(mods.get("road_rot_mult", 1.0))
	var is_night: bool = TimeManager.is_night()
	var night_fee: int = 0

	if is_night and hub_id != "local_biyahero":
		road_rot *= 0.60
		night_fee = 25
		fuel_cost += night_fee

	return {
		"hub_data": hub_data,
		"fuel_cost": fuel_cost,
		"road_rot": road_rot,
		"has_cold": has_cold,
		"is_night": is_night,
		"night_fee": night_fee,
	}


func _record_sale_market_impact(crop_name: String, quantity: int, hub_id: String, region_id: String) -> void:
	var dump_multiplier: float = 1.8 if quantity >= 50 else 1.0
	var sup_delta: float = float(quantity) * dump_multiplier
	if HUB_TO_REGION.has(hub_id):
		var dest_r: String = str(HUB_TO_REGION[hub_id])
		apply_market_trade(dest_r, crop_name, sup_delta * 0.75, 0.0, Data.is_multiplayer_match)
		apply_market_trade(region_id, crop_name, sup_delta * 0.25, 0.0, Data.is_multiplayer_match)
	else:
		apply_market_trade(region_id, crop_name, sup_delta, 0.0, Data.is_multiplayer_match)


## Sell a specific stored batch with distance logistics, fuel expenses, and road ROT decay
func sell_stored_batch(batch_index: int, hub_id: String) -> bool:
	if batch_index < 0 or batch_index >= stored_inventory.size():
		return false
	if not Data.is_hub_available(hub_id):
		return false

	var batch: Dictionary = stored_inventory[batch_index]
	var log_info: Dictionary = _get_hub_logistics(hub_id, Data.current_region)
	var hub_data: Dictionary = log_info["hub_data"]
	var fuel_cost: int = int(log_info["fuel_cost"])
	var road_rot_percent: float = float(log_info["road_rot"])

	if EconomyManager.cash < fuel_cost:
		return false

	if log_info["has_cold"] or batch.get("is_cold_storage", false) or batch.get("is_processed", false) or Data.is_processed_good(batch.crop):
		road_rot_percent = 0.0

	var arrival_freshness: float = maxf(batch.freshness - road_rot_percent, 0.0)
	if arrival_freshness <= 0.0:
		if batch.freshness <= 0.0:
			stored_inventory.remove_at(batch_index)
			_sync_storage_with_building_manager()
			inventory_changed.emit()
		return false

	var unit_price: float = calculate_unit_price(batch.crop, batch.grade, arrival_freshness, hub_id)
	var gross_revenue: int = int(round(unit_price * float(batch.quantity)))
	var net_profit: int = gross_revenue - fuel_cost

	EconomyManager.deduct_cash(fuel_cost, false)
	if gross_revenue > 0:
		EconomyManager.add_cash(gross_revenue, false)

	_record_sale_market_impact(batch.crop, int(batch.quantity), hub_id, Data.current_region)

	var hub_name: String = hub_data.get("display_name", hub_id)
	sale_completed.emit(batch.crop, gross_revenue, net_profit, hub_name, road_rot_percent)
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

		var storage_buildings: Array = b_mgr.get_storage_buildings() if b_mgr.has_method("get_storage_buildings") else []
		for b in storage_buildings:
			if is_instance_valid(b) and "used_storage" in b:
				b.used_storage = 0

		var unassigned_batches: Array = []
		for batch in stored_inventory:
			var matched: bool = false
			var fac_id: int = int(batch.get("facility_id", 0))
			if fac_id != 0:
				for b in storage_buildings:
					if is_instance_valid(b) and b.get_instance_id() == fac_id:
						b.used_storage += int(batch.get("quantity", 0))
						matched = true
						break
			if not matched:
				unassigned_batches.append(batch)

		for batch in unassigned_batches:
			var crop_name: String = str(batch.get("crop", ""))
			var qty: int = int(batch.get("quantity", 0))
			for b in storage_buildings:
				if is_instance_valid(b) and b.accepts_crop(crop_name) and b.has_space(qty):
					b.used_storage += qty
					batch["facility_id"] = b.get_instance_id()
					batch["facility_type"] = b.building_type
					break

		for b in storage_buildings:
			if is_instance_valid(b) and b.has_method("update_storage_display"):
				b.update_storage_display()

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
	var log_info: Dictionary = _get_hub_logistics(hub_id, Data.current_region)
	var fuel_cost: int = int(log_info["fuel_cost"])
	var has_cold: bool = bool(log_info["has_cold"])
	var road_rot: float = float(log_info["road_rot"])
	var is_night: bool = bool(log_info["is_night"])
	var night_fee: int = int(log_info["night_fee"])

	if has_cold or Data.is_processed_good(crop_name):
		road_rot = 0.0

	var total_qty: int = 0
	var total_gross: int = 0
	var total_preview_pts: int = 0
	for b in stored_inventory:
		if b.get("crop", "") == crop_name:
			var batch_road_rot: float = road_rot
			if b.get("is_cold_storage", false) or b.get("is_processed", false) or Data.is_processed_good(str(b.get("crop", ""))):
				batch_road_rot = 0.0
			var arrival_fresh: float = maxf(b.freshness - batch_road_rot, 0.0)
			var unit_p: float = calculate_unit_price(b.crop, b.grade, arrival_fresh, hub_id)
			var gross: int = int(round(unit_p * float(b.quantity)))
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
	if not Data.is_hub_available(hub_id):
		return {"success": false, "error": "hub_locked"}

	var log_info: Dictionary = _get_hub_logistics(hub_id, Data.current_region)
	var hub_data: Dictionary = log_info["hub_data"]
	var fuel_cost: int = int(log_info["fuel_cost"])
	var has_cold: bool = bool(log_info["has_cold"])
	var road_rot: float = float(log_info["road_rot"])

	if has_cold or Data.is_processed_good(crop_name):
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
		var batch_road_rot: float = road_rot
		if b.get("is_cold_storage", false) or b.get("is_processed", false) or Data.is_processed_good(str(b.get("crop", ""))):
			batch_road_rot = 0.0
		var arrival_fresh: float = maxf(b.freshness - batch_road_rot, 0.0)
		var unit_p: float = calculate_unit_price(b.crop, b.grade, arrival_fresh, hub_id)
		var gross: int = int(round(unit_p * float(b.quantity)))
		if arrival_fresh <= 0.0:
			gross = 0
		total_gross += gross
		total_qty += int(b.quantity)

		if arrival_fresh > 0.0:
			var earned_pts: int = LeaderboardManager.record_sale(b.crop, int(b.quantity), b.grade, arrival_fresh, hub_id)
			total_points_earned += earned_pts

	if total_gross <= 0:
		discard_ruined_batches(crop_name)
		if hub_id != "local_biyahero":
			return {"success": false, "error": "ruined_in_transit"}
		fuel_cost = 0

	var net_profit: int = total_gross - fuel_cost

	EconomyManager.deduct_cash(fuel_cost, false)
	if total_gross > 0:
		EconomyManager.add_cash(total_gross, false)

	_record_sale_market_impact(crop_name, total_qty, hub_id, Data.current_region)

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
	apply_market_trade(Data.current_region, crop, float(quantity), 0.0, false)
