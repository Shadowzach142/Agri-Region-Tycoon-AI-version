# TileRenderer.gd
# Handles all 2.5D visual presentation for isometric farm tiles.
# Extracted from FarmGrid to keep it focused on state & actions only.
#
# Standard 2:1 Isometric Projection:
#   Tile diamond: 128 px wide x 64 px high
#   Top: (0, -32), Right: (64, 0), Bottom: (0, 32), Left: (-64, 0)
#   3D depth slab: 8 px downwards on front edges
#
# Ground sprite system:
#   Assign a GroundTileSprites resource to `ground_sprites` to use custom
#   PNG textures on tile diamond faces. Any slot left null falls back to the
#   procedural colour system automatically — swap sprites one state at a time.

class_name TileRenderer
extends RefCounted

# ---------------------------------------------------------------------------
# Tile color palette
# ---------------------------------------------------------------------------
const COLOR_BORDER:      Color = Color(0.12, 0.12, 0.10, 1.0)
const COLOR_EMPTY:       Color = Color(0.35, 0.58, 0.28, 1.0)  # Grass green
const COLOR_LOCKED:      Color = Color(0.28, 0.38, 0.24, 0.95)  # Soft wilderness grass tone
const COLOR_PLOWED:      Color = Color(0.46, 0.30, 0.18, 1.0)  # Cultivated soil brown
const COLOR_PLANTED:     Color = Color(0.24, 0.45, 0.18, 1.0)  # Seedling green
const COLOR_GROWING:     Color = Color(0.30, 0.65, 0.22, 1.0)  # Maturing green
const COLOR_HARVESTABLE: Color = Color(0.88, 0.72, 0.15, 1.0)  # Ripe golden yellow
const COLOR_FLOODED:     Color = Color(0.18, 0.45, 0.72, 0.95) # Rot / flood water
const COLOR_INFECTED:    Color = Color(0.75, 0.20, 0.20, 1.0)  # Pest danger red

# ---------------------------------------------------------------------------
# Visual-node arrays (owned by FarmGrid, referenced here)
# ---------------------------------------------------------------------------
var tile_fills:    Array = []  # Polygon2D diamond fills
var tile_overlays: Array = []  # Node2D procedural detail layer
var tile_dots:     Array = []  # ColorRect / Polygon indicator dots
var tile_labels:   Array = []  # Label crop icon labels
var tile_sprites:  Array = []  # Sprite2D custom ground sprites

# ---------------------------------------------------------------------------
# Ground sprite resource (optional — assign in FarmGrid._ready())
# When a texture slot is non-null, it overrides the procedural fill colour.
# Drop PNGs into assets/sprites/ground/ and assign them here.
# ---------------------------------------------------------------------------
var ground_sprites: GroundTileSprites = null
var _crop_texture_cache: Dictionary = {}
var _crop_stage_cache: Dictionary = {}

const CROP_STAGE_CONFIG: Dictionary = {
	"palay":          {"folder": "Rice",      "prefix": "RICE-P",      "max_growth": 3, "max_stage": 5},
	"yellow_corn":    {"folder": "Corn",      "prefix": "CORN-P",      "max_growth": 3, "max_stage": 5},
	"sugarcane":      {"folder": "Sugarcane", "prefix": "SUGARCANE-P", "max_growth": 3, "max_stage": 5},
	"pineapple":      {"folder": "Pineapple", "prefix": "PINEAPPLE-P", "max_growth": 3, "max_stage": 5},
	"arabica_coffee": {"folder": "Coffee",    "prefix": "COFFEE-P",    "max_growth": 3, "max_stage": 5},
	"banana":         {"folder": "Banana",    "prefix": "BANANA-P",    "max_growth": 4, "max_stage": 6},
	"coconut":        {"folder": "Coconut",   "prefix": "COCONUT-P",   "max_growth": 3, "max_stage": 5}
}

# Perennial crops that have a "no crop" regrowth stage sprite
const REGROWTH_CROPS: Dictionary = {
	"arabica_coffee": {"folder": "Coffee",  "prefix": "COFFEE-P",  "nocrop_stage": 3},
	"banana":         {"folder": "Banana",  "prefix": "BANANA-P",  "nocrop_stage": 3},
	"coconut":        {"folder": "Coconut", "prefix": "COCONUT-P", "nocrop_stage": 3}
}

## Returns the "no crop" regrowth sprite for a perennial crop (e.g. BANANA-P3 no crop.png).
## Used when a perennial tile is in the post-harvest regrowing state.
func get_regrowth_texture(crop_type: String) -> Texture2D:
	var cache_key := "%s:nocrop" % crop_type
	if _crop_stage_cache.has(cache_key):
		return _crop_stage_cache[cache_key]

	if REGROWTH_CROPS.has(crop_type):
		var cfg: Dictionary = REGROWTH_CROPS[crop_type]
		var stage: int = int(cfg["nocrop_stage"])
		var path := "res://assets/sprites/Field/Crops/%s/%s%d no crop.png" % [cfg["folder"], cfg["prefix"], stage]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_crop_stage_cache[cache_key] = tex
				return tex

	_crop_stage_cache[cache_key] = null
	return null

## Returns the exact stage-based sprite texture for a crop.
## Stages 1-3 (or 1-4 for banana) are growth stages.
## Stages 4+ (or 5+ for banana) are withering stages.
func get_crop_stage_texture(crop_type: String, stage: int) -> Texture2D:
	if crop_type.is_empty() or stage < 1:
		return null
	var key := "%s:%d" % [crop_type, stage]
	if _crop_stage_cache.has(key):
		return _crop_stage_cache[key]

	var cfg: Dictionary = CROP_STAGE_CONFIG.get(crop_type, {})
	if not cfg.is_empty():
		var folder: String = cfg["folder"]
		var prefix: String = cfg["prefix"]
		var path := "res://assets/sprites/Field/Crops/%s/%s%d.png" % [folder, prefix, stage]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_crop_stage_cache[key] = tex
				return tex

	# Fallback to single crop sprite if stage sprite not found
	var fallback := get_crop_sprite_texture(crop_type)
	_crop_stage_cache[key] = fallback
	return fallback

