# SeaWater.gd
# Renders the animated eastern coastal ocean and shoreline (Sarangani Bay / General Santos waters).
# Gives geographical context to the General Santos Seaport Terminal and prevents building anywhere
# except the designated eastern coastal port zone.

class_name SeaWater
extends Node2D

const COAST_X: float = 32.0
const OCEAN_WIDTH: float = 14.0 # Extends 14 isometric tile lengths east
const GRID_HEIGHT: float = 32.0

var _ocean_polygon: PackedVector2Array = []
var _coast_line: PackedVector2Array = []

func _init() -> void:
	z_index = -40
	z_as_relative = false

func _ready() -> void:
	_rebuild_geometry()

func _rebuild_geometry() -> void:
	_ocean_polygon.clear()
	_coast_line.clear()

	# Corner 1: (32, 0)
	var p_top_shore := _get_iso_pt(COAST_X, 0.0)
	# Corner 2: (32 + W, 0)
	var p_top_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH, 0.0)
	# Corner 3: (32 + W, 32)
	var p_bot_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH, GRID_HEIGHT)
	# Corner 4: (32, 32)
	var p_bot_shore := _get_iso_pt(COAST_X, GRID_HEIGHT)

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

	# 1. Base deep ocean water fill (tropical Philippine bay)
	draw_colored_polygon(_ocean_polygon, Color(0.06, 0.28, 0.44, 0.95))

	# 2. Coastal shallow shelf (clear tropical turquoise water over beach sand)
	var shelf_polygon := PackedVector2Array([
		_get_iso_pt(COAST_X, 0.0),
		_get_iso_pt(COAST_X + 2.2, 0.0),
		_get_iso_pt(COAST_X + 2.2, GRID_HEIGHT),
		_get_iso_pt(COAST_X, GRID_HEIGHT)
	])
	draw_colored_polygon(shelf_polygon, Color(0.10, 0.62, 0.70, 0.60))

	# 3. Deep ocean water body shading (further out)
	var deep_polygon := PackedVector2Array([
		_get_iso_pt(COAST_X + 4.5, 0.0),
		_get_iso_pt(COAST_X + OCEAN_WIDTH, 0.0),
		_get_iso_pt(COAST_X + OCEAN_WIDTH, GRID_HEIGHT),
		_get_iso_pt(COAST_X + 4.5, GRID_HEIGHT)
	])
	draw_colored_polygon(deep_polygon, Color(0.04, 0.16, 0.30, 0.75))

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

	# 5. Ambient animated gentle wave ripples
	for w in range(10):
		var y_phase: float = float(w) * 2.4 + fmod(t * 0.85 + float(w) * 1.4, 3.0)
		var offset_x: float = 1.0 + float(w) * 1.3
		var p1 := _get_iso_pt(COAST_X + offset_x, y_phase)
		var p2 := _get_iso_pt(COAST_X + offset_x + 2.8, y_phase + 1.6)
		var is_shallow: bool = offset_x < 2.5
		var col: Color = Color(0.55, 0.92, 1.0, 0.40 + 0.20 * sin(t * 2.2 + float(w))) if is_shallow else Color(0.35, 0.70, 0.90, 0.25 + 0.15 * sin(t * 2.0 + float(w)))
		draw_line(p1, p2, col, 2.0)

	# 5. Navigational marker buoys floating in Sarangani bay
	var buoy_positions := [Vector2(33.5, 8.0), Vector2(34.0, 18.0), Vector2(33.0, 26.0)]
	for bp in buoy_positions:
		var pt := _get_iso_pt(bp.x, bp.y) + Vector2(0, sin(t * 2.5 + bp.y) * 2.5)
		draw_circle(pt + Vector2(0, 3), 4.0, Color(0.02, 0.10, 0.18, 0.40))
		draw_circle(pt, 3.5, Color(0.95, 0.35, 0.20, 1.0))
		draw_circle(pt + Vector2(0, -3), 1.5, Color(1.0, 0.95, 0.40, 0.90))
