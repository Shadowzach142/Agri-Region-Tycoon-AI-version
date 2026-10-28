# SeaWater.gd
# Renders the animated eastern water body along the farm's eastern boundary (gx >= 32.0).
# Gives geographical context to the seaport / riverport terminal and allows water-dependent
# buildings to be placed along the eastern boundary across all 5 regions.
# Dynamically adapts to represent each region's authentic geographic water body:
#   - Cotabato: Rio Grande de Mindanao / Pulangi River Canal (freshwater current & mooring stakes)
#   - South Cotabato: Lake Sebu / Lake Holon Crater Lake (crystal-blue glassy water & mountain lotuses)
#   - Sarangani: Sarangani Littoral Coast / Celebes Sea (tropical turquoise lagoon & rolling swells)
#   - Sultan Kudarat: Buluan Lake & Tacurong Wetlands (calm marsh water & bamboo fish traps)
#   - General Santos: Sarangani Bay Deepwater Seaport (deep industrial navy fairway & seawall wharf)

class_name SeaWater
extends Node2D

const COAST_X: float = 32.0
const OCEAN_WIDTH: float = 14.0 # Extends 14 isometric tile lengths east
const GRID_HEIGHT: float = 32.0

@export var region_key: String = ""

var _ocean_polygon: PackedVector2Array = []
var _coast_line: PackedVector2Array = []

var _water_light_textures: Array[Texture2D] = []
var _water_dark_textures: Array[Texture2D] = []
var _water_calm_textures: Array[Texture2D] = []

func _init() -> void:
	z_index = -40
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_textures()

func _load_textures() -> void:
	if _water_light_textures.is_empty():
		for i in range(1, 9):
			var path := "res://assets/sprites/water/water_light_%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					_water_light_textures.append(tex)

	if _water_dark_textures.is_empty():
		for i in range(1, 9):
			var path := "res://assets/sprites/water/water_dark_%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					_water_dark_textures.append(tex)

	if _water_calm_textures.is_empty():
		for i in range(1, 6):
			var path := "res://assets/sprites/water/water_%02d.png" % i
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex:
					_water_calm_textures.append(tex)

func _ready() -> void:
	_resolve_region()
	_rebuild_geometry()

func _resolve_region() -> String:
	if region_key != "":
		return region_key
	var data_node = get_tree().root.get_node_or_null("Data") if is_inside_tree() else null
	if data_node and "current_region" in data_node:
		region_key = data_node.current_region
	else:
		region_key = "cotabato"
	return region_key

