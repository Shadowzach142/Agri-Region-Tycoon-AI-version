# BuildingPlacementOverlay.gd
# Visual grid ghost preview when placing buildings (Clash of Clans / RTS style).
# Draws green footprint if the group of squares is valid, red if blocked.
# Includes authentic high-res building sprite ghost, footprint ratio badge, and shoreline indicators.

class_name BuildingPlacementOverlay
extends Node2D

var farm_grid: Node2D = null

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
	var b_type: String = farm_grid.placing_building_type

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

	# 3. Authentic Sprite Ghost Preview (scaled 1:1 to footprint diamond)
	var is_flipped: bool = farm_grid.placing_is_flipped if (farm_grid != null and "placing_is_flipped" in farm_grid) else false
	var prev: Dictionary = Building.get_placement_preview(b_type, is_flipped)
	if not prev.is_empty() and prev.has("texture") and prev["texture"] != null:
		var tex: Texture2D = prev["texture"]
		var sc: float = float(prev.get("scale", 1.0))
		var center := (top_pt + bottom_pt) * 0.5
		var coff: Vector2 = prev.get("center_offset", Vector2.ZERO)
		var sprite_origin: Vector2 = center - coff * sc
		var dsz := tex.get_size() * sc
		var ghost_mod: Color = Color(1.0, 1.0, 1.0, 0.65) if is_valid else Color(1.0, 0.40, 0.40, 0.50)
		var has_dedicated_flip: bool = prev.get("has_dedicated_flip", false)
		if is_flipped and Data.get_building(b_type).get("is_decoration", false) and not has_dedicated_flip:
			draw_set_transform(Vector2(center.x, sprite_origin.y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(tex, Rect2(-coff.x * sc, 0.0, dsz.x, dsz.y), false, ghost_mod)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, Rect2(sprite_origin, dsz), false, ghost_mod)

	# 4. Footprint Ratio & Scale Badge above the placement diamond
	var font := ThemeDB.fallback_font
	var font_size: int = 12
	var flip_str: String = " | [R] Flipped 🔄" if is_flipped else " | [R] Normal"
	var ratio_text: String = "%d×%d Tiles (Ratio 1:1)%s" % [fp.x, fp.y, flip_str]
	var text_w: float = font.get_string_size(ratio_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var badge_pos: Vector2 = top_pt + Vector2(-text_w * 0.5, -16.0)
	var badge_rect := Rect2(badge_pos - Vector2(8, 2), Vector2(text_w + 16, 18))
	draw_rect(badge_rect, Color(0.12, 0.08, 0.05, 0.88), true, 4.0)
	draw_rect(badge_rect, border_color, false, 1.5)
	draw_string(font, badge_pos + Vector2(0, 12), ratio_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.85))

	# 5. Shoreline Highlighting & Guidance for Seaport
	var requires_shore: bool = bool(Data.get_building(b_type).get("requires_shore", false))
	if requires_shore:
		var is_at_shore: bool = (gp.x + fp.x) == farm_grid.GRID_SIZE.x
		# Draw glowing shoreline indicator on the eastern coastline
		var t: float = float(Time.get_ticks_msec()) * 0.001
		var shore_p1 := _get_iso_pt(float(farm_grid.GRID_SIZE.x), 0.0)
		var shore_p2 := _get_iso_pt(float(farm_grid.GRID_SIZE.x), float(farm_grid.GRID_SIZE.y))
		var shore_pulse: float = 0.5 + 0.4 * sin(t * 4.0)
		draw_line(shore_p1, shore_p2, Color(0.35, 0.85, 1.0, shore_pulse), 4.5)

		if not is_at_shore:
			var hint_text := "⚓ Must Touch Eastern Coastline!"
			var hint_w: float = font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var hint_pos: Vector2 = top_pt + Vector2(-hint_w * 0.5, -38.0)
			var hint_rect := Rect2(hint_pos - Vector2(8, 2), Vector2(hint_w + 16, 18))
			draw_rect(hint_rect, Color(0.18, 0.05, 0.05, 0.92), true, 4.0)
			draw_rect(hint_rect, Color(1.0, 0.35, 0.35, 0.95), false, 1.5)
			draw_string(font, hint_pos + Vector2(0, 12), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.85))

	# 6. Sprinkler spray radius coverage preview
	if b_type == "sprinkler":
		var rad: int = BuildingManager.get_sprinkler_radius()
		var cov_top    := _get_iso_pt(float(gp.x - rad), float(gp.y - rad))
		var cov_right  := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y - rad))
		var cov_bottom := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y + fp.y + rad))
		var cov_left   := _get_iso_pt(float(gp.x - rad), float(gp.y + fp.y + rad))

		var cov_poly := PackedVector2Array([cov_top, cov_right, cov_bottom, cov_left])
		draw_colored_polygon(cov_poly, Color(0.20, 0.65, 1.0, 0.22))
		draw_polyline(PackedVector2Array([cov_top, cov_right, cov_bottom, cov_left, cov_top]), Color(0.35, 0.85, 1.0, 0.85), 2.0)

		for sx in range(-rad, fp.x + rad + 1):
			var sp1 := _get_iso_pt(float(gp.x + sx), float(gp.y - rad))
			var sp2 := _get_iso_pt(float(gp.x + sx), float(gp.y + fp.y + rad))
			draw_line(sp1, sp2, Color(0.35, 0.85, 1.0, 0.25), 1.0)
		for sy in range(-rad, fp.y + rad + 1):
			var sp1 := _get_iso_pt(float(gp.x - rad), float(gp.y + sy))
			var sp2 := _get_iso_pt(float(gp.x + fp.x + rad), float(gp.y + sy))
			draw_line(sp1, sp2, Color(0.35, 0.85, 1.0, 0.25), 1.0)
