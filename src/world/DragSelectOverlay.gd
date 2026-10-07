# DragSelectOverlay.gd
# Transparent Node2D rendered on TOP of all farm tile children.
# Draws the RTS-style marquee drag box and the golden multi-tile selection highlights.
# Added as the last child of FarmGrid with z_index = 200.

class_name DragSelectOverlay
extends Node2D

# Set by FarmGrid._ready() immediately after add_child()
var farm_grid: Node2D = null
 
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
	)

func _draw() -> void:
	if farm_grid == null:
		return

	# 1) Active drag selection area in 2:1 isometric projection
	if farm_grid.is_box_dragging:
		var g_start := FarmerMovement.pixel_to_grid(farm_grid.to_global(farm_grid.drag_start_pos), farm_grid)
		var g_cur   := FarmerMovement.pixel_to_grid(farm_grid.to_global(farm_grid.drag_current_pos), farm_grid)

		var min_x: int = clampi(min(g_start.x, g_cur.x), 0, farm_grid.GRID_SIZE.x - 1)
		var max_x: int = clampi(max(g_start.x, g_cur.x), 0, farm_grid.GRID_SIZE.x - 1)
		var min_y: int = clampi(min(g_start.y, g_cur.y), 0, farm_grid.GRID_SIZE.y - 1)
		var max_y: int = clampi(max(g_start.y, g_cur.y), 0, farm_grid.GRID_SIZE.y - 1)

		var top_pt: Vector2    = _get_iso_pt(float(min_x), float(min_y))
		var right_pt: Vector2  = _get_iso_pt(float(max_x + 1), float(min_y))
		var bottom_pt: Vector2 = _get_iso_pt(float(max_x + 1), float(max_y + 1))
		var left_pt: Vector2   = _get_iso_pt(float(min_x), float(max_y + 1))

		var is_drone_mode: bool = false
		var plant_hotbar = get_tree().root.find_child("PlantHotbar", true, false)
		if plant_hotbar and plant_hotbar.has_method("get_selected_tool"):
			is_drone_mode = (plant_hotbar.get_selected_tool() == "drone_zone")

		var fill_col   := Color(0.20, 0.75, 1.0, 0.22) if is_drone_mode else Color(0.20, 0.85, 0.40, 0.22)
		var border_col := Color(0.40, 0.88, 1.0, 0.95) if is_drone_mode else Color(0.35, 1.0, 0.50, 0.95)
		var grid_col   := Color(0.40, 0.88, 1.0, 0.40) if is_drone_mode else Color(0.35, 1.0, 0.50, 0.40)

		var poly := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt])
		draw_colored_polygon(poly, fill_col)

		var border := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt, top_pt])
		draw_polyline(border, border_col, 2.5)

		# Interior isometric tile division lines
		for x in range(min_x + 1, max_x + 1):
			var p1: Vector2 = _get_iso_pt(float(x), float(min_y))
			var p2: Vector2 = _get_iso_pt(float(x), float(max_y + 1))
			draw_line(p1, p2, grid_col, 1.5)

		for y in range(min_y + 1, max_y + 1):
			var p1: Vector2 = _get_iso_pt(float(min_x), float(y))
			var p2: Vector2 = _get_iso_pt(float(max_x + 1), float(y))
			draw_line(p1, p2, grid_col, 1.5)

	# 2) Golden highlights over committed selected tiles in 2.5D isometric view
	var drawn_selected: Dictionary = {}
	for sel_pos in farm_grid.selected_tiles:
		if not farm_grid._is_valid(sel_pos):
			continue
		var tile: FarmTile = farm_grid.tiles[sel_pos.x][sel_pos.y]
		var is_multi: bool = (tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1))
		var root_pos: Vector2i = sel_pos if not is_multi else (sel_pos if tile.is_multi_tile_root else tile.multi_tile_root_pos)
		if is_multi:
			if drawn_selected.has(root_pos):
				continue
			drawn_selected[root_pos] = true
			for dx in range(2):
				for dy in range(2):
					drawn_selected[root_pos + Vector2i(dx, dy)] = true
			var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(root_pos, Vector2i(2, 2))
			var border_pts := PackedVector2Array(poly)
			border_pts.append(poly[0])
			draw_polyline(border_pts, Color(1.0, 0.90, 0.20, 0.92), 2.5)
		else:
			if drawn_selected.has(sel_pos):
				continue
			drawn_selected[sel_pos] = true
			var diamond: PackedVector2Array = FarmerMovement.get_tile_diamond_local(sel_pos)
			var border_pts := PackedVector2Array(diamond)
			border_pts.append(diamond[0])  # close loop
			draw_polyline(border_pts, Color(1.0, 0.90, 0.20, 0.92), 2.5)

	# 3) Persistent green highlights on tiles with active/pending tasks (plow, plant, water, harvest, spray)
	_draw_task_highlights()

	# 4) Active tool / plant hover cursor matching footprint and soil validity
	_draw_tool_hover()

