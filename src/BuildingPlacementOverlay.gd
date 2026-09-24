# BuildingPlacementOverlay.gd
# Visual grid ghost preview when placing buildings (Clash of Clans / RTS style).
# Draws green footprint if the group of squares is valid, red if blocked.

class_name BuildingPlacementOverlay
extends Node2D

var farm_grid: Node2D = null

const TILE_SIZE: int = 64

func _draw() -> void:
	if farm_grid == null or not farm_grid.is_placing_building:
		return

	var fp: Vector2i = farm_grid.placing_footprint
	var gp: Vector2i = farm_grid.placing_hover_grid_pos

	var rect := Rect2(
		Vector2(gp.x * TILE_SIZE, gp.y * TILE_SIZE),
		Vector2(fp.x * TILE_SIZE, fp.y * TILE_SIZE)
	)

	var is_valid: bool = farm_grid.is_valid_building_placement(gp, fp)

	var fill_color   := Color(0.2, 0.85, 0.35, 0.30) if is_valid else Color(0.9, 0.2, 0.2, 0.35)
	var border_color := Color(0.3, 1.0, 0.45, 0.95) if is_valid else Color(1.0, 0.25, 0.25, 0.95)

	# Translucent footprint fill
	draw_rect(rect, fill_color, true)
	# Prominent border
	draw_rect(rect, border_color, false, 3.0)

	# Footprint tile division grid lines
	for x in range(1, fp.x):
		var lx: float = (gp.x + x) * TILE_SIZE
		draw_line(Vector2(lx, gp.y * TILE_SIZE), Vector2(lx, (gp.y + fp.y) * TILE_SIZE), border_color, 1.0)
	for y in range(1, fp.y):
		var ly: float = (gp.y + y) * TILE_SIZE
		draw_line(Vector2(gp.x * TILE_SIZE, ly), Vector2((gp.x + fp.x) * TILE_SIZE, ly), border_color, 1.0)
