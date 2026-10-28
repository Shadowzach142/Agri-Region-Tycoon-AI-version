# GroundTileSprites.gd
# =============================================================================
# DATA RESOURCE & PROCEDURAL TERRAIN ENGINE
# Procedurally selects ground textures from 5 sprite variation sets:
#   1. NGRASS (NGRASS-01.png to NGRASS-05.png)             - Normal lush meadow grass
#   2. WGRASS (WGRASS-01.png to wGRASS-05.png)             - Saturated wet turf (>70% moisture)
#   3. BARE SOIL (BARE-SOIL-01.png to BARE-SOIL-05.png)     - Tilled agricultural loam soil
#   4. DROUGHT SOIL (DROUGHT-SOIL-O1 to 05.png)            - Arid parched cracked earth (<25% moisture)
#   5. WALK SOIL (WALK-SOIL-01.png to WALK-SOIL-05.png)    - Compacted gravel/earthen path & foundation
#
# Procedural generation features:
# - All normal/dry natural grass starts with cohesive NGRASS variants.
# - Wet grass: WGRASS variants are used exclusively when soil moisture > 70%
#   (rain, storms, watering, floods).
# - Drought soil: DROUGHT SOIL variants trigger during severe drought (< 25% moisture).
# - Foundation soil: WALK SOIL variants provide compacted earthen foundations under buildings.
# - High-entropy deterministic coordinate hashing distributes variants organically across 5 indices.
# =============================================================================

class_name GroundTileSprites
extends Resource

@export var normal_grass_variants: Array[Texture2D] = []
@export var wet_grass_variants:    Array[Texture2D] = []
@export var bare_soil_variants:    Array[Texture2D] = []
@export var drought_soil_variants: Array[Texture2D] = []
@export var walk_soil_variants:    Array[Texture2D] = []
@export var sand_variants:         Array[Texture2D] = []
@export var wet_sand_variants:     Array[Texture2D] = []
@export var flood_water_variants: Array[Texture2D] = []

# Backwards-compatibility aliases for existing systems
@export var light_grass_variants:  Array[Texture2D] = []
@export var dark_grass_variants:   Array[Texture2D] = []
@export var bare_variants:         Array[Texture2D] = []

@export var flooded:  Texture2D = null
@export var infected: Texture2D = null

var world_seed: int = 0

## Returns true if the grid coordinate lies on the eastern coastal beach side
static func is_beach_tile(pos: Vector2i) -> bool:
	# Only Sarangani Littoral Coast features an eastern sandy beach shoreline
	var cur_reg: String = Data.current_region if Engine.has_singleton("Data") or ("current_region" in Data) else "sarangani"
	if cur_reg != "sarangani":
		return false

	# Easternmost coastal shoreline touching the sea is x == 31
	if pos.x == 31:
		return true
	# Continuous golden sand beach strip along x == 30
	if pos.x == 30:
		return true
	# Organic undulating coastal dune line along x == 29
	if pos.x == 29:
		var wave: int = (pos.y * 7 + 3) % 11
		return wave < 6 # ~55% of dune edge tiles transition into sand
	return false

func _init() -> void:
	randomize()
	world_seed = randi()
	_ensure_variants_loaded()

func set_world_seed(new_seed: int) -> void:
	world_seed = new_seed

