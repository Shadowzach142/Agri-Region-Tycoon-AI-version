# DragSelectOverlay.gd
# Transparent Node2D rendered on TOP of all farm tile children.
# Draws the RTS-style marquee drag box and the golden multi-tile selection highlights.
# Added as the last child of FarmGrid with z_index = 200.

class_name DragSelectOverlay
extends Node2D

# Set by FarmGrid._ready() immediately after add_child()
var farm_grid: Node2D = null

const TILE_SIZE: int = 64

func _draw() -> void:
	if farm_grid == null:
		return

	# 1) Active drag rectangle (green marquee)
	if farm_grid.is_box_dragging:
		var rect: Rect2 = Rect2(
			farm_grid.drag_start_pos,
			farm_grid.drag_current_pos - farm_grid.drag_start_pos
		).abs()
		draw_rect(rect, Color(0.20, 0.85, 0.35, 0.18), true)          # translucent fill
		draw_rect(rect, Color(0.35, 1.0, 0.45, 0.95), false, 2.0)     # bright border

	# 2) Golden highlights over committed selected tiles
	for sel_pos in farm_grid.selected_tiles:
		var tile_rect: Rect2 = Rect2(
			Vector2(sel_pos.x, sel_pos.y) * TILE_SIZE,
			Vector2(TILE_SIZE, TILE_SIZE)
		)
		draw_rect(tile_rect, Color(1.0, 0.85, 0.15, 0.22), true)      # gold fill
		draw_rect(tile_rect, Color(1.0, 0.90, 0.20, 0.90), false, 2.5) # gold border
