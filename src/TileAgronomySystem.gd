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
static func process_day(tile: FarmTile, _pos: Vector2i) -> void:
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
	else:
		tile.state = FarmTile.TileState.GROWING

	apply_climate_effects(tile, crop_data)

	# Pest damage (health decay + yield erosion)
	if tile.pest_type != "":
		tile.health        = maxf(tile.health - 0.15, 0.0)
		tile.yield_quantity = int(tile.yield_quantity * 0.85)
		if tile.health < 0.4:
			tile.quality = FarmTile.QualityGrade.C
		elif tile.health < 0.8:
			tile.quality = FarmTile.QualityGrade.B

# ---------------------------------------------------------------------------
# Hourly soil simulation (evaporation, drip irrigation, waterlogging)
# ---------------------------------------------------------------------------
static func process_hour(tile: FarmTile, has_drip: bool) -> void:
	if tile.state == FarmTile.TileState.OBSTACLE:
		return

	# Evaporation: 1.5/hr during El Niño vs 0.5/hr baseline
	var evap: float = 1.5 if WeatherManager.current_climate == WeatherManager.Climate.EL_NINO else 0.5
	tile.soil_moisture = maxf(tile.soil_moisture - evap, 0.0)

	# Smart drip irrigation: auto-top-up thirsty planted tiles
	if has_drip and (tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING):
		var c_info: Dictionary = Data.get_crop(tile.crop_type)
		var req_min: float = float(c_info.get("water_min", 40))
		if tile.soil_moisture < req_min:
			tile.soil_moisture = req_min + 5.0

	# Palay: 12-hour waterlogging causes destructive rot
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
static func apply_climate_effects(tile: FarmTile, crop_data: Dictionary) -> void:
	var wm = WeatherManager
	var water_min: float = float(crop_data.get("water_min", 40))
	var water_max: float = float(crop_data.get("water_max", 80))

	# Agronomy Rule: Arabica Coffee permanently killed by flooding
	if tile.crop_type == "arabica_coffee" and (tile.soil_moisture >= 90.0 or tile.state == FarmTile.TileState.FLOODED):
		tile.reset()
		return

	match wm.current_climate:
		WeatherManager.Climate.EL_NINO:
			tile.soil_moisture = maxf(tile.soil_moisture - 15.0, 0.0)
			# Yellow Corn is heat-resilient up to 45°C
			var heat_resilient: bool = (tile.crop_type == "yellow_corn" and wm.temperature <= 45.0)
			if tile.soil_moisture < water_min and not heat_resilient:
				tile.days_without_water += 1
				tile.health = maxf(tile.health - 0.20, 0.0)
				if tile.health < 0.4:
					tile.quality = FarmTile.QualityGrade.C
				elif tile.health < 0.7:
					tile.quality = FarmTile.QualityGrade.B

		WeatherManager.Climate.LA_NINA:
			tile.soil_moisture = minf(tile.soil_moisture + 22.0, 100.0)
			if tile.soil_moisture > water_max:
				tile.days_overwatered += 1
				if tile.soil_moisture >= 90.0:
					# Soil moisture > 90% causes crop rot
					tile.state          = FarmTile.TileState.FLOODED
					tile.growth_progress = 0.0
					tile.yield_quantity  = int(tile.yield_quantity * 0.3)
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