## Searches for and caches custom crop sprite textures if provided by the user.
## Supports assets/sprites/Field/Crops/ mature sprites, assets/sprites/crops/<crop>.png, etc.
func get_crop_sprite_texture(crop_type: String) -> Texture2D:
	if crop_type.is_empty():
		return null
	if _crop_texture_cache.has(crop_type):
		return _crop_texture_cache[crop_type]

	# First check if stage sprite exists for mature stage (Stage 4 for Banana, Stage 3 for others)
	if CROP_STAGE_CONFIG.has(crop_type):
		var mature_stage: int = int(CROP_STAGE_CONFIG[crop_type]["max_growth"])
		var stage_tex := get_crop_stage_texture(crop_type, mature_stage)
		if stage_tex:
			_crop_texture_cache[crop_type] = stage_tex
			return stage_tex

	var candidates: Array[String] = [
		"res://assets/sprites/crops/%s.png" % crop_type,
		"res://assets/sprites/crops/%s.png" % crop_type.capitalize(),
		"res://assets/sprites/crops/crop_%s.png" % crop_type,
		"res://assets/sprites/%s.png" % crop_type,
		"res://assets/sprites/%s.png" % crop_type.capitalize(),
		"res://assets/icons/%s.png" % crop_type,
		"res://assets/icons/%s.png" % crop_type.capitalize(),
		"res://assets/icons/%s_sprite.png" % crop_type
	]

	for path in candidates:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_crop_texture_cache[crop_type] = tex
				return tex

	_crop_texture_cache[crop_type] = null
	return null

## Calculates the active sprite stage index for a tile.
## Follows user specification:
## - General crops: 1-3 growth stage, 4-5 withering stage
## - Banana: 1-4 growth stage, 5-6 withering stage
func get_tile_crop_stage(tile: FarmTile) -> int:
	if tile.crop_type.is_empty():
		return 1

	var is_banana: bool = (tile.crop_type == "banana")

	# 1. Terminal decay: Flooded (waterlogged / drowned) or dead
	if tile.state == FarmTile.TileState.FLOODED or tile.health <= 0.18:
		return 6 if is_banana else 5

	# 2. Withering / Pest / Health Stress / Overripe
	var is_withering: bool = false
	var is_severe: bool = false

	if tile.state == FarmTile.TileState.INFECTED or tile.pest_type != "":
		is_withering = true
		if tile.health < 0.45:
			is_severe = true
	elif tile.health < 0.40 or tile.days_without_water >= 3 or tile.days_overwatered >= 3:
		is_withering = true
		if tile.health < 0.25:
			is_severe = true
	elif tile.state == FarmTile.TileState.HARVESTABLE and tile.freshness < 60.0:
		is_withering = true
		if tile.freshness < 25.0:
			is_severe = true

	if is_withering:
		if is_banana:
			return 6 if is_severe else 5
		else:
			return 5 if is_severe else 4

	# 3. Normal growth progression
	if is_banana:
		if tile.state == FarmTile.TileState.HARVESTABLE or tile.growth_progress >= 1.0:
			return 4
		elif tile.state == FarmTile.TileState.PLANTED or tile.growth_progress < 0.25:
			return 1
		elif tile.growth_progress < 0.65:
			return 2
		else:
			return 3
	else:
		if tile.state == FarmTile.TileState.HARVESTABLE or tile.growth_progress >= 1.0:
			return 3
		elif tile.state == FarmTile.TileState.PLANTED or tile.growth_progress < 0.30:
			return 1
		else:
			return 2

## Returns the active stage texture for a given tile.
## For regrowing perennials, returns the "no crop" texture while the plant regrows.
func get_crop_texture_for_tile(tile: FarmTile) -> Texture2D:
	if tile.crop_type.is_empty():
		return null
	# Regrowing perennial: show bare-plant "no crop" sprite
	if tile.is_regrowing and REGROWTH_CROPS.has(tile.crop_type):
		var nocrop_tex := get_regrowth_texture(tile.crop_type)
		if nocrop_tex:
			return nocrop_tex
	# Normal stage texture
	var stage := get_tile_crop_stage(tile)
	return get_crop_stage_texture(tile.crop_type, stage)

func setup(fills: Array, overlays: Array, dots: Array, labels: Array, sprites: Array = []) -> void:
	tile_fills    = fills
	tile_overlays = overlays
	tile_dots     = dots
	tile_labels   = labels
	tile_sprites  = sprites
	# Load the ground sprite resource if it exists
	const SPRITE_RES := "res://assets/sprites/ground/ground_tile_sprites.tres"
	if ResourceLoader.exists(SPRITE_RES):
		ground_sprites = load(SPRITE_RES) as GroundTileSprites

# ---------------------------------------------------------------------------
# Batch update
# ---------------------------------------------------------------------------
func update_all(tiles: Array, grid_size: Vector2i) -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			update_tile(Vector2i(x, y), tiles)

# ---------------------------------------------------------------------------
# Single tile visual update
# ---------------------------------------------------------------------------
func update_tile(pos: Vector2i, tiles: Array) -> void:
	var tile: FarmTile = tiles[pos.x][pos.y]
	var fill: Polygon2D = tile_fills[pos.x][pos.y]
	var sprite: Sprite2D = null
	if tile_sprites.size() > pos.x and tile_sprites[pos.x].size() > pos.y:
		sprite = tile_sprites[pos.x][pos.y]
	var dot:  ColorRect = tile_dots[pos.x][pos.y]
	var lbl:  Label     = tile_labels[pos.x][pos.y]

	_apply_fill_color(pos, tile, fill, lbl, sprite)
	_render_texture_detail(pos, tile)
	_update_status_dot(tile, dot)

