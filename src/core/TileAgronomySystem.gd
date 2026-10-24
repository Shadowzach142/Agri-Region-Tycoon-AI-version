# TileAgronomySystem.gd
# Simulates daily crop growth, hourly evaporation, climate effects, and quality grading.
# Extracted from FarmGrid to give it a single clear responsibility.
#
# All methods are static: no instance needed.
#   TileAgronomySystem.process_day(tile, pos)
#   TileAgronomySystem.process_hour(tile, has_drip)

class_name TileAgronomySystem
extends RefCounted

# ---------------------------------------------------------------------------
# Daily crop simulation (called once per in-game day per growing tile)
# ---------------------------------------------------------------------------
static func process_day(tile: FarmTile, pos: Vector2i) -> void:
	if tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null:
		return

	# Uncultivated plowed soil gradually regrows wild grass back to EMPTY after 3 days
	if tile.state == FarmTile.TileState.PLOWED and tile.crop_type == "":
		tile.days_without_water += 1
		if tile.days_without_water >= 3:
			tile.state = FarmTile.TileState.EMPTY
			tile.soil_moisture = 60.0
			tile.days_without_water = 0
		return

	var crop_data: Dictionary = Data.get_crop(tile.crop_type)
	if crop_data.is_empty():
		return

	# Agronomy Rule: Palay halts growth if soil moisture < 30%
	var is_halted: bool = (tile.crop_type == "palay" and tile.soil_moisture < 30.0)

	if not is_halted:
		var growth_days: float = float(crop_data.get("growth_days", 30))
		var growth_delta: float = (1.0 / growth_days) * tile.soil_fertility
		tile.growth_progress = clampf(tile.growth_progress + growth_delta, 0.0, 1.0)

	if tile.growth_progress >= 1.0:
		tile.state   = FarmTile.TileState.HARVESTABLE
		tile.quality = determine_quality(tile)
		tile.is_regrowing = false  # Fruit has fully regrown — show crop sprite again
	else:
		tile.state = FarmTile.TileState.GROWING

	apply_climate_effects(tile, crop_data, pos)

	# Pest damage (health decay + yield erosion)
	if tile.pest_type != "":
		tile.health        = maxf(tile.health - 0.15, 0.0)
		tile.yield_quantity = int(tile.yield_quantity * 0.85)
		if tile.health < 0.4:
			tile.quality = FarmTile.QualityGrade.C
		elif tile.health < 0.8:
			tile.quality = FarmTile.QualityGrade.B