## Automatically loads all variant arrays from assets/sprites/ground/
func _ensure_variants_loaded() -> void:
	# 1. Normal Grass (NGRASS-01..05)
	if normal_grass_variants.is_empty():
		for i in range(1, 6):
			var path := "res://assets/sprites/ground/NGRASS/NGRASS-%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					normal_grass_variants.append(tex)

	# 2. Wet Grass (WGRASS-01..02 and wGRASS-03..05)
	if wet_grass_variants.is_empty():
		for i in range(1, 6):
			var candidates: Array[String] = []
			if i >= 3:
				candidates.append("res://assets/sprites/ground/WGRASS/wGRASS-%02d.png" % i)
				candidates.append("res://assets/sprites/ground/WGRASS/WGRASS-%02d.png" % i)
			else:
				candidates.append("res://assets/sprites/ground/WGRASS/WGRASS-%02d.png" % i)
				candidates.append("res://assets/sprites/ground/WGRASS/wGRASS-%02d.png" % i)
			for path in candidates:
				if ResourceLoader.exists(path):
					var tex := load(path) as Texture2D
					if tex:
						wet_grass_variants.append(tex)
						break

	# 3. Bare Soil (BARE-SOIL-01..05)
	if bare_soil_variants.is_empty():
		for i in range(1, 6):
			var path := "res://assets/sprites/ground/BARE SOIL/BARE-SOIL-%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					bare_soil_variants.append(tex)

	# 4. Drought Soil (DROUGHT-SOIL-O1 / 02..05)
	if drought_soil_variants.is_empty():
		for i in range(1, 6):
			var candidates: Array[String] = []
			if i == 1:
				candidates.append("res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-O1.png")
				candidates.append("res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-01.png")
			else:
				candidates.append("res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-%02d.png" % i)
				candidates.append("res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-O%d.png" % i)
			for path in candidates:
				if ResourceLoader.exists(path):
					var tex := load(path) as Texture2D
					if tex:
						drought_soil_variants.append(tex)
						break

	# 5. Walk Soil (WALK-SOIL-01..05)
	if walk_soil_variants.is_empty():
		for i in range(1, 6):
			var path := "res://assets/sprites/ground/BARE SOIL/WALK-SOIL-%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					walk_soil_variants.append(tex)

	# 6. Sand Variants (Sand-01..03)
	if sand_variants.is_empty():
		for i in range(1, 4):
			var path := "res://assets/sprites/ground/SAND/Sand-%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					sand_variants.append(tex)

	# 7. Wet Sand Variants (WSand-01..03)
	if wet_sand_variants.is_empty():
		for i in range(1, 4):
			var path := "res://assets/sprites/ground/SAND/WSand-%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					wet_sand_variants.append(tex)

	# 8. Flood Water Animated Variants (water_01..05)
	if flood_water_variants.is_empty():
		for i in range(1, 6):
			var path := "res://assets/sprites/water/water_%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					flood_water_variants.append(tex)

	# Sync backwards-compatibility arrays
	if light_grass_variants.is_empty():
		light_grass_variants = normal_grass_variants
	if dark_grass_variants.is_empty():
		dark_grass_variants = wet_grass_variants
	if bare_variants.is_empty():
		bare_variants = bare_soil_variants

## High-entropy deterministic coordinate hash for organic variant distribution
func get_variant_index(pos: Vector2i, salt: int, count: int) -> int:
	if count <= 1:
		return 0
	# 32-bit SplitMix-style spatial hash across (x, y, salt, world_seed)
	var n: int = (pos.x * 374761393 + pos.y * 668265263 + (world_seed ^ salt) * 362437) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) * 1274126177 & 0x7FFFFFFF
	n = (n ^ (n >> 16)) * 2654435761 & 0x7FFFFFFF
	n = (n ^ (n >> 15)) & 0x7FFFFFFF
	var roll: int = n % 100

	# Distribution across 5 variants:
	# 30% clean base (var 0), 20% var 1, 20% var 2, 15% var 3, 15% var 4
	if count >= 5:
		if roll < 30:
			return 0
		elif roll < 50:
			return 1
		elif roll < 70:
			return 2
		elif roll < 85:
			return 3
		else:
			return 4
	else:
		return roll % count

