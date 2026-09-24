# TileRenderer.gd
# Handles all visual presentation for farm tiles.
# Extracted from FarmGrid to keep it focused on state & actions only.
#
# Usage:
#   var renderer := TileRenderer.new()
#   renderer.setup(tile_fills, tile_overlays, tile_dots, tile_labels)
#   renderer.update_tile(pos, tiles)   # called by FarmGrid

class_name TileRenderer
extends RefCounted

# ---------------------------------------------------------------------------
# Tile color palette
# ---------------------------------------------------------------------------
const COLOR_BORDER:      Color = Color(0.12, 0.12, 0.10, 1.0)
const COLOR_EMPTY:       Color = Color(0.35, 0.58, 0.28, 1.0)  # Grass green
const COLOR_PLOWED:      Color = Color(0.46, 0.30, 0.18, 1.0)  # Cultivated soil brown
const COLOR_PLANTED:     Color = Color(0.24, 0.45, 0.18, 1.0)  # Seedling green
const COLOR_GROWING:     Color = Color(0.30, 0.65, 0.22, 1.0)  # Maturing green
const COLOR_HARVESTABLE: Color = Color(0.88, 0.72, 0.15, 1.0)  # Ripe golden yellow
const COLOR_FLOODED:     Color = Color(0.15, 0.40, 0.70, 1.0)  # Rot / flood water
const COLOR_INFECTED:    Color = Color(0.75, 0.20, 0.20, 1.0)  # Pest danger red

# ---------------------------------------------------------------------------
# Visual-node arrays (owned by FarmGrid, referenced here)
# ---------------------------------------------------------------------------
var tile_fills:    Array = []
var tile_overlays: Array = []
var tile_dots:     Array = []
var tile_labels:   Array = []

func setup(fills: Array, overlays: Array, dots: Array, labels: Array) -> void:
	tile_fills    = fills
	tile_overlays = overlays
	tile_dots     = dots
	tile_labels   = labels

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
	var fill: ColorRect = tile_fills[pos.x][pos.y]
	var dot:  ColorRect = tile_dots[pos.x][pos.y]
	var lbl:  Label     = tile_labels[pos.x][pos.y]

	_apply_fill_color(tile, fill, lbl)
	_render_texture_detail(pos, tile)
	_update_status_dot(tile, dot)

# ---------------------------------------------------------------------------
# Fill color + crop icon
# ---------------------------------------------------------------------------
func _apply_fill_color(tile: FarmTile, fill: ColorRect, lbl: Label) -> void:
	match tile.state:
		FarmTile.TileState.EMPTY:
			if tile.soil_moisture < 35.0:
				fill.color = Color(0.48, 0.58, 0.32)
			elif tile.soil_moisture > 75.0:
				fill.color = Color(0.24, 0.44, 0.18)
			else:
				fill.color = COLOR_EMPTY
			lbl.text = ""

		FarmTile.TileState.PLOWED:
			if tile.soil_moisture > 70.0:
				fill.color = Color(0.32, 0.20, 0.11)
			elif tile.soil_moisture < 35.0:
				fill.color = Color(0.56, 0.42, 0.28)
			else:
				fill.color = COLOR_PLOWED
			lbl.text = ""

		FarmTile.TileState.PLANTED:
			fill.color = COLOR_PLANTED
			lbl.text = Data.get_crop(tile.crop_type).get("icon", "🌱")

		FarmTile.TileState.GROWING:
			fill.color = COLOR_GROWING.lerp(COLOR_HARVESTABLE, tile.growth_progress * 0.7)
			lbl.text = Data.get_crop(tile.crop_type).get("icon", "🌿")

		FarmTile.TileState.HARVESTABLE:
			fill.color = COLOR_HARVESTABLE
			lbl.text = Data.get_crop(tile.crop_type).get("icon", "🌾")

		FarmTile.TileState.FLOODED:
			fill.color = COLOR_FLOODED
			lbl.text = "🌊"

		FarmTile.TileState.INFECTED:
			fill.color = COLOR_INFECTED
			lbl.text = "🐛"

		FarmTile.TileState.OBSTACLE:
			fill.color = Color(0.18, 0.34, 0.16, 1.0)
			lbl.text = "🌳"

		FarmTile.TileState.BUILDING:
			fill.color = Color(0.22, 0.18, 0.14, 1.0)
			lbl.text = ""

