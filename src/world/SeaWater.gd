# SeaWater.gd
# Renders the animated eastern coastal ocean and shoreline (Sarangani Bay / General Santos waters).
# Gives geographical context to the General Santos Seaport Terminal and prevents building anywhere
# except the designated eastern coastal port zone.

class_name SeaWater
extends Node2D

const COAST_X: float = 24.0
const OCEAN_WIDTH: float = 14.0 # Extends 14 isometric tile lengths east
const GRID_HEIGHT: float = 24.0

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

	# Corner 1: (24, 0)
	var p_top_shore := _get_iso_pt(COAST_X, 0.0)
	# Corner 2: (24 + W, 0)
	var p_top_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH, 0.0)
	# Corner 3: (24 + W, 24)
	var p_bot_deep := _get_iso_pt(COAST_X + OCEAN_WIDTH, GRID_HEIGHT)
	# Corner 4: (24, 24)
	var p_bot_shore := _get_iso_pt(COAST_X, GRID_HEIGHT)

	_ocean_polygon = PackedVector2Array([
		p_top_shore,
		p_top_deep,
		p_bot_deep,
		p_bot_shore
	])

	# Shoreline vertices from (24, 0) to (24, 24)
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

	# 2. Deep ocean water body shading
	var deep_polygon := PackedVector2Array([
		_get_iso_pt(COAST_X + 4.0, 0.0),
		_get_iso_pt(COAST_X + OCEAN_WIDTH, 0.0),
		_get_iso_pt(COAST_X + OCEAN_WIDTH, GRID_HEIGHT),
		_get_iso_pt(COAST_X + 4.0, GRID_HEIGHT)
	])
	draw_colored_polygon(deep_polygon, Color(0.04, 0.18, 0.32, 0.70))

	# 3. Ambient animated gentle wave ripples
	for w in range(8):
		var y_phase: float = float(w) * 3.0 + fmod(t * 0.8 + float(w) * 1.5, 3.0)
		var offset_x: float = 1.5 + float(w) * 1.4
		var p1 := _get_iso_pt(COAST_X + offset_x, y_phase)
		var p2 := _get_iso_pt(COAST_X + offset_x + 3.0, y_phase + 1.8)
		var alpha: float = 0.25 + 0.15 * sin(t * 2.0 + float(w))
		draw_line(p1, p2, Color(0.40, 0.75, 0.95, alpha), 2.0)

	# 4. Shore foam and breaking surf against the eastern farmland
	if _coast_line.size() >= 2:
		var foam_alpha: float = 0.60 + 0.25 * sin(t * 3.0)
		draw_polyline(_coast_line, Color(0.85, 0.96, 1.0, foam_alpha), 5.0)
		draw_polyline(_coast_line, Color(0.35, 0.85, 0.95, 0.80), 2.5)

	# 5. Navigational marker buoys floating in Sarangani bay
	var buoy_positions := [Vector2(25.5, 6.0), Vector2(26.0, 14.0), Vector2(25.0, 20.0)]
	for bp in buoy_positions:
		var pt := _get_iso_pt(bp.x, bp.y) + Vector2(0, sin(t * 2.5 + bp.y) * 2.5)
		draw_circle(pt + Vector2(0, 3), 4.0, Color(0.02, 0.10, 0.18, 0.40))
		draw_circle(pt, 3.5, Color(0.95, 0.35, 0.20, 1.0))
		draw_circle(pt + Vector2(0, -3), 1.5, Color(1.0, 0.95, 0.40, 0.90))