func _draw_task_highlights() -> void:
	if farm_grid == null:
		return

	var tasks: Array[Dictionary] = TaskManager.get_active_tasks()
	if tasks.is_empty():
		return

	var green_fill         := Color(0.18, 0.85, 0.35, 0.26)
	var green_border       := Color(0.35, 1.0, 0.45, 0.90)
	var active_green_fill   := Color(0.24, 0.92, 0.38, 0.35)
	var active_green_border := Color(0.50, 1.0, 0.60, 1.00)

	var drawn_tiles: Dictionary = {}

	for t in tasks:
		var task_type: String = t.get("type", "")
		if task_type != "plow" and task_type != "plant" and task_type != "water" and task_type != "harvest" and task_type != "spray_pest":
			continue

		var root_pos: Vector2i = t.get("position", Vector2i(-1, -1))
		if root_pos == Vector2i(-1, -1) or not farm_grid._is_valid(root_pos):
			continue

		var is_active: bool = t.get("is_active", false)
		var fill_color: Color = active_green_fill if is_active else green_fill
		var border_color: Color = active_green_border if is_active else green_border
		var border_width: float = 2.5 if is_active else 2.0

		var fp: Vector2i = Vector2i(1, 1)
		var root_tile: FarmTile = farm_grid.tiles[root_pos.x][root_pos.y]
		if task_type == "plant":
			var crop_name: String = t.get("crop_type", "")
			if not crop_name.is_empty():
				var c_data: Dictionary = Data.get_crop(crop_name)
				fp = c_data.get("footprint", Vector2i(1, 1))
		elif root_tile.is_multi_tile_root or root_tile.multi_tile_root_pos != Vector2i(-1, -1):
			fp = Vector2i(2, 2)
			root_pos = root_pos if root_tile.is_multi_tile_root else root_tile.multi_tile_root_pos

		if fp == Vector2i(1, 1):
			if drawn_tiles.has(root_pos):
				continue
			var tile: FarmTile = farm_grid.tiles[root_pos.x][root_pos.y]
			# If the plow task has completed and tile is already PLOWED, skip
			if task_type == "plow" and tile.state == FarmTile.TileState.PLOWED:
				continue
			# If the plant task has completed and tile is already PLANTED/GROWING, skip
			if task_type == "plant" and tile.state != FarmTile.TileState.PLOWED:
				continue

			drawn_tiles[root_pos] = true
			var diamond: PackedVector2Array = FarmerMovement.get_tile_diamond_local(root_pos)
			var border_pts := PackedVector2Array(diamond)
			border_pts.append(diamond[0])
			draw_polyline(border_pts, border_color, border_width)

		else:
			# Multi-tile (e.g. 2x2 Coconut Palm grove)
			if task_type == "plant" and root_tile.state != FarmTile.TileState.PLOWED:
				continue

			for dx in range(fp.x):
				for dy in range(fp.y):
					var p := root_pos + Vector2i(dx, dy)
					if not farm_grid._is_valid(p):
						continue
					drawn_tiles[p] = true

			# Outer bounding diamond for the multi-tile footprint
			var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(root_pos, fp)
			var outer_border := PackedVector2Array(poly)
			outer_border.append(poly[0])
			draw_polyline(outer_border, border_color, border_width + 0.5)

			# Interior division lines (only when planting seeds)
			if task_type == "plant":
				var div_line_color := border_color
				div_line_color.a *= 0.5
				for x in range(1, fp.x):
					var p1: Vector2 = _get_iso_pt(float(root_pos.x + x), float(root_pos.y))
					var p2: Vector2 = _get_iso_pt(float(root_pos.x + x), float(root_pos.y + fp.y))
					draw_line(p1, p2, div_line_color, 1.5)

				for y in range(1, fp.y):
					var p1: Vector2 = _get_iso_pt(float(root_pos.x), float(root_pos.y + y))
					var p2: Vector2 = _get_iso_pt(float(root_pos.x + fp.x), float(root_pos.y + y))
					draw_line(p1, p2, div_line_color, 1.5)