# ---------------------------------------------------------------------------
# Indicator dot (top-right corner)
# ---------------------------------------------------------------------------
func _update_status_dot(tile: FarmTile, dot: ColorRect) -> void:
	if tile.pest_type != "" or tile.state == FarmTile.TileState.INFECTED:
		dot.color = Color(0.95, 0.15, 0.15, 1.0)  # Red: Pest
	elif tile.state == FarmTile.TileState.HARVESTABLE:
		dot.color = Color(1.0, 0.88, 0.15, 1.0)   # Gold: Ready
	elif tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
		var c_data: Dictionary = Data.get_crop(tile.crop_type)
		if tile.soil_moisture < float(c_data.get("water_min", 40)):
			dot.color = Color(0.25, 0.65, 1.0, 1.0)  # Blue: Thirsty
		else:
			dot.color = Color.TRANSPARENT
	else:
		dot.color = Color.TRANSPARENT

# ---------------------------------------------------------------------------
# Procedural texture detail overlay
# ---------------------------------------------------------------------------
func _render_texture_detail(pos: Vector2i, tile: FarmTile) -> void:
	var overlay: Node2D = tile_overlays[pos.x][pos.y]
	for child in overlay.get_children():
		child.queue_free()

	match tile.state:
		FarmTile.TileState.EMPTY:
			var speck_offsets: Array = [
				Vector2(12, 14), Vector2(42, 18), Vector2(20, 42),
				Vector2(46, 44), Vector2(28, 24)
			]
			for i in range(speck_offsets.size()):
				var col: Color = Color(0.44, 0.72, 0.32, 0.7) if (i % 2 == 0) else Color(0.20, 0.38, 0.14, 0.7)
				overlay.add_child(_make_rect(Vector2(4, 4), speck_offsets[i], col))

		FarmTile.TileState.PLOWED:
			for i in range(4):
				var y_pos: int = 6 + i * 14
				overlay.add_child(_make_rect(Vector2(56, 3), Vector2(4, y_pos),     Color(0.22, 0.12, 0.05, 0.75)))
				overlay.add_child(_make_rect(Vector2(56, 3), Vector2(4, y_pos + 3), Color(0.55, 0.36, 0.20, 0.75)))

		FarmTile.TileState.FLOODED:
			overlay.add_child(_make_rect(Vector2(46, 3),  Vector2(8,  16), Color(0.40, 0.70, 0.95, 0.6)))
			overlay.add_child(_make_rect(Vector2(40, 3),  Vector2(12, 42), Color(0.40, 0.70, 0.95, 0.6)))
			overlay.add_child(_make_rect(Vector2(20, 14), Vector2(22, 24), Color(0.14, 0.09, 0.04, 0.9)))

		FarmTile.TileState.PLANTED:
			overlay.add_child(_make_rect(Vector2(34, 10), Vector2(15, 38), Color(0.30, 0.18, 0.08, 0.85)))

		FarmTile.TileState.GROWING:
			var f_width: float = clampf(tile.growth_progress * 46.0, 10.0, 46.0)
			overlay.add_child(_make_rect(Vector2(f_width, 4), Vector2(32.0 - f_width / 2.0, 50.0), Color(0.25, 0.80, 0.30, 0.85)))

		FarmTile.TileState.HARVESTABLE:
			overlay.add_child(_make_rect(Vector2(52, 4), Vector2(6, 50), Color(1.0, 0.90, 0.20, 0.95)))

		FarmTile.TileState.OBSTACLE:
			# Deep ground shadow
			overlay.add_child(_make_rect(Vector2(38, 12), Vector2(13, 44), Color(0.06, 0.12, 0.05, 0.55)))
			# Sturdy tree trunk
			overlay.add_child(_make_rect(Vector2(12, 20), Vector2(26, 30), Color(0.38, 0.22, 0.10, 1.0)))
			overlay.add_child(_make_rect(Vector2(3, 18),  Vector2(28, 31), Color(0.26, 0.14, 0.06, 0.9)))
			# Layered COC-style tree foliage canopy
			overlay.add_child(_make_rect(Vector2(44, 26), Vector2(10, 14), Color(0.16, 0.40, 0.14, 0.95)))
			overlay.add_child(_make_rect(Vector2(36, 22), Vector2(14, 10), Color(0.22, 0.50, 0.18, 0.95)))
			overlay.add_child(_make_rect(Vector2(26, 18), Vector2(19, 6),  Color(0.28, 0.60, 0.22, 0.95)))
			# Canopy highlights
			overlay.add_child(_make_rect(Vector2(8, 6),   Vector2(22, 10), Color(0.42, 0.76, 0.26, 0.9)))
			overlay.add_child(_make_rect(Vector2(6, 6),   Vector2(36, 16), Color(0.42, 0.76, 0.26, 0.9)))

# ---------------------------------------------------------------------------
# Helper: create a mouse-filter-ignore ColorRect
# ---------------------------------------------------------------------------
func _make_rect(r_size: Vector2, r_pos: Vector2, r_color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.size         = r_size
	r.position     = r_pos
	r.color        = r_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