## Main API: Returns the procedural texture for a given tile and grid position
func get_texture(tile: FarmTile, pos: Vector2i = Vector2i.ZERO) -> Texture2D:
	_ensure_variants_loaded()
	var is_beach := is_beach_tile(pos)

	match tile.state:
		# Cultivated soil state: Plowed
		FarmTile.TileState.PLOWED:
			# Arid soil during severe drought (< 25% moisture)
			if tile.soil_moisture < 25.0 and not drought_soil_variants.is_empty():
				var idx := get_variant_index(pos, 105, drought_soil_variants.size())
				return drought_soil_variants[idx]
			if not bare_soil_variants.is_empty():
				var idx := get_variant_index(pos, 101, bare_soil_variants.size())
				return bare_soil_variants[idx]
			return null

		# Building foundations: Compacted walk soil during construction, lush grass or beach sand once done
		FarmTile.TileState.BUILDING:
			# If the building is actively under construction, show compacted construction earth
			if tile.building_ref and "state" in tile.building_ref and tile.building_ref.state == 0:
				if not walk_soil_variants.is_empty():
					var idx := get_variant_index(pos, 150, walk_soil_variants.size())
					return walk_soil_variants[idx]
				elif not bare_soil_variants.is_empty():
					var idx := get_variant_index(pos, 101, bare_soil_variants.size())
					return bare_soil_variants[idx]

			# When the building is done (ACTIVE), if on the coast, returns to clean coastal sand!
			if is_beach and not sand_variants.is_empty():
				var idx := get_variant_index(pos, 350, sand_variants.size())
				return sand_variants[idx]
			elif not normal_grass_variants.is_empty():
				var idx := get_variant_index(pos, 303, normal_grass_variants.size())
				return normal_grass_variants[idx]
			elif not walk_soil_variants.is_empty():
				var idx := get_variant_index(pos, 150, walk_soil_variants.size())
				return walk_soil_variants[idx]
			return null

		# Multi-tile crop child tiles or procedural fallback ground
		FarmTile.TileState.PLANTED, \
		FarmTile.TileState.GROWING, \
		FarmTile.TileState.HARVESTABLE:
			if tile.soil_moisture < 25.0 and not drought_soil_variants.is_empty():
				var idx := get_variant_index(pos, 105, drought_soil_variants.size())
				return drought_soil_variants[idx]
			if not bare_soil_variants.is_empty():
				var idx := get_variant_index(pos, 101, bare_soil_variants.size())
				return bare_soil_variants[idx]
			return null

		# Natural uncultivated plots (homestead / coast)
		FarmTile.TileState.EMPTY:
			if is_beach:
				if (pos.x == 31 or tile.soil_moisture > 80.0) and not wet_sand_variants.is_empty():
					var idx := get_variant_index(pos, 250, wet_sand_variants.size())
					return wet_sand_variants[idx]
				elif not sand_variants.is_empty():
					var idx := get_variant_index(pos, 260, sand_variants.size())
					return sand_variants[idx]

			# Arid soil patch during severe drought (< 25% moisture)
			if tile.soil_moisture < 25.0 and not drought_soil_variants.is_empty():
				var idx := get_variant_index(pos, 105, drought_soil_variants.size())
				return drought_soil_variants[idx]

			# WET GRASS: When moisture exceeds 70% (rain / watered), transition to Wet Grass
			if tile.soil_moisture > 70.0 and not wet_grass_variants.is_empty():
				var idx := get_variant_index(pos, 202, wet_grass_variants.size())
				return wet_grass_variants[idx]

			# DEFAULT: Clean, unified Normal Grass across all starting and normal plots
			if not normal_grass_variants.is_empty():
				var idx := get_variant_index(pos, 303, normal_grass_variants.size())
				return normal_grass_variants[idx]
			return null

		# Unbought wilderness parcels
		FarmTile.TileState.LOCKED:
			if is_beach:
				if (pos.x == 31 or tile.soil_moisture > 80.0) and not wet_sand_variants.is_empty():
					var idx := get_variant_index(pos, 450, wet_sand_variants.size())
					return wet_sand_variants[idx]
				elif not sand_variants.is_empty():
					var idx := get_variant_index(pos, 460, sand_variants.size())
					return sand_variants[idx]

			# Wet grass during rain
			if tile.soil_moisture > 70.0 and not wet_grass_variants.is_empty():
				var idx := get_variant_index(pos, 404, wet_grass_variants.size())
				return wet_grass_variants[idx]
			elif not normal_grass_variants.is_empty():
				var idx := get_variant_index(pos, 505, normal_grass_variants.size())
				return normal_grass_variants[idx]
			return null

		# Natural obstacles (trees, rocks) resting on natural grass / beach dunes
		FarmTile.TileState.OBSTACLE:
			if is_beach:
				if (pos.x == 31 or tile.soil_moisture > 80.0) and not wet_sand_variants.is_empty():
					var idx := get_variant_index(pos, 650, wet_sand_variants.size())
					return wet_sand_variants[idx]
				elif not sand_variants.is_empty():
					var idx := get_variant_index(pos, 660, sand_variants.size())
					return sand_variants[idx]

			if tile.soil_moisture > 70.0 and not wet_grass_variants.is_empty():
				var idx := get_variant_index(pos, 606, wet_grass_variants.size())
				return wet_grass_variants[idx]
			elif not normal_grass_variants.is_empty():
				var idx := get_variant_index(pos, 707, normal_grass_variants.size())
				return normal_grass_variants[idx]
			return null

		FarmTile.TileState.FLOODED:
			# Animated water sprites for flooded plots
			if not flood_water_variants.is_empty():
				var idx := get_variant_index(pos, 888, flood_water_variants.size())
				return flood_water_variants[idx]
			if flooded:
				return flooded
			# Flooded beach uses wet sand
			if is_beach and not wet_sand_variants.is_empty():
				var idx := get_variant_index(pos, 850, wet_sand_variants.size())
				return wet_sand_variants[idx]
			# Flooded plots fallback: use wet grass
			if not wet_grass_variants.is_empty():
				var idx := get_variant_index(pos, 808, wet_grass_variants.size())
				return wet_grass_variants[idx]
			return null

		FarmTile.TileState.INFECTED:
			return infected

	return null