# ---------------------------------------------------------------------------
# Fill color + crop icon
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Helper: apply sprite texture OR fall back to procedural color
# ---------------------------------------------------------------------------
func _apply_sprite_or_color(fill: Polygon2D, fallback_color: Color, tile: FarmTile, sprite: Sprite2D = null, pos: Vector2i = Vector2i.ZERO) -> void:
	if ground_sprites:
		var tex: Texture2D = ground_sprites.get_texture(tile, pos)
		if tex:
			if sprite:
				sprite.texture = tex
				sprite.visible = true
				if "bare" in tex.resource_path.to_lower():
					sprite.offset = Vector2(0, -2)
				else:
					sprite.offset = Vector2.ZERO
				
				# Preserve unbought wilderness shading on locked sprites
				if tile.state == FarmTile.TileState.LOCKED:
					sprite.modulate = Color(0.58, 0.66, 0.54, 1.0)
				elif tile.state == FarmTile.TileState.FLOODED:
					sprite.modulate = Color(0.40, 0.65, 0.90, 0.95)
				elif tile.state == FarmTile.TileState.INFECTED:
					sprite.modulate = Color(0.85, 0.40, 0.35, 1.0)
				else:
					sprite.modulate = Color.WHITE

				fill.visible = false
			else:
				fill.texture = tex
				fill.color   = Color.WHITE
				fill.visible = true
			return
	# Fallback: clear texture, use procedural color
	if sprite:
		sprite.visible = false
	fill.texture = null
	fill.color   = fallback_color
	fill.visible = true

func _apply_crop_modulate(sprite: Sprite2D, tile: FarmTile) -> void:
	if tile.state == FarmTile.TileState.FLOODED:
		sprite.modulate = Color(0.55, 0.75, 0.95, 0.85)
	elif tile.state == FarmTile.TileState.INFECTED or tile.pest_type != "":
		sprite.modulate = Color(0.95, 0.55, 0.55, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _apply_fill_color(pos: Vector2i, tile: FarmTile, fill: Polygon2D, lbl: Label, sprite: Sprite2D = null) -> void:
	match tile.state:
		FarmTile.TileState.EMPTY:
			var col: Color
			if tile.soil_moisture < 35.0:
				col = Color(0.48, 0.58, 0.32)
			elif tile.soil_moisture > 75.0:
				col = Color(0.24, 0.44, 0.18)
			else:
				col = COLOR_EMPTY
			_apply_sprite_or_color(fill, col, tile, sprite, pos)
			lbl.text = ""

		FarmTile.TileState.PLOWED:
			var col: Color
			if tile.soil_moisture > 70.0:
				col = Color(0.32, 0.20, 0.11)
			elif tile.soil_moisture < 35.0:
				col = Color(0.56, 0.42, 0.28)
			else:
				col = COLOR_PLOWED
			_apply_sprite_or_color(fill, col, tile, sprite, pos)
			lbl.text = ""

		FarmTile.TileState.PLANTED:
			# Crop sprites are rendered by _draw_custom_crop_sprite in _render_texture_detail.
			if tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1):
				_apply_sprite_or_color(fill, COLOR_PLOWED, tile, sprite, pos)
				lbl.text = ""
			else:
				var has_crop_tex: bool = get_crop_texture_for_tile(tile) != null
				if not has_crop_tex:
					_apply_sprite_or_color(fill, COLOR_PLANTED, tile, sprite, pos)
					lbl.text = "🌱"
				else:
					if sprite:
						sprite.texture = null
						sprite.visible = false
					fill.visible = false
					lbl.text = ""

		FarmTile.TileState.GROWING:
			if tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1):
				_apply_sprite_or_color(fill, COLOR_PLOWED, tile, sprite, pos)
				lbl.text = ""
			else:
				var has_crop_tex: bool = get_crop_texture_for_tile(tile) != null
				if not has_crop_tex:
					var col := COLOR_GROWING.lerp(COLOR_HARVESTABLE, tile.growth_progress * 0.7)
					_apply_sprite_or_color(fill, col, tile, sprite, pos)
					lbl.text = "🌿"
				else:
					if sprite:
						sprite.texture = null
						sprite.visible = false
					fill.visible = false
					lbl.text = ""

		FarmTile.TileState.HARVESTABLE:
			if tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1):
				_apply_sprite_or_color(fill, COLOR_PLOWED, tile, sprite, pos)
				lbl.text = ""
			else:
				var has_crop_tex: bool = get_crop_texture_for_tile(tile) != null
				if not has_crop_tex:
					_apply_sprite_or_color(fill, COLOR_HARVESTABLE, tile, sprite, pos)
					var crop_icon := "🌾"
					if Engine.has_singleton("Data"):
						crop_icon = Engine.get_singleton("Data").get_crop(tile.crop_type).get("icon", "🌾")
					elif ResourceLoader.exists("res://autoload/Data.gd"):
						var d_script = load("res://autoload/Data.gd")
						if "CROPS" in d_script and d_script.CROPS.has(tile.crop_type):
							crop_icon = d_script.CROPS[tile.crop_type].get("icon", "🌾")
					lbl.text = crop_icon
				else:
					if sprite:
						sprite.texture = null
						sprite.visible = false
					fill.visible = false
					lbl.text = ""

		FarmTile.TileState.FLOODED:
			# Crop sprites handled by overlay; ground sprite only shows terrain tint
			if sprite:
				sprite.texture = null
				sprite.visible = false
			_apply_sprite_or_color(fill, COLOR_FLOODED, tile, null, pos)
			lbl.text = "🌊"

		FarmTile.TileState.INFECTED:
			if sprite:
				sprite.texture = null
				sprite.visible = false
			_apply_sprite_or_color(fill, COLOR_INFECTED, tile, null, pos)
			lbl.text = "🐛"

		FarmTile.TileState.OBSTACLE:
			_apply_sprite_or_color(fill, Color(0.22, 0.38, 0.18, 1.0), tile, sprite, pos)
			lbl.text = ""  # 3D model rendered in overlay

		FarmTile.TileState.BUILDING:
			var col: Color
			if tile.building_ref and tile.building_ref.building_type == "bodega":
				col = Color(0.30, 0.46, 0.25, 1.0)
			else:
				col = Color(0.20, 0.17, 0.14, 1.0)
			_apply_sprite_or_color(fill, col, tile, sprite, pos)
			lbl.text = ""

		FarmTile.TileState.LOCKED:
			_apply_sprite_or_color(fill, COLOR_LOCKED, tile, sprite, pos)
			lbl.text = ""