# ---------------------------------------------------------------------------
# Hourly soil simulation (evaporation, drip irrigation, waterlogging, rainfall)
# ---------------------------------------------------------------------------
static func process_hour(tile: FarmTile, has_drip: bool, pos: Vector2i = Vector2i(-1, -1)) -> void:
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null:
		return
	if tile.state == FarmTile.TileState.LOCKED:
		return


	var wm = WeatherManager

	var is_night: bool = TimeManager.is_night()

	# ── Evaporation & Rainfall rate by climate ──────────────────────────────
	# Night cycle reduces daytime solar evaporation by 80-85%.
	# High night humidity creates dew condensation on open soils.
	# Irrigation infrastructure provides up to 35% mulch & pipe evaporation reduction.
	var evap_reduction: float = BuildingManager.get_irrigation_evap_reduction()
	match wm.current_climate:
		wm.Climate.EL_NINO:
			var evap: float = (0.35 if is_night else 1.5) * (1.0 - evap_reduction)
			tile.soil_moisture = maxf(tile.soil_moisture - evap, 0.0)
		wm.Climate.LA_NINA:
			# Evaporate a little, but rain adds more
			var evap: float = (0.05 if is_night else 0.2) * (1.0 - evap_reduction)
			var rainfall_gain: float = randf_range(1.5, 3.0)
			tile.soil_moisture = minf(tile.soil_moisture - evap + rainfall_gain, 100.0)
		wm.Climate.NORMAL:
			var evap: float = (0.08 if is_night else 0.5) * (1.0 - evap_reduction)
			tile.soil_moisture = maxf(tile.soil_moisture - evap, 0.0)

	# ── Nocturnal Dew Condensation ──────────────────────────────────────────
	# In tropical Philippine nights, cooling air causes dew moisture to settle on unflooded soil
	if is_night and wm.get_effective_humidity() >= 0.55 and tile.state != FarmTile.TileState.FLOODED:
		if tile.soil_moisture < 85.0:
			var dew_gain: float = randf_range(0.20, 0.45)
			tile.soil_moisture = minf(tile.soil_moisture + dew_gain, 85.0)

	# ── Nocturnal Plant Rest & Recuperation ─────────────────────────────────
	# Healthy crops rest in darkness without scorching sun heat, restoring damaged health
	if is_night and (tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING):
		if tile.pest_type == "" and tile.hours_waterlogged == 0:
			var c_data: Dictionary = Data.get_crop(tile.crop_type)
			var w_min: float = float(c_data.get("water_min", 40))
			var w_max: float = float(c_data.get("water_max", 80))
			if tile.soil_moisture >= w_min and tile.soil_moisture <= w_max:
				tile.health = minf(tile.health + 0.015, 1.0)

	# ── Smart automated irrigation: Rotary Sprinklers & Pressurized Drip Lines ──
	var covered_by_sprinkler: bool = (pos != Vector2i(-1, -1) and BuildingManager.is_tile_covered_by_sprinkler(pos))
	var has_full_drip: bool = has_drip or (BuildingManager.has_irrigation() and BuildingManager.get_irrigation_level() >= 3)

	if covered_by_sprinkler or has_full_drip:
		if tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
			var c_info: Dictionary = Data.get_crop(tile.crop_type)
			if not c_info.is_empty():
				var req_min: float = float(c_info.get("water_min", 40))
				var req_max: float = float(c_info.get("water_max", 80))
				var target_moisture: float = BuildingManager.get_irrigation_target_moisture(req_min, req_max)
				if tile.soil_moisture < req_min:
					tile.soil_moisture = target_moisture
				tile.days_without_water = 0
		elif tile.state == FarmTile.TileState.PLOWED:
			# Keep plowed soil prepared and fertile
			if tile.soil_moisture < 50.0:
				tile.soil_moisture = 60.0

	# ── Palay: 12-hour waterlogging causes destructive rot ─────────────────
	if tile.crop_type == "palay" and tile.soil_moisture > 95.0:
		tile.hours_waterlogged += 1
		if tile.hours_waterlogged >= 12:
			tile.state          = FarmTile.TileState.FLOODED
			tile.growth_progress = 0.0
			tile.yield_quantity  = int(tile.yield_quantity * 0.3)
			tile.quality         = FarmTile.QualityGrade.C
			tile.health          = 0.2
	else:
		tile.hours_waterlogged = 0