func _rebuild_geometry() -> void:
	_ocean_polygon.clear()
	_coast_line.clear()

	# Base polygon covers entire eastern water body with safety margins
	var p_top_shore := _get_iso_pt(COAST_X, -4.0)
	var p_top_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH + 3.0, -4.0)
	var p_bot_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH + 3.0, GRID_HEIGHT + 4.0)
	var p_bot_shore := _get_iso_pt(COAST_X, GRID_HEIGHT + 4.0)

	_ocean_polygon = PackedVector2Array([
		p_top_shore,
		p_top_deep,
		p_bot_deep,
		p_bot_shore
	])

	# Shoreline vertices from (32, 0) to (32, 32)
	for y in range(int(GRID_HEIGHT) + 1):
		_coast_line.append(_get_iso_pt(COAST_X, float(y)))

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy + 1.0) * FarmerMovement.HALF_H
	)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _ocean_polygon.size() < 4:
		return

	var reg := _resolve_region()
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# Regional Color & Visual Palettes
	var col_deep: Color
	var col_shelf: Color
	var shelf_width: float = 3.2

	match reg:
		"cotabato":
			# Pulangi River / Rio Grande de Mindanao: Freshwater river emerald & alluvial silt
			col_deep = Color(0.06, 0.22, 0.26, 0.98)
			col_shelf = Color(0.18, 0.34, 0.30, 0.88)
			shelf_width = 2.4
		"south_cotabato":
			# Lake Sebu / Lake Holon: Deep alpine crater lake crystal sapphire & volcanic gravel
			col_deep = Color(0.04, 0.14, 0.32, 0.98)
			col_shelf = Color(0.10, 0.26, 0.42, 0.85)
			shelf_width = 2.2
		"sultan_kudarat":
			# Buluan Lake & Tacurong Wetlands: Nutrient-rich agricultural wetland water & loam silt
			col_deep = Color(0.09, 0.23, 0.21, 0.98)
			col_shelf = Color(0.17, 0.32, 0.24, 0.85)
			shelf_width = 3.0
		"general_santos":
			# Sarangani Bay Seaport: Industrial deep ocean navy & concrete seawall embankment
			col_deep = Color(0.02, 0.09, 0.20, 0.98)
			col_shelf = Color(0.06, 0.24, 0.38, 0.88)
			shelf_width = 2.0
		_: # "sarangani" default
			# Sarangani Littoral Coast: Sun-drenched turquoise coral reef shelf & oceanic abyss
			col_deep = Color(0.04, 0.16, 0.28, 0.98)
			col_shelf = Color(0.08, 0.45, 0.58, 0.85)
			shelf_width = 3.4

	# 1. Base deep water bedrock floor
	draw_colored_polygon(_ocean_polygon, col_deep)

	# 2. Shallow shoreline shelf
	var shelf_polygon := PackedVector2Array([
		_get_iso_pt(COAST_X, -3.0),
		_get_iso_pt(COAST_X + shelf_width, -3.0),
		_get_iso_pt(COAST_X + shelf_width, GRID_HEIGHT + 3.0),
		_get_iso_pt(COAST_X, GRID_HEIGHT + 3.0)
	])
	draw_colored_polygon(shelf_polygon, col_shelf)

	# 3. Animated Isometric Water Surface Grid
	var min_gy: int = -2
	var max_gy: int = int(GRID_HEIGHT) + 2
	var min_gx: int = int(COAST_X)
	var max_gx: int = int(COAST_X + OCEAN_WIDTH) + 1

	for gy in range(min_gy, max_gy + 1):
		for gx in range(min_gx, max_gx + 1):
			var dist: float = float(gx - int(COAST_X))
			var pt: Vector2 = _get_iso_pt(float(gx), float(gy)) - Vector2(64.0, 32.0)
			var rect := Rect2(pt.x, pt.y, 128.0, 128.0)

			match reg:
				"cotabato":
					# Active river current flowing south-east along the Pulangi
					if not _water_calm_textures.is_empty():
						var flow: float = sin(t * 1.6 + float(gx) * 0.5 - float(gy) * 0.35)
						var f_idx: int = int(abs(flow) * float(_water_calm_textures.size())) % _water_calm_textures.size()
						var tex: Texture2D = _water_calm_textures[f_idx]
						var mod_col := Color(0.78, 0.96, 0.90, 0.80)
						draw_texture_rect(tex, rect, false, mod_col)

				"south_cotabato":
					# Ultra-tranquil, glassy alpine crater lake surface
					if not _water_calm_textures.is_empty():
						var breathe: float = sin(t * 0.65 - dist * 0.2 + float(gy) * 0.1)
						var f_idx: int = int(abs(breathe) * float(_water_calm_textures.size())) % _water_calm_textures.size()
						var tex: Texture2D = _water_calm_textures[f_idx]
						var mod_col := Color(0.68, 0.86, 1.0, 0.72)
						draw_texture_rect(tex, rect, false, mod_col)

				"sultan_kudarat":
					# Calm agricultural wetland ripples
					if not _water_calm_textures.is_empty():
						var marsh: float = sin(t * 0.95 + float(gx) * 0.3 - float(gy) * 0.2)
						var f_idx: int = int(abs(marsh) * float(_water_calm_textures.size())) % _water_calm_textures.size()
						var tex: Texture2D = _water_calm_textures[f_idx]
						var mod_col := Color(0.80, 0.94, 0.82, 0.76)
						draw_texture_rect(tex, rect, false, mod_col)

				"general_santos":
					# Industrial seaport deep ocean swell
					if not _water_dark_textures.is_empty():
						var swell: float = sin(t * 0.90 - dist * 0.30 + float(gy) * 0.15)
						var f_idx: int = clampi(int(clampf((swell - 0.10) / 0.90, 0.0, 1.0) * 7.99), 0, 7)
						var tex: Texture2D = _water_dark_textures[f_idx]
						var mod_col := Color(0.70, 0.82, 0.95, 0.90)
						draw_texture_rect(tex, rect, false, mod_col)

				_: # "sarangani"
					# Tropical ocean wave crests & clear lagoon transition
					if not _water_light_textures.is_empty() and not _water_dark_textures.is_empty():
						var swell: float = sin(t * 0.85 - dist * 0.35 + float(gy) * 0.14)
						var f_idx: int = clampi(int(clampf((swell - 0.10) / 0.90, 0.0, 1.0) * 7.99), 0, 7)
						var tex: Texture2D = _water_light_textures[f_idx] if dist < 2.5 else _water_dark_textures[f_idx]
						var mod_col := Color(1.0, 1.0, 1.0, 0.95) if dist < 2.5 else Color(0.76, 0.86, 0.95, 0.92)
						draw_texture_rect(tex, rect, false, mod_col)

	# 4. Regional Shoreline Dynamics & Landmark Features
	match reg:
		"cotabato":
			# Pulangi River Current Streaks & Mooring Posts
			for i in range(14):
				var rx: float = COAST_X + 0.8 + float(i % 4) * 2.2
				var ry: float = float(i * 2.3) + sin(t * 0.8 + float(i)) * 1.5
				var p1 := _get_iso_pt(rx, ry)
				var p2 := _get_iso_pt(rx + 1.6, ry + 0.6)
				draw_line(p1, p2, Color(0.85, 0.98, 0.95, 0.40), 2.0)

			# Wooden mooring posts driven into the riverbank for docking bangka boats
			for py in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0]:
				var pt := _get_iso_pt(COAST_X + 0.3, py)
				# Post shadow
				draw_circle(pt + Vector2(2, 4), 3.5, Color(0.04, 0.10, 0.08, 0.50))
				# Wooden piling
				draw_line(pt + Vector2(0, 4), pt + Vector2(0, -12), Color(0.38, 0.26, 0.14, 1.0), 3.5)
				draw_line(pt + Vector2(0, -8), pt + Vector2(0, -12), Color(0.55, 0.40, 0.22, 1.0), 3.5)
				# Mooring rope ring
				draw_circle(pt + Vector2(0, -8), 2.2, Color(0.80, 0.70, 0.45, 0.90))

		"south_cotabato":
			# Glassy Lake Sebu Specular Sheen & Floating Mountain Lotuses
			for i in range(10):
				var lx: float = COAST_X + 1.2 + float(i % 3) * 1.8
				var ly: float = 1.5 + float(i * 3.1)
				var pt := _get_iso_pt(lx, ly) + Vector2(sin(t * 0.4 + float(i)) * 2.0, 0)
				# Lily pad
				draw_circle(pt, 5.0, Color(0.18, 0.45, 0.25, 0.85))
				draw_circle(pt + Vector2(1, -1), 2.0, Color(0.95, 0.80, 0.90, 0.95)) # Blossom

			# Submerged volcanic shoreline rocks
			for ry in [4.0, 9.0, 15.0, 21.0, 27.0]:
				var pt := _get_iso_pt(COAST_X + 0.4, ry)
				draw_circle(pt + Vector2(0, 2), 6.0, Color(0.15, 0.18, 0.22, 0.75))
				draw_circle(pt, 4.5, Color(0.28, 0.32, 0.36, 0.85))

		"sultan_kudarat":
			# Traditional Bamboo Fish Traps (Baklad) & Wetland Reeds
			for by in [4.0, 11.0, 18.0, 25.0]:
				var root := _get_iso_pt(COAST_X + 1.2, by)
				# Diamond bamboo fish trap corral stakes
				var p_n := root + Vector2(0, -12)
				var p_e := root + Vector2(24, 0)
				var p_s := root + Vector2(0, 12)
				var p_w := root + Vector2(-24, 0)
				draw_polyline(PackedVector2Array([p_n, p_e, p_s, p_w, p_n]), Color(0.48, 0.38, 0.22, 0.90), 2.0)
				for stake in [p_n, p_e, p_s, p_w]:
					draw_line(stake + Vector2(0, 3), stake + Vector2(0, -8), Color(0.60, 0.48, 0.26, 1.0), 2.5)

			# Tall marsh reeds along the edge
			for ry in range(0, 32, 3):
				var rpt := _get_iso_pt(COAST_X + 0.2, float(ry) + 0.5)
				var sway: float = sin(t * 1.5 + float(ry)) * 2.0
				draw_line(rpt, rpt + Vector2(sway - 2, -14), Color(0.25, 0.42, 0.18, 0.90), 2.0)
				draw_line(rpt + Vector2(2, 0), rpt + Vector2(sway + 3, -16), Color(0.35, 0.52, 0.24, 0.90), 2.0)

		"general_santos":
			# Seawall Concrete Embankment & Harbor Starboard/Port Buoys
			if _coast_line.size() >= 2:
				# Heavy concrete wharf seawall cap
				draw_polyline(_coast_line, Color(0.22, 0.24, 0.26, 0.98), 8.0)
				draw_polyline(_coast_line, Color(0.48, 0.50, 0.52, 0.95), 4.0)

			# Industrial harbor channel fairway buoys
			var port_buoys := [
				{"pos": Vector2(33.5, 6.0), "col": Color(0.95, 0.25, 0.20)}, # Starboard Red
				{"pos": Vector2(34.2, 16.0), "col": Color(0.20, 0.90, 0.35)}, # Port Green
				{"pos": Vector2(33.5, 26.0), "col": Color(0.95, 0.85, 0.20)}, # Caution Yellow
			]
			for b in port_buoys:
				var bp: Vector2 = b["pos"]
				var bcol: Color = b["col"]
				var pt := _get_iso_pt(bp.x, bp.y) + Vector2(0, sin(t * 0.8 + bp.y) * 1.5)
				draw_circle(pt + Vector2(0, 3), 4.5, Color(0.02, 0.08, 0.15, 0.45))
				draw_circle(pt, 4.0, bcol)
				# Flashing light beacon
				var flash: float = 0.5 + 0.5 * sin(t * 3.0 + bp.y * 2.0)
				draw_circle(pt + Vector2(0, -4), 2.0, Color(1.0, 1.0, 0.70, flash))

		_: # "sarangani"
			# Rhythmic gentle surf wash on beach sand
			if _coast_line.size() >= 2:
				var tide_wash: float = sin(t * 0.45) * 2.2
				var washed_coast := PackedVector2Array()
				for pt in _coast_line:
					washed_coast.append(pt + Vector2(-tide_wash * 0.55, tide_wash * 0.28))
				draw_polyline(washed_coast, Color(0.20, 0.75, 0.85, 0.25), 5.0)
				var foam_alpha: float = 0.42 + 0.16 * sin(t * 0.55)
				draw_polyline(washed_coast, Color(0.92, 0.97, 1.0, foam_alpha), 2.5)

			# Navigational marker buoys
			var buoy_positions := [Vector2(33.5, 8.0), Vector2(34.0, 18.0), Vector2(33.0, 26.0)]
			for bp in buoy_positions:
				var pt := _get_iso_pt(bp.x, bp.y) + Vector2(0, sin(t * 0.75 + bp.y * 1.5) * 1.8)
				draw_circle(pt + Vector2(0, 3), 4.0, Color(0.02, 0.10, 0.18, 0.35))
				draw_circle(pt, 3.5, Color(0.95, 0.35, 0.20, 1.0))
				draw_circle(pt + Vector2(0, -3), 1.5, Color(1.0, 0.95, 0.40, 0.90))