# ---------------------------------------------------------------------------
# Indicator dot (top-right diamond tip)
# ---------------------------------------------------------------------------
func _update_status_dot(tile: FarmTile, dot: ColorRect) -> void:
	if not dot:
		return

	if tile.pest_type != "" or tile.state == FarmTile.TileState.INFECTED:
		dot.color = Color(0.95, 0.15, 0.15, 1.0)  # Red: Pest
	elif tile.state == FarmTile.TileState.HARVESTABLE:
		dot.color = Color(1.0, 0.88, 0.15, 1.0)   # Gold: Ready
	elif tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
		var water_min: float = 40.0
		if Engine.has_singleton("Data"):
			water_min = float(Engine.get_singleton("Data").get_crop(tile.crop_type).get("water_min", 40.0))
		elif ResourceLoader.exists("res://autoload/Data.gd"):
			var d_script = load("res://autoload/Data.gd")
			if "CROPS" in d_script and d_script.CROPS.has(tile.crop_type):
				water_min = float(d_script.CROPS[tile.crop_type].get("water_min", 40.0))
		if tile.soil_moisture < water_min:
			dot.color = Color(0.25, 0.65, 1.0, 1.0)  # Blue: Thirsty
		else:
			dot.color = Color.TRANSPARENT
	else:
		dot.color = Color.TRANSPARENT

# ---------------------------------------------------------------------------
# Procedural 2.5D texture detail overlay in isometric perspective
# ---------------------------------------------------------------------------
func _render_texture_detail(pos: Vector2i, tile: FarmTile) -> void:
	var overlay: Node2D = tile_overlays[pos.x][pos.y]
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

	if tile.state == FarmTile.TileState.EMPTY and tile.obstacle_type == "":
		overlay.modulate.a = 1.0

	# Child plots of a multi-tile crop (e.g. 2×2 Coconut Palm) skip individual plant rendering
	# (The root plot renders the grand combined 2×2 tree spanning the grove)
	if tile.multi_tile_root_pos != Vector2i(-1, -1) and not tile.is_multi_tile_root:
		return

	var has_sprite: bool = false
	if ground_sprites and ground_sprites.get_texture(tile, pos) != null:
		has_sprite = true

	match tile.state:
		FarmTile.TileState.EMPTY:
			if not has_sprite:
				# Isometric grass tufts and pebbles (procedural fallback only)
				var offsets: Array[Vector2] = [
					Vector2(-24, -6), Vector2(18, -10), Vector2(-12, 12),
					Vector2(26, 8), Vector2(0, -2)
				]
				for i in range(offsets.size()):
					var pt := offsets[i]
					var blade_col := Color(0.44, 0.72, 0.32, 0.75) if (i % 2 == 0) else Color(0.22, 0.42, 0.16, 0.75)
					var line := Line2D.new()
					line.width = 1.5
					line.default_color = blade_col
					line.add_point(pt)
					line.add_point(pt + Vector2(-2, -5))
					overlay.add_child(line)

			# Arid cracked earth fissures when parched (< 25% moisture)
			if tile.soil_moisture < 25.0:
				var crack1 := Line2D.new()
				crack1.width = 1.2
				crack1.default_color = Color(0.38, 0.28, 0.16, 0.85)
				crack1.add_point(Vector2(-18, -4))
				crack1.add_point(Vector2(-6, 2))
				crack1.add_point(Vector2(6, -2))
				crack1.add_point(Vector2(16, 6))
				overlay.add_child(crack1)

				var crack2 := Line2D.new()
				crack2.width = 1.0
				crack2.default_color = Color(0.38, 0.28, 0.16, 0.85)
				crack2.add_point(Vector2(-6, 2))
				crack2.add_point(Vector2(-2, 10))
				overlay.add_child(crack2)

		FarmTile.TileState.PLOWED:
			if not has_sprite:
				# Diagonal furrow ridges aligned with isometric axes (slope 0.5, procedural fallback only)
				var furrow_offsets := [-14.0, -4.0, 6.0, 16.0]
				for f_offset in furrow_offsets:
					# Dark furrow trench
					var trench := Line2D.new()
					trench.width = 2.0
					trench.default_color = Color(0.20, 0.11, 0.05, 0.8)
					trench.add_point(Vector2(-36.0, f_offset * 0.5 - 18.0))
					trench.add_point(Vector2(36.0,  f_offset * 0.5 + 18.0))
					overlay.add_child(trench)

					# Light furrow ridge
					var ridge := Line2D.new()
					ridge.width = 1.5
					ridge.default_color = Color(0.55, 0.38, 0.22, 0.8)
					ridge.add_point(Vector2(-36.0, f_offset * 0.5 - 16.0))
					ridge.add_point(Vector2(36.0,  f_offset * 0.5 + 20.0))
					overlay.add_child(ridge)
			_draw_drip_irrigation_lines(overlay, tile)

		FarmTile.TileState.FLOODED:
			if tile.crop_type != "":
				if tile.is_multi_tile_root:
					_draw_2x2_multi_tile_crop(overlay, tile)
				else:
					var crop_tex := get_crop_texture_for_tile(tile)
					if crop_tex != null:
						_draw_custom_crop_sprite(overlay, crop_tex, tile)
					elif not has_sprite:
						# Translucent water ripple waves (procedural fallback only)
						var ripple1 := Line2D.new()
						ripple1.width = 1.5
						ripple1.default_color = Color(0.60, 0.85, 1.0, 0.65)
						ripple1.add_point(Vector2(-24, -4))
						ripple1.add_point(Vector2(20, 4))
						overlay.add_child(ripple1)
						var ripple2 := Line2D.new()
						ripple2.width = 1.5
						ripple2.default_color = Color(0.60, 0.85, 1.0, 0.65)
						ripple2.add_point(Vector2(-16, 8))
						ripple2.add_point(Vector2(24, 14))
						overlay.add_child(ripple2)
			else:
				var ripple1 := Line2D.new()
				ripple1.width = 1.5
				ripple1.default_color = Color(0.60, 0.85, 1.0, 0.65)
				ripple1.add_point(Vector2(-24, -4))
				ripple1.add_point(Vector2(20, 4))
				overlay.add_child(ripple1)
				var ripple2 := Line2D.new()
				ripple2.width = 1.5
				ripple2.default_color = Color(0.60, 0.85, 1.0, 0.65)
				ripple2.add_point(Vector2(-16, 8))
				ripple2.add_point(Vector2(24, 14))
				overlay.add_child(ripple2)

		FarmTile.TileState.INFECTED:
			_draw_drip_irrigation_lines(overlay, tile)
			if tile.crop_type != "":
				if tile.is_multi_tile_root:
					_draw_2x2_multi_tile_crop(overlay, tile)
				else:
					var crop_tex := get_crop_texture_for_tile(tile)
					if crop_tex != null:
						_draw_custom_crop_sprite(overlay, crop_tex, tile)

		FarmTile.TileState.PLANTED:
			_draw_drip_irrigation_lines(overlay, tile)
			if tile.is_multi_tile_root:
				_draw_2x2_multi_tile_crop(overlay, tile)
			else:
				var crop_tex := get_crop_texture_for_tile(tile)
				if crop_tex != null:
					# 1x1 with custom sprite — draw in overlay (correct isometric anchor)
					_draw_custom_crop_sprite(overlay, crop_tex, tile)
				elif not has_sprite:
					# Seedling soil mound (procedural fallback only)
					var mound := Polygon2D.new()
					mound.polygon = PackedVector2Array([
						Vector2(-12, 0), Vector2(0, -6), Vector2(12, 0), Vector2(0, 6)
					])
					mound.color = Color(0.30, 0.18, 0.08, 0.9)
					overlay.add_child(mound)

		FarmTile.TileState.GROWING:
			_draw_drip_irrigation_lines(overlay, tile)
			if tile.is_multi_tile_root:
				_draw_2x2_multi_tile_crop(overlay, tile)
			else:
				var crop_tex := get_crop_texture_for_tile(tile)
				if crop_tex != null:
					_draw_custom_crop_sprite(overlay, crop_tex, tile)
				else:
					if tile.crop_type == "sugarcane":
						_draw_sugarcane_stalks(overlay, tile)
					else:
						# Standing 2.5D green crop stalks (procedural fallback only)
						var stalk_h: float = clampf(tile.growth_progress * 24.0, 8.0, 24.0)
						var base_p := Vector2(0, 4)
						var top_p  := Vector2(0, 4 - stalk_h)

						var stalk := Line2D.new()
						stalk.width = 3.0
						stalk.default_color = Color(0.28, 0.75, 0.22, 0.95)
						stalk.add_point(base_p)
						stalk.add_point(top_p)
						overlay.add_child(stalk)

		FarmTile.TileState.HARVESTABLE:
			_draw_drip_irrigation_lines(overlay, tile)
			if tile.is_multi_tile_root:
				_draw_2x2_multi_tile_crop(overlay, tile)
			else:
				var crop_tex := get_crop_texture_for_tile(tile)
				if crop_tex != null:
					_draw_custom_crop_sprite(overlay, crop_tex, tile)
				else:
					if tile.crop_type == "sugarcane":
						_draw_sugarcane_stalks(overlay, tile)
					else:
						# Lush golden rice sheafs standing upright (procedural fallback only)
						for i in range(-2, 3):
							var stalk := Line2D.new()
							stalk.width = 2.5
							stalk.default_color = Color(1.0, 0.88, 0.20, 0.95)
							var bx: float = float(i) * 5.0
							stalk.add_point(Vector2(bx, 6))
							stalk.add_point(Vector2(bx * 1.4, -18))
							overlay.add_child(stalk)

		FarmTile.TileState.OBSTACLE:
			if tile.obstacle_type == "rock":
				_draw_rock_obstacle(overlay)
			else:
				_draw_tree_obstacle(overlay)

		FarmTile.TileState.LOCKED:
			if tile.obstacle_type == "rock":
				_draw_rock_obstacle(overlay)
			elif tile.obstacle_type == "tree":
				_draw_tree_obstacle(overlay)
			elif not has_sprite:
				# Wild dense uncultivated wilderness weeds (procedural fallback only)
				var pts: Array[Vector2] = [Vector2(-16, -6), Vector2(14, 8), Vector2(0, -2)]
				for p: Vector2 in pts:
					var weed := Line2D.new()
					weed.width = 1.5
					weed.default_color = Color(0.11, 0.16, 0.09, 0.85)
					weed.add_point(p)
					weed.add_point(p + Vector2(-2, -6))
					overlay.add_child(weed)