# ---------------------------------------------------------------------------
# Climate effects (called inside process_day)
# ---------------------------------------------------------------------------
static func apply_climate_effects(tile: FarmTile, crop_data: Dictionary, pos: Vector2i = Vector2i(-1, -1)) -> void:
	var wm = WeatherManager
	var water_min: float = float(crop_data.get("water_min", 40))
	var water_max: float = float(crop_data.get("water_max", 80))

	# Agronomy Rule: Arabica Coffee & Pineapple sensitive to severe waterlogging (Phytophthora root rot)
	if (tile.crop_type == "arabica_coffee" or tile.crop_type == "pineapple") and tile.days_overwatered >= 2:
		tile.health = maxf(tile.health - 0.35, 0.0)
		if tile.health <= 0.0 or tile.state == FarmTile.TileState.FLOODED:
			tile.reset()
			return

	match wm.current_climate:
		WeatherManager.Climate.EL_NINO:
			var covered_by_sprinkler: bool = (pos != Vector2i(-1, -1) and BuildingManager.is_tile_covered_by_sprinkler(pos))
			if not covered_by_sprinkler:
				tile.soil_moisture = maxf(tile.soil_moisture - 15.0, 0.0)
			else:
				tile.days_without_water = 0
				tile.health = minf(tile.health + 0.05, 1.0)

			# Yellow Corn is heat-resilient up to 45°C; Pineapple is CAM drought-resilient up to 40°C
			var heat_resilient: bool = (tile.crop_type == "yellow_corn" and wm.temperature <= 45.0) or (tile.crop_type == "pineapple" and wm.temperature <= 40.0)
			if tile.soil_moisture < water_min and not heat_resilient and not covered_by_sprinkler:
				tile.days_without_water += 1
				tile.health = maxf(tile.health - 0.15, 0.0)
				if tile.health < 0.4:
					tile.quality = FarmTile.QualityGrade.C
				elif tile.health < 0.7:
					tile.quality = FarmTile.QualityGrade.B

		WeatherManager.Climate.LA_NINA:
			tile.soil_moisture = minf(tile.soil_moisture + 15.0, 100.0)
			if tile.soil_moisture > water_max:
				tile.days_overwatered += 1
				# Waterlogging stress reduces health gradually over days, not instantly
				tile.health = maxf(tile.health - 0.15, 0.2)
				if tile.health < 0.5:
					tile.quality = FarmTile.QualityGrade.C
				elif tile.health < 0.8:
					tile.quality = FarmTile.QualityGrade.B

				# Only prolonged waterlogging (3+ days of >=92% water) causes rot
				if tile.days_overwatered >= 3 and tile.soil_moisture >= 92.0:
					tile.state           = FarmTile.TileState.FLOODED
					tile.growth_progress = 0.0
					tile.yield_quantity  = int(tile.yield_quantity * 0.4)
					tile.quality         = FarmTile.QualityGrade.C
					tile.health          = 0.2

		WeatherManager.Climate.NORMAL:
			tile.days_without_water = 0
			tile.days_overwatered   = 0
			tile.soil_moisture = clampf(tile.soil_moisture + randf_range(-2.0, 4.0), 30.0, 75.0)

# ---------------------------------------------------------------------------
# Quality grading helpers
# ---------------------------------------------------------------------------
static func determine_quality(tile: FarmTile) -> int:
	if tile.health >= 0.85:
		return FarmTile.QualityGrade.A
	elif tile.health >= 0.55:
		return FarmTile.QualityGrade.B
	return FarmTile.QualityGrade.C

static func grade_to_string(grade: int) -> String:
	match grade:
		FarmTile.QualityGrade.A: return "Grade A"
		FarmTile.QualityGrade.B: return "Grade B"
		_:                        return "Grade C"

## Calculates yield quantity, quality grade, and metadata for harvesting a tile.
## Supports both fully ripe harvest and early emergency harvest (mitigating flood/drought risk).
static func calculate_harvest(tile: FarmTile) -> Dictionary:
	var is_early: bool = tile.growth_progress < 1.0
	var final_yield: int = 0
	var quality: int = FarmTile.QualityGrade.C

	if is_early:
		# Premature salvage harvest:
		# Yield scales directly with growth progression. Minimum 10% salvage yield.
		var progress_factor: float = clampf(tile.growth_progress, 0.10, 1.0)
		final_yield = int(round(tile.yield_quantity * progress_factor))
		final_yield = max(1, final_yield)

		# Quality grade for early harvest:
		# Unripe crops cannot achieve Grade A (Organic / Export grade).
		# Late-stage healthy premature crops (>= 80% growth, >= 80% health, no pest) achieve Grade B.
		# Earlier or diseased premature crops yield Grade C.
		if tile.growth_progress >= 0.80 and tile.health >= 0.80 and tile.pest_type == "":
			quality = FarmTile.QualityGrade.B
		else:
			quality = FarmTile.QualityGrade.C
	else:
		final_yield = tile.yield_quantity
		quality = determine_quality(tile)

	return {
		"yield": final_yield,
		"quality": quality,
		"grade_string": grade_to_string(quality),
		"is_early": is_early
	}
