# BuildingPlacementOverlay.gd
# Visual grid ghost preview when placing buildings (Clash of Clans / RTS style).
# Draws green footprint if the group of squares is valid, red if blocked.

class_name BuildingPlacementOverlay
extends Node2D

var farm_grid: Node2D = null

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
	)

func _draw() -> void:
	if farm_grid == null or not farm_grid.is_placing_building:
		return

	var fp: Vector2i = farm_grid.placing_footprint
	var gp: Vector2i = farm_grid.placing_hover_grid_pos

	var is_valid: bool = farm_grid.is_valid_building_placement(gp, fp)

	var fill_color: Color   = Color(0.2, 0.85, 0.35, 0.35) if is_valid else Color(0.9, 0.2, 0.2, 0.35)
	var border_color: Color = Color(0.3, 1.0, 0.45, 0.95) if is_valid else Color(1.0, 0.25, 0.25, 0.95)

	# 1. Outer footprint diamond in 2:1 isometric projection
	var top_pt: Vector2    = _get_iso_pt(float(gp.x), float(gp.y))
	var right_pt: Vector2  = _get_iso_pt(float(gp.x + fp.x), float(gp.y))
	var bottom_pt: Vector2 = _get_iso_pt(float(gp.x + fp.x), float(gp.y + fp.y))
	var left_pt: Vector2   = _get_iso_pt(float(gp.x), float(gp.y + fp.y))

	var poly := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt])
	draw_colored_polygon(poly, fill_color)

	var border_loop := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt, top_pt])
	draw_polyline(border_loop, border_color, 3.0)

	# 2. Interior isometric tile subdivision lines
	for x in range(1, fp.x):
		var p1: Vector2 = _get_iso_pt(float(gp.x + x), float(gp.y))
		var p2: Vector2 = _get_iso_pt(float(gp.x + x), float(gp.y + fp.y))
		draw_line(p1, p2, border_color, 1.5)

	for y in range(1, fp.y):
		var p1: Vector2 = _get_iso_pt(float(gp.x), float(gp.y + y))
		var p2: Vector2 = _get_iso_pt(float(gp.x + fp.x), float(gp.y + y))
		draw_line(p1, p2, border_color, 1.5)

	# 3. Sprinkler spray radius coverage preview (glowing translucent cyan diamond)
	if farm_grid.placing_building_type == "sprinkler":
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_top    := _get_iso_pt(float(gp.x - rad), float(gp.y - rad))
		var cov_right  := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y - rad))
		var cov_bottom := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y + fp.y + rad))
		var cov_left   := _get_iso_pt(float(gp.x - rad), float(gp.y + fp.y + rad))

		var cov_poly := PackedVector2Array([cov_top, cov_right, cov_bottom, cov_left])
		draw_colored_polygon(cov_poly, Color(0.20, 0.65, 1.0, 0.22))
		draw_polyline(PackedVector2Array([cov_top, cov_right, cov_bottom, cov_left, cov_top]), Color(0.35, 0.85, 1.0, 0.85), 2.0)

		# Subdivide coverage grid lines
		for sx in range(-rad, fp.x + rad + 1):
			var sp1 := _get_iso_pt(float(gp.x + sx), float(gp.y - rad))
			var sp2 := _get_iso_pt(float(gp.x + sx), float(gp.y + fp.y + rad))
			draw_line(sp1, sp2, Color(0.35, 0.85, 1.0, 0.25), 1.0)
		for sy in range(-rad, fp.y + rad + 1):
			var sp1 := _get_iso_pt(float(gp.x - rad), float(gp.y + sy))
			var sp2 := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y + sy))
			draw_line(sp1, sp2, Color(0.35, 0.85, 1.0, 0.25), 1.0)