func _draw_drip_irrigation_lines(overlay: Node2D, tile: FarmTile) -> void:
	var bm = null
	if Engine.has_singleton("BuildingManager"):
		bm = Engine.get_singleton("BuildingManager")
	elif Engine.get_main_loop() and Engine.get_main_loop().root.has_node("BuildingManager"):
		bm = Engine.get_main_loop().root.get_node("BuildingManager")

	if bm == null or not bm.has_method("has_irrigation") or not bm.has_irrigation():
		return

	var irr_lvl: int = bm.get_irrigation_level() if bm.has_method("get_irrigation_level") else 1
	var hose_col := Color(0.14, 0.16, 0.18, 0.85)
	var emitter_col := Color(0.35, 0.45, 0.55, 0.90)
	var drop_col := Color(0.35, 0.80, 1.0, 0.80)

	# Parallel micro-drip hoses aligned with isometric 2:1 slope
	var offsets := [-6.0, 8.0]
	for off_y in offsets:
		var p1 := Vector2(-32.0, off_y * 0.5 - 16.0)
		var p2 := Vector2(32.0, off_y * 0.5 + 16.0)

		var hose := Line2D.new()
		hose.width = 1.3
		hose.default_color = hose_col
		hose.add_point(p1)
		hose.add_point(p2)
		overlay.add_child(hose)

		# Emitter nozzles along the drip line
		for t in [0.28, 0.50, 0.72]:
			var ep: Vector2 = p1.lerp(p2, t)
			var emitter := Polygon2D.new()
			emitter.polygon = PackedVector2Array([
				ep + Vector2(-1.5, -1.0), ep + Vector2(1.5, -1.0),
				ep + Vector2(1.5, 1.0), ep + Vector2(-1.5, 1.0)
			])
			emitter.color = emitter_col
			overlay.add_child(emitter)

			if irr_lvl >= 3:
				var drop := Polygon2D.new()
				drop.polygon = PackedVector2Array([
					ep + Vector2(0, 1.0), ep + Vector2(1.2, 2.5),
					ep + Vector2(0, 3.5), ep + Vector2(-1.2, 2.5)
				])
				drop.color = drop_col
				overlay.add_child(drop)

