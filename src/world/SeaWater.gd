# SeaWater.gd
# Renders the animated eastern coastal ocean and shoreline (Sarangani Bay / General Santos waters).
# Gives geographical context to the General Santos Seaport Terminal and prevents building anywhere
# except the designated eastern coastal port zone.
# Features living animated pixel-art isometric water tiles with traveling ocean swells and coastal surf.

class_name SeaWater
extends Node2D

const COAST_X: float = 32.0
const OCEAN_WIDTH: float = 14.0 # Extends 14 isometric tile lengths east
const GRID_HEIGHT: float = 32.0

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
	_rebuild_geometry()

func _rebuild_geometry() -> void:
	_ocean_polygon.clear()
	_coast_line.clear()

	# Base polygon covers entire eastern sea with safety margins
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
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
	)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _ocean_polygon.size() < 4:
		return

	var t: float = float(Time.get_ticks_msec()) * 0.001

	# 1. Base deep ocean bedrock floor (guarantees seamless color underlay)
	draw_colored_polygon(_ocean_polygon, Color(0.04, 0.16, 0.28, 0.98))

	# 2. Coastal shallow shelf background (tropical turquoise lagoon underlay)
	var shelf_polygon := PackedVector2Array([
		_get_iso_pt(COAST_X, -3.0),
		_get_iso_pt(COAST_X + 3.2, -3.0),
		_get_iso_pt(COAST_X + 3.2, GRID_HEIGHT + 3.0),
		_get_iso_pt(COAST_X, GRID_HEIGHT + 3.0)
	])
	draw_colored_polygon(shelf_polygon, Color(0.08, 0.45, 0.58, 0.85))

	# 3. Animated Isometric Sea Tile Grid
	if not _water_light_textures.is_empty() and not _water_dark_textures.is_empty():
		var min_gy: int = -2
		var max_gy: int = int(GRID_HEIGHT) + 2
		var min_gx: int = int(COAST_X)
		var max_gx: int = int(COAST_X + OCEAN_WIDTH) + 1

		# Outer loop on gy, inner on gx: sorts north-west to south-east for correct isometric slab overlap
		for gy in range(min_gy, max_gy + 1):
			for gx in range(min_gx, max_gx + 1):
				var dist_from_coast: float = float(gx - int(COAST_X))
				# Wave propagation equation: waves roll westwards toward the coastline with diagonal angular crest
				var wave_phase: float = t * 6.2 - dist_from_coast * 0.72 + float(gy) * 0.28
				var frame_idx: int = posmod(int(wave_phase), 8)

				var tex: Texture2D = null
				var mod_col := Color(1.0, 1.0, 1.0, 0.96)

				if dist_from_coast < 2.5:
					# Coastal shallow shelf: clear turquoise water with white cresting surf
					tex = _water_light_textures[frame_idx]
				elif dist_from_coast < 4.0:
					# Reef transition zone: gradual transition to deep ocean
					tex = _water_dark_textures[frame_idx]
					mod_col = Color(0.85, 0.94, 1.0, 0.96)
				else:
					# Deep oceanic bay: dark sapphire blue water
					tex = _water_dark_textures[frame_idx]

				if tex:
					var pt: Vector2 = _get_iso_pt(float(gx), float(gy)) - Vector2(64.0, 32.0)
					draw_texture_rect(tex, Rect2(pt.x, pt.y, 128.0, 128.0), false, mod_col)

	# 4. Shore foam and breaking surf washing dynamically against the golden beach sand
	if _coast_line.size() >= 2:
		var tide_wash: float = sin(t * 1.8) * 3.5
		var washed_coast := PackedVector2Array()
		for pt in _coast_line:
			washed_coast.append(pt + Vector2(-tide_wash * 0.7, tide_wash * 0.35))
		# Translucent water sheet washing up on beach sand
		draw_polyline(washed_coast, Color(0.20, 0.75, 0.85, 0.40), 7.0)
		var foam_alpha: float = 0.65 + 0.25 * sin(t * 3.0)
		draw_polyline(washed_coast, Color(0.92, 0.98, 1.0, foam_alpha), 4.0)
		draw_polyline(_coast_line, Color(0.35, 0.85, 0.95, 0.75), 2.0)

	# 5. Navigational marker buoys floating in Sarangani bay
	var buoy_positions := [Vector2(33.5, 8.0), Vector2(34.0, 18.0), Vector2(33.0, 26.0)]
	for bp in buoy_positions:
		var pt := _get_iso_pt(bp.x, bp.y) + Vector2(0, sin(t * 2.5 + bp.y) * 2.5)
		draw_circle(pt + Vector2(0, 3), 4.0, Color(0.02, 0.10, 0.18, 0.40))
		draw_circle(pt, 3.5, Color(0.95, 0.35, 0.20, 1.0))
		draw_circle(pt + Vector2(0, -3), 1.5, Color(1.0, 0.95, 0.40, 0.90))