func _draw_tool_hover() -> void:
	if farm_grid == null:
		return
	if farm_grid.is_box_dragging or farm_grid.is_placing_building:
		return
	if farm_grid.has_method("_is_any_menu_open") and farm_grid._is_any_menu_open():
		return

	var gp: Vector2i = farm_grid.hovered_grid_pos
	if gp == Vector2i(-1, -1) or not farm_grid._is_valid(gp):
		return

	# If mouse is hovering over an interactive UI element, suppress the in-world hover
	var vp := get_viewport()
	if vp:
		var hovered_ctrl := vp.gui_get_hovered_control()
		if hovered_ctrl != null and hovered_ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return

	# Only draw tool hover when a farmer is selected and plant hotbar is active
	if TaskManager.get_selected_farmers().is_empty():
		return

	var plant_hotbar = get_tree().root.find_child("PlantHotbar", true, false)
	if plant_hotbar == null or not plant_hotbar.visible:
		return

	var active_tool: String = ""
	if plant_hotbar and plant_hotbar.has_method("get_selected_tool"):
		active_tool = plant_hotbar.get_selected_tool()
	if active_tool.is_empty():
		return

	var h_tile: FarmTile = farm_grid.tiles[gp.x][gp.y]
	var is_planted_multi: bool = (h_tile.is_multi_tile_root or h_tile.multi_tile_root_pos != Vector2i(-1, -1))
	var root_pos: Vector2i = gp if not is_planted_multi else (gp if h_tile.is_multi_tile_root else h_tile.multi_tile_root_pos)

	var target_gp: Vector2i = gp
	var fp: Vector2i = farm_grid.get_tool_footprint(active_tool)
	var is_standing_2x2: bool = false

	if is_planted_multi:
		target_gp = root_pos
		fp = Vector2i(2, 2)
		is_standing_2x2 = true

	var is_overall_valid: bool = farm_grid.is_valid_tool_target(target_gp, active_tool)

	var green_fill   := Color(0.20, 0.85, 0.35, 0.30)
	var green_border := Color(0.35, 1.0, 0.45, 0.95)
	var green_line   := Color(0.35, 1.0, 0.45, 0.50)

	var red_fill     := Color(0.90, 0.20, 0.20, 0.30)
	var red_border   := Color(1.0, 0.25, 0.25, 0.95)
	var red_line     := Color(1.0, 0.25, 0.25, 0.50)

	# 1. Highlight blocked/invalid sub-tiles with a red outline (only when placing/planting, not for standing 2x2 crop)
	if not is_standing_2x2:
		for dx in range(fp.x):
			for dy in range(fp.y):
				var sub_pos := target_gp + Vector2i(dx, dy)
				var sub_valid: bool = farm_grid.is_valid_tool_target(sub_pos, active_tool)

				if not sub_valid:
					var t_top: Vector2    = _get_iso_pt(float(sub_pos.x), float(sub_pos.y))
					var t_right: Vector2  = _get_iso_pt(float(sub_pos.x + 1), float(sub_pos.y))
					var t_bottom: Vector2 = _get_iso_pt(float(sub_pos.x + 1), float(sub_pos.y + 1))
					var t_left: Vector2   = _get_iso_pt(float(sub_pos.x), float(sub_pos.y + 1))
					var sub_diamond := PackedVector2Array([t_top, t_right, t_bottom, t_left, t_top])
					draw_polyline(sub_diamond, red_border, 1.8)

	# 2. Outer bounding diamond matching full footprint
	var top_pt: Vector2    = _get_iso_pt(float(target_gp.x), float(target_gp.y))
	var right_pt: Vector2  = _get_iso_pt(float(target_gp.x + fp.x), float(target_gp.y))
	var bottom_pt: Vector2 = _get_iso_pt(float(target_gp.x + fp.x), float(target_gp.y + fp.y))
	var left_pt: Vector2   = _get_iso_pt(float(target_gp.x), float(target_gp.y + fp.y))

	var outer_border_color := green_border if is_overall_valid else red_border
	var outer_border := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt, top_pt])
	draw_polyline(outer_border, outer_border_color, 2.5)

	# 3. Interior division lines if multi-tile footprint (e.g. 2x2 Coconut or larger), but only when placing/planting seeds on empty land
	if not is_standing_2x2:
		var div_line_color := green_line if is_overall_valid else red_line
		for x in range(1, fp.x):
			var p1: Vector2 = _get_iso_pt(float(target_gp.x + x), float(target_gp.y))
			var p2: Vector2 = _get_iso_pt(float(target_gp.x + x), float(target_gp.y + fp.y))
			draw_line(p1, p2, div_line_color, 1.5)

		for y in range(1, fp.y):
			var p1: Vector2 = _get_iso_pt(float(target_gp.x), float(target_gp.y + y))
			var p2: Vector2 = _get_iso_pt(float(target_gp.x + fp.x), float(target_gp.y + y))
			draw_line(p1, p2, div_line_color, 1.5)