func _draw_custom_crop_sprite(overlay: Node2D, crop_tex: Texture2D, tile: FarmTile) -> void:
	if not crop_tex:
		return

	var spr := Sprite2D.new()
	spr.name = "CropSprite"
	spr.texture = crop_tex
	spr.centered = true
	spr.scale = Vector2(4.0, 4.0)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# In isometric 2:1 projection the tile diamond center is at (0,0) local.
	# The bottom-front tip of the diamond is at y=+32 (local). We want the
	# sprite base to sit exactly on that ground line, so:
	#   position = bottom-front tip = Vector2(0, 32)
	#   offset   = shift the sprite up by half its scaled height so its bottom
	#              edge lands at y=0 relative to spr.position
	# scaled_h = tex_h * 4.0, so offset.y = -(tex_h * 4.0) / 2.0 / 4.0 = -tex_h / 2.0
	# But sprite is centered=true, so Godot already shifts by -scaled_h/2 internally.
	# We just need to move the sprite up so the bottom pixel is at y=+32:
	#   center of sprite in local space = spr.position.y = 32 - scaled_h/2
	# => position.y = 32 - (tex_h * 4.0) / 2.0, offset = Vector2.ZERO
	var tex_h: float = float(crop_tex.get_height())
	spr.position = Vector2(0.0, 32.0 - tex_h * 4.0 / 2.0)
	spr.offset = Vector2.ZERO

	# State shading
	match tile.state:
		FarmTile.TileState.FLOODED:
			spr.modulate = Color(0.55, 0.75, 0.95, 0.85)
		FarmTile.TileState.INFECTED:
			spr.modulate = Color(0.95, 0.55, 0.55, 1.0)
		_:
			if tile.pest_type != "":
				spr.modulate = Color(0.95, 0.70, 0.70, 1.0)
			else:
				spr.modulate = Color.WHITE

	overlay.add_child(spr)

func _draw_tree_obstacle(overlay: Node2D) -> void:
	# 1. Dark oval ground shadow
	var shadow := Polygon2D.new()
	var s_pts: PackedVector2Array = []
	for a in range(16):
		var rad: float = float(a) * TAU / 16.0
		s_pts.append(Vector2(cos(rad) * 28.0, 8.0 + sin(rad) * 12.0))
	shadow.polygon = s_pts
	shadow.color = Color(0.08, 0.14, 0.06, 0.55)
	overlay.add_child(shadow)

	# 2. Sturdy 2.5D Tree Trunk
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-8, 8), Vector2(8, 8), Vector2(6, -20), Vector2(-6, -20)
	])
	trunk.color = Color(0.40, 0.24, 0.12, 1.0)
	overlay.add_child(trunk)

	var bark_shade := Line2D.new()
	bark_shade.width = 2.0
	bark_shade.default_color = Color(0.28, 0.15, 0.06, 0.9)
	bark_shade.add_point(Vector2(-3, 8))
	bark_shade.add_point(Vector2(-2, -20))
	overlay.add_child(bark_shade)

	# 3. Layered 2.5D Isometric Canopy
	# Bottom layer (dark green)
	var c_bot := Polygon2D.new()
	c_bot.polygon = PackedVector2Array([
		Vector2(0, -50), Vector2(36, -28), Vector2(0, -6), Vector2(-36, -28)
	])
	c_bot.color = Color(0.16, 0.42, 0.14, 0.95)
	overlay.add_child(c_bot)

	# Middle layer (medium green)
	var c_mid := Polygon2D.new()
	c_mid.polygon = PackedVector2Array([
		Vector2(0, -64), Vector2(30, -42), Vector2(0, -20), Vector2(-30, -42)
	])
	c_mid.color = Color(0.24, 0.55, 0.18, 0.95)
	overlay.add_child(c_mid)

	# Top canopy crown (bright vibrant green)
	var c_top := Polygon2D.new()
	c_top.polygon = PackedVector2Array([
		Vector2(0, -78), Vector2(22, -56), Vector2(0, -34), Vector2(-22, -56)
	])
	c_top.color = Color(0.32, 0.68, 0.24, 0.95)
	overlay.add_child(c_top)

	# Sunlit leaf highlights
	var h1 := Polygon2D.new()
	h1.polygon = PackedVector2Array([
		Vector2(-10, -56), Vector2(0, -62), Vector2(0, -48), Vector2(-10, -48)
	])
	h1.color = Color(0.48, 0.82, 0.32, 0.9)
	overlay.add_child(h1)

func _draw_rock_obstacle(overlay: Node2D) -> void:
	# 2.5D Isometric River Boulder / Granite Rock
	# 1. Dark ground shadow
	var shadow := Polygon2D.new()
	var s_pts: PackedVector2Array = []
	for a in range(16):
		var rad: float = float(a) * TAU / 16.0
		s_pts.append(Vector2(cos(rad) * 22.0, 6.0 + sin(rad) * 9.0))
	shadow.polygon = s_pts
	shadow.color = Color(0.06, 0.10, 0.06, 0.45)
	overlay.add_child(shadow)

	# 2. Main Granite Boulder Facets (Isometric 3D shading)
	# Shaded bottom/south-west facet
	var f_dark := Polygon2D.new()
	f_dark.polygon = PackedVector2Array([
		Vector2(-18, 4), Vector2(0, 10), Vector2(-2, -6), Vector2(-16, -3)
	])
	f_dark.color = Color(0.35, 0.37, 0.42, 1.0)
	overlay.add_child(f_dark)

	# Mid-tone right facet
	var f_mid := Polygon2D.new()
	f_mid.polygon = PackedVector2Array([
		Vector2(0, 10), Vector2(16, 4), Vector2(14, -6), Vector2(-2, -6)
	])
	f_mid.color = Color(0.50, 0.53, 0.58, 1.0)
	overlay.add_child(f_mid)

	# Sunlit top crown facet (sunlight from top)
	var f_top := Polygon2D.new()
	f_top.polygon = PackedVector2Array([
		Vector2(-16, -3), Vector2(-2, -6), Vector2(14, -6), Vector2(0, -16)
	])
	f_top.color = Color(0.68, 0.72, 0.77, 1.0)
	overlay.add_child(f_top)

	# Angular fissure line / rock crease
	var crack := Line2D.new()
	crack.width = 1.5
	crack.default_color = Color(0.24, 0.26, 0.30, 0.95)
	crack.add_point(Vector2(-2, -6))
	crack.add_point(Vector2(0, 10))
	overlay.add_child(crack)

	var ridge := Line2D.new()
	ridge.width = 1.2
	ridge.default_color = Color(0.82, 0.86, 0.90, 0.85)
	ridge.add_point(Vector2(-2, -6))
	ridge.add_point(Vector2(0, -16))
	overlay.add_child(ridge)

	# Moss / lichen patch on shaded lower crevice
	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([
		Vector2(-14, 2), Vector2(-6, 7), Vector2(-9, 0)
	])
	moss.color = Color(0.36, 0.50, 0.26, 0.90)
	overlay.add_child(moss)

	# 3. Small companion pebble
	var peb := Polygon2D.new()
	peb.polygon = PackedVector2Array([
		Vector2(11, 7), Vector2(17, 8), Vector2(15, 3), Vector2(10, 4)
	])
	peb.color = Color(0.46, 0.49, 0.54, 1.0)
	overlay.add_child(peb)

	var peb_top := Line2D.new()
	peb_top.width = 1.0
	peb_top.default_color = Color(0.70, 0.73, 0.78, 0.8)
	peb_top.add_point(Vector2(10, 4))
	peb_top.add_point(Vector2(15, 3))
	overlay.add_child(peb_top)

# ---------------------------------------------------------------------------
# Sugarcane Stalk Cluster Rendering
# ---------------------------------------------------------------------------
func _draw_sugarcane_stalks(overlay: Node2D, tile: FarmTile) -> void:
	var prog: float = tile.growth_progress if tile.state != FarmTile.TileState.HARVESTABLE else 1.0
	var max_h: float = lerp(12.0, 32.0, prog)
	var is_ripe: bool = (tile.state == FarmTile.TileState.HARVESTABLE)

	# Cane offsets and slight tilts
	var stalks: Array = [
		{"x": -8.0, "slant": -2.0, "h_mult": 0.88},
		{"x": -2.0, "slant": 0.5, "h_mult": 1.0},
		{"x": 4.0, "slant": 1.5, "h_mult": 0.95},
		{"x": 9.0, "slant": 2.5, "h_mult": 0.82}
	]

	var cane_col := Color(0.62, 0.78, 0.26) if is_ripe else Color(0.44, 0.68, 0.22)
	var node_col := Color(0.48, 0.30, 0.22, 0.85) if is_ripe else Color(0.30, 0.44, 0.16, 0.8)

	for s in stalks:
		var bx: float = s.x
		var by: float = 2.0 + s.x * 0.25
		var top_x: float = bx + s.slant
		var top_y: float = by - max_h * s.h_mult

		# Main thick fibrous stalk
		var cane := Line2D.new()
		cane.width = 2.8
		cane.default_color = cane_col
		cane.add_point(Vector2(bx, by))
		cane.add_point(Vector2(top_x, top_y))
		overlay.add_child(cane)

		# Horizontal ring nodes along the stalk
		var num_nodes: int = int(max_h * s.h_mult / 7.0)
		for n in range(1, num_nodes + 1):
			var t: float = float(n) * 7.0 / (max_h * s.h_mult)
			var node_p := Vector2(lerp(bx, top_x, t), lerp(by, top_y, t))
			var node_line := Line2D.new()
			node_line.width = 1.2
			node_line.default_color = node_col
			node_line.add_point(node_p + Vector2(-1.5, -0.5))
			node_line.add_point(node_p + Vector2(1.5, 0.5))
			overlay.add_child(node_line)

		# Arching blade leaves at the cane tip
		if prog > 0.35:
			var leaf_left := Line2D.new()
			leaf_left.width = 1.5
			leaf_left.default_color = Color(0.38, 0.76, 0.24, 0.9)
			leaf_left.add_point(Vector2(top_x, top_y))
			leaf_left.add_point(Vector2(top_x - 6.0, top_y - 4.0))
			leaf_left.add_point(Vector2(top_x - 10.0, top_y + 1.0))
			overlay.add_child(leaf_left)

			var leaf_right := Line2D.new()
			leaf_right.width = 1.5
			leaf_right.default_color = Color(0.45, 0.82, 0.28, 0.9)
			leaf_right.add_point(Vector2(top_x, top_y))
			leaf_right.add_point(Vector2(top_x + 5.0, top_y - 5.0))
			leaf_right.add_point(Vector2(top_x + 9.0, top_y - 1.0))
			overlay.add_child(leaf_right)

# ---------------------------------------------------------------------------
# 2x2 Multi-Tile Tree / Palm Rendering (Centered on 2x2 Grove Intersection)
# ---------------------------------------------------------------------------
func _draw_2x2_coconut_palm(overlay: Node2D, tile: FarmTile) -> void:
	_draw_2x2_multi_tile_crop(overlay, tile)

func _draw_2x2_multi_tile_crop(overlay: Node2D, tile: FarmTile) -> void:
	# 2x2 footprint center relative to root isometric diamond (0, 0)
	# Center intersection where the 4 tiles meet is exactly Vector2(0, 32)
	var center_pos := Vector2(0, 32)

	# 2. Check for custom crop stage texture first
	var crop_tex := get_crop_texture_for_tile(tile)
	if crop_tex != null:
		var spr := Sprite2D.new()
		spr.name = "CropSprite2x2"
		spr.texture = crop_tex
		spr.centered = true
		spr.scale = Vector2(4.0, 4.0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_h: float = float(crop_tex.get_height())

		# Compute horizontal trunk alignment to keep tree centered on the grove
		var trunk_x_offset: float = 0.0
		var c_name := tile.crop_type
		var stage := get_tile_crop_stage(tile)
		if c_name == "banana":
			match stage:
				1: trunk_x_offset = 0.5
				2: trunk_x_offset = 3.0
				3: trunk_x_offset = 4.5
				4: trunk_x_offset = 2.5
				5: trunk_x_offset = 6.0
				6: trunk_x_offset = 1.5
		elif c_name == "coconut":
			match stage:
				1: trunk_x_offset = -0.5
				2: trunk_x_offset = 1.0
				3: trunk_x_offset = -3.0
				4: trunk_x_offset = 0.0
				5: trunk_x_offset = 0.5

		spr.position = center_pos
		spr.offset = Vector2(trunk_x_offset, - tex_h / 2.0)

		match tile.state:
			FarmTile.TileState.FLOODED:
				spr.modulate = Color(0.55, 0.75, 0.95, 0.85)
			FarmTile.TileState.INFECTED:
				spr.modulate = Color(0.95, 0.55, 0.55, 1.0)
			_:
				if tile.pest_type != "":
					spr.modulate = Color(0.95, 0.70, 0.70, 1.0)
				else:
					spr.modulate = Color.WHITE

		overlay.add_child(spr)
		return

	# 3. Procedural 2.5D Majestic Coconut Palm Fallback
	match tile.state:
		FarmTile.TileState.PLANTED:
			# Coconut seed nut mound and green sprout
			var nut := Polygon2D.new()
			nut.polygon = PackedVector2Array([
				center_pos + Vector2(-6, 2), center_pos + Vector2(0, -3),
				center_pos + Vector2(6, 2), center_pos + Vector2(0, 7)
			])
			nut.color = Color(0.42, 0.28, 0.16)
			overlay.add_child(nut)

			var shoot := Line2D.new()
			shoot.width = 2.0
			shoot.default_color = Color(0.35, 0.78, 0.22)
			shoot.add_point(center_pos + Vector2(0, 0))
			shoot.add_point(center_pos + Vector2(2, -10))
			overlay.add_child(shoot)

		FarmTile.TileState.GROWING:
			var prog: float = tile.growth_progress
			var trunk_h: float = lerp(16.0, 46.0, prog)
			var crown_x: float = center_pos.x - 5.0 * prog
			var crown_y: float = center_pos.y - trunk_h

			# Growing curving trunk
			var trunk := Line2D.new()
			trunk.width = lerp(3.5, 6.5, prog)
			trunk.default_color = Color(0.48, 0.36, 0.22)
			trunk.add_point(center_pos + Vector2(0, 2))
			trunk.add_point(Vector2(center_pos.x - 2.0, center_pos.y - trunk_h * 0.5))
			trunk.add_point(Vector2(crown_x, crown_y))
			overlay.add_child(trunk)

			# Growing palm fronds (radial splay)
			var frond_count: int = 5
			var frond_len: float = lerp(14.0, 32.0, prog)
			for i in range(frond_count):
				var angle: float = -PI * 0.15 - float(i) * (PI * 0.70 / float(frond_count - 1))
				var frond := Line2D.new()
				frond.width = 2.0
				frond.default_color = Color(0.24, 0.58, 0.18) if i % 2 == 0 else Color(0.32, 0.70, 0.24)
				frond.add_point(Vector2(crown_x, crown_y))
				var mid_p := Vector2(crown_x + cos(angle) * frond_len * 0.6, crown_y + sin(angle) * frond_len * 0.5)
				var tip_p := Vector2(crown_x + cos(angle) * frond_len, crown_y + sin(angle) * frond_len * 0.7 + 6.0)
				frond.add_point(mid_p)
				frond.add_point(tip_p)
				overlay.add_child(frond)

		FarmTile.TileState.HARVESTABLE:
			# Fully mature grand 2x2 palm tree
			var crown_x: float = center_pos.x - 7.0
			var crown_y: float = center_pos.y - 52.0

			# Mature trunk polygon with realistic taper and curve
			var trunk_poly := Polygon2D.new()
			trunk_poly.polygon = PackedVector2Array([
				center_pos + Vector2(-5, 4),
				center_pos + Vector2(5, 4),
				Vector2(center_pos.x + 3.0, center_pos.y - 24.0),
				Vector2(crown_x + 3.0, crown_y),
				Vector2(crown_x - 3.0, crown_y),
				Vector2(center_pos.x - 4.0, center_pos.y - 24.0)
			])
			trunk_poly.color = Color(0.46, 0.35, 0.22)
			overlay.add_child(trunk_poly)

			# Trunk texture rings
			for ring_y in [-8.0, -18.0, -28.0, -38.0]:
				var ring := Line2D.new()
				ring.width = 1.5
				ring.default_color = Color(0.32, 0.22, 0.14, 0.85)
				var rx: float = lerp(center_pos.x, crown_x, absf(ring_y) / 52.0)
				ring.add_point(Vector2(rx - 3.5, center_pos.y + ring_y))
				ring.add_point(Vector2(rx + 3.5, center_pos.y + ring_y))
				overlay.add_child(ring)

			# Hanging coconut cluster drupes (3 coconuts)
			var nut_positions: Array[Vector2] = [
				Vector2(crown_x - 3, crown_y + 5),
				Vector2(crown_x + 2, crown_y + 6),
				Vector2(crown_x - 1, crown_y + 9)
			]
			for np in nut_positions:
				var c_nut := Polygon2D.new()
				c_nut.polygon = PackedVector2Array([
					np + Vector2(-3, 0), np + Vector2(0, -3),
					np + Vector2(3, 0), np + Vector2(0, 3)
				])
				c_nut.color = Color(0.48, 0.40, 0.22)
				overlay.add_child(c_nut)

			# Sweeping radial fronds (7 wide majestic arching fronds)
			var frond_count: int = 7
			var frond_len: float = 38.0
			for i in range(frond_count):
				var angle: float = -PI * 0.10 - float(i) * (PI * 0.80 / float(frond_count - 1))
				var frond := Line2D.new()
				frond.width = 2.4
				frond.default_color = Color(0.22, 0.54, 0.16) if i % 2 == 0 else Color(0.34, 0.72, 0.25)
				frond.add_point(Vector2(crown_x, crown_y))
				var mid_p := Vector2(crown_x + cos(angle) * frond_len * 0.6, crown_y + sin(angle) * frond_len * 0.5)
				var tip_p := Vector2(crown_x + cos(angle) * frond_len, crown_y + sin(angle) * frond_len * 0.75 + 10.0)
				frond.add_point(mid_p)
				frond.add_point(tip_p)
				overlay.add_child(frond)

