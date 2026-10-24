# FarmHeatmapOverlay.gd
# Real-time Soil & Farm Diagnostic Heatmap & Irrigation Blueprint Overlay.
# Visualizes soil moisture, crop health, maturity readiness, pest blights, and sprinkler coverage
# across the entire 24x24 isometric farm grid.

class_name FarmHeatmapOverlay
extends Node2D

signal state_changed(active: bool)
signal mode_changed(new_mode: int)

enum HeatmapMode {
	UNIFIED,    # Tactical overview: moisture tint + harvest glow + pest beacons + sprinkler net
	MOISTURE,   # Pure soil hydration gradient (<35% dry, 35-50% low, 50-80% optimal, >80% wet)
	HEALTH,     # Crop vigor, maturity readiness, and blight stress
	IRRIGATION  # Sprinkler coverage blueprint & dry gap identification
}

var farm_grid: Node2D = null
var is_active: bool = false
var current_mode: int = HeatmapMode.UNIFIED

# Visual parameters
var alpha: float = 0.0
var _pulse_phase: float = 0.0
var _tween: Tween = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 195 # Renders right below DragSelectOverlay (z=200)
	z_as_relative = false
	visible = false
	if farm_grid == null and get_parent() is Node2D:
		farm_grid = get_parent()

func _process(delta: float) -> void:
	if not is_active and alpha <= 0.0:
		return
	_pulse_phase += delta * 3.5
	queue_redraw()

func _get_iso_pt(gx: float, gy: float) -> Vector2:
	return Vector2(
		FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W,
		FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
	)

func toggle() -> void:
	if is_active:
		deactivate()
	else:
		activate()

func activate() -> void:
	if is_active:
		return
	is_active = true
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "alpha", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	state_changed.emit(true)
	AudioManager.play_ui("tile_select")
	LogManager.log_event("general", "🗺️ Field Diagnostic Heatmap activated [F]. Mode: %s." % get_mode_name(), "🗺️", Color(0.35, 0.90, 1.0))

func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "alpha", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		if not is_active:
			visible = false
	)
	state_changed.emit(false)
	AudioManager.play_ui("pause")

func set_mode(mode: int) -> void:
	current_mode = clampi(mode, 0, 3)
	mode_changed.emit(current_mode)
	AudioManager.play_ui("click")
	queue_redraw()

func get_mode_name() -> String:
	match current_mode:
		HeatmapMode.UNIFIED: return "Tactical Overview"
		HeatmapMode.MOISTURE: return "Soil Moisture"
		HeatmapMode.HEALTH: return "Crop Health & Ripe Yield"
		HeatmapMode.IRRIGATION: return "Sprinkler Coverage Network"
		_: return "Heatmap"

func _draw() -> void:
	if farm_grid == null or alpha <= 0.0:
		return

	var pulse: float = 0.5 + 0.5 * sin(_pulse_phase)
	var fast_pulse: float = 0.5 + 0.5 * sin(_pulse_phase * 2.0)

	# 1. Tile diagnostic diamonds
	for x in range(farm_grid.GRID_SIZE.x):
		for y in range(farm_grid.GRID_SIZE.y):
			var p := Vector2i(x, y)
			if not farm_grid.is_tile_unlocked(p):
				continue

			var tile: FarmTile = farm_grid.tiles[x][y]
			var t_top: Vector2    = _get_iso_pt(float(x), float(y))
			var t_right: Vector2  = _get_iso_pt(float(x + 1), float(y))
			var t_bottom: Vector2 = _get_iso_pt(float(x + 1), float(y + 1))
			var t_left: Vector2   = _get_iso_pt(float(x), float(y + 1))
			var diamond := PackedVector2Array([t_top, t_right, t_bottom, t_left])

			match current_mode:
				HeatmapMode.UNIFIED:
					_draw_tile_unified(diamond, tile, p, pulse, fast_pulse)
				HeatmapMode.MOISTURE:
					_draw_tile_moisture(diamond, tile, p)
				HeatmapMode.HEALTH:
					_draw_tile_health(diamond, tile, p, pulse, fast_pulse)
				HeatmapMode.IRRIGATION:
					_draw_tile_irrigation(diamond, tile, p, pulse)

	# 2. Draw Sprinkler Blueprint Diamond Arcs (UNIFIED & IRRIGATION modes)
	if current_mode == HeatmapMode.UNIFIED or current_mode == HeatmapMode.IRRIGATION:
		_draw_sprinkler_blueprint_networks(pulse)

	# 3. Highlight hovered tile with diagnostic crosshair diamond
	var h_pos: Vector2i = farm_grid.hovered_grid_pos
	if h_pos != Vector2i(-1, -1) and farm_grid._is_valid(h_pos) and farm_grid.is_tile_unlocked(h_pos):
		var h_top: Vector2    = _get_iso_pt(float(h_pos.x), float(h_pos.y))
		var h_right: Vector2  = _get_iso_pt(float(h_pos.x + 1), float(h_pos.y))
		var h_bottom: Vector2 = _get_iso_pt(float(h_pos.x + 1), float(h_pos.y + 1))
		var h_left: Vector2   = _get_iso_pt(float(h_pos.x), float(h_pos.y + 1))
		var h_loop := PackedVector2Array([h_top, h_right, h_bottom, h_left, h_top])
		draw_polyline(h_loop, Color(1.0, 1.0, 1.0, 0.95 * alpha), 2.2)

## Unified Tactical Diagnostic: Combines moisture tint + harvest glow + pest beacons
func _draw_tile_unified(diamond: PackedVector2Array, tile: FarmTile, pos: Vector2i, pulse: float, fast_pulse: float) -> void:
	var fill_color := Color(0, 0, 0, 0)
	var border_color := Color(0, 0, 0, 0)
	var has_border: bool = false

	# Pest Blight / Infection Alert (Highest visual alert priority)
	if tile.state == FarmTile.TileState.INFECTED or not tile.pest_type.is_empty():
		fill_color = Color(0.85, 0.15, 0.55, (0.35 + 0.20 * fast_pulse) * alpha)
		border_color = Color(1.0, 0.20, 0.65, (0.80 + 0.20 * fast_pulse) * alpha)
		has_border = true
		draw_colored_polygon(diamond, fill_color)
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, border_color, 2.2)
		return

	# Harvestable Crop Ready to Harvest
	if tile.state == FarmTile.TileState.HARVESTABLE:
		fill_color = Color(1.0, 0.85, 0.20, (0.32 + 0.18 * pulse) * alpha)
		border_color = Color(1.0, 0.92, 0.35, (0.85 + 0.15 * pulse) * alpha)
		draw_colored_polygon(diamond, fill_color)
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, border_color, 2.0)
		return

	# Soil Moisture Diagnostic Tint
	var m: float = tile.soil_moisture
	if tile.state == FarmTile.TileState.FLOODED:
		fill_color = Color(0.10, 0.30, 0.85, 0.50 * alpha)
		border_color = Color(0.20, 0.55, 1.0, 0.80 * alpha)
		has_border = true
	elif m < 35.0:
		# Parched / Thirsty: Warning Orange/Red
		fill_color = Color(0.95, 0.40, 0.12, (0.36 + 0.12 * pulse) * alpha)
		border_color = Color(1.0, 0.50, 0.20, (0.70 + 0.20 * pulse) * alpha)
		has_border = true
	elif m < 50.0:
		# Low Moisture: Soft Sand Yellow
		fill_color = Color(0.92, 0.82, 0.30, 0.24 * alpha)
	elif m <= 80.0:
		# Optimal Hydration: Lush Cyan/Azure
		fill_color = Color(0.18, 0.75, 0.85, 0.25 * alpha)
	else:
		# Saturated: Deep Blue
		fill_color = Color(0.12, 0.45, 0.95, 0.35 * alpha)

	draw_colored_polygon(diamond, fill_color)
	if has_border:
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, border_color, 1.6)

## Pure Soil Hydration Gradient View
func _draw_tile_moisture(diamond: PackedVector2Array, tile: FarmTile, _pos: Vector2i) -> void:
	var m: float = tile.soil_moisture
	var fill_color := Color(0, 0, 0, 0)
	var border_color := Color(0, 0, 0, 0)
	var draw_border: bool = false

	if tile.state == FarmTile.TileState.FLOODED:
		fill_color = Color(0.10, 0.25, 0.90, 0.55 * alpha)
		border_color = Color(0.4, 0.7, 1.0, 0.9 * alpha)
		draw_border = true
	elif m < 30.0:
		fill_color = Color(0.95, 0.25, 0.15, 0.42 * alpha)
		border_color = Color(1.0, 0.4, 0.25, 0.85 * alpha)
		draw_border = true
	elif m < 50.0:
		fill_color = Color(0.95, 0.85, 0.25, 0.32 * alpha)
	elif m <= 80.0:
		fill_color = Color(0.20, 0.78, 0.88, 0.35 * alpha)
	else:
		fill_color = Color(0.12, 0.42, 0.95, 0.45 * alpha)

	draw_colored_polygon(diamond, fill_color)
	if draw_border:
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, border_color, 1.6)

## Crop Health & Growth Readiness View
func _draw_tile_health(diamond: PackedVector2Array, tile: FarmTile, _pos: Vector2i, pulse: float, fast_pulse: float) -> void:
	if tile.crop_type.is_empty():
		# Empty / unplanted tile: subtle neutral gray tint
		draw_colored_polygon(diamond, Color(0.15, 0.12, 0.08, 0.15 * alpha))
		return

	if tile.state == FarmTile.TileState.INFECTED or not tile.pest_type.is_empty():
		var col := Color(0.95, 0.15, 0.60, (0.45 + 0.25 * fast_pulse) * alpha)
		draw_colored_polygon(diamond, col)
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, Color(1.0, 0.30, 0.70, (0.85 + 0.15 * fast_pulse) * alpha), 2.2)
		return

	if tile.state == FarmTile.TileState.HARVESTABLE:
		var col := Color(1.0, 0.85, 0.25, (0.40 + 0.20 * pulse) * alpha)
		draw_colored_polygon(diamond, col)
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, Color(1.0, 0.95, 0.40, (0.85 + 0.15 * pulse) * alpha), 2.2)
		return

	# Growing crop: color coded by health (0.0 to 1.0)
	var h: float = tile.health
	var col := Color(0.35, 0.88, 0.40, 0.35 * alpha)
	if h < 0.35:
		col = Color(0.90, 0.25, 0.20, 0.45 * alpha)
	elif h < 0.70:
		col = Color(0.95, 0.75, 0.25, 0.35 * alpha)

	draw_colored_polygon(diamond, col)

## Sprinkler Coverage Blueprint View
func _draw_tile_irrigation(diamond: PackedVector2Array, _tile: FarmTile, pos: Vector2i, pulse: float) -> void:
	var covered: bool = BuildingManager.is_tile_covered_by_sprinkler(pos)
	if covered:
		var col := Color(0.20, 0.75, 1.0, (0.35 + 0.10 * pulse) * alpha)
		draw_colored_polygon(diamond, col)
		var loop := PackedVector2Array(diamond)
		loop.append(diamond[0])
		draw_polyline(loop, Color(0.40, 0.85, 1.0, 0.75 * alpha), 1.4)
	else:
		# Uncovered plot: subtle warning amber tint
		draw_colored_polygon(diamond, Color(0.35, 0.25, 0.15, 0.18 * alpha))

## Draws glowing cyan diamond fields for each active sprinkler's operational radius
func _draw_sprinkler_blueprint_networks(pulse: float) -> void:
	var rad: int = BuildingManager.get_sprinkler_radius()
	var sprinklers: Array = BuildingManager.get_all_sprinklers()

	for s in sprinklers:
		if not is_instance_valid(s):
			continue
		var gp: Vector2i = s.grid_pos
		var min_x: float = float(gp.x - rad)
		var max_x: float = float(gp.x + rad + 1)
		var min_y: float = float(gp.y - rad)
		var max_y: float = float(gp.y + rad + 1)

		var top_pt: Vector2    = _get_iso_pt(min_x, min_y)
		var right_pt: Vector2  = _get_iso_pt(max_x, min_y)
		var bottom_pt: Vector2 = _get_iso_pt(max_x, max_y)
		var left_pt: Vector2   = _get_iso_pt(min_x, max_y)

		var poly := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt])
		var border := PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt, top_pt])

		# Sprinkler water arc zone
		draw_colored_polygon(poly, Color(0.18, 0.70, 1.0, (0.08 + 0.04 * pulse) * alpha))
		draw_polyline(border, Color(0.35, 0.85, 1.0, (0.65 + 0.25 * pulse) * alpha), 2.2)

		# Center sprinkler origin marker
		var s_center: Vector2 = _get_iso_pt(float(gp.x) + 0.5, float(gp.y) + 0.5)
		draw_circle(s_center, 4.0, Color(1.0, 1.0, 1.0, 0.90 * alpha))
		draw_circle(s_center, 6.5, Color(0.20, 0.80, 1.0, (0.60 + 0.30 * pulse) * alpha))

## Returns detailed diagnostic telemetry for any grid coordinate
func get_tile_diagnostic_info(pos: Vector2i) -> Dictionary:
	if farm_grid == null or not farm_grid._is_valid(pos):
		return {}
	var t: FarmTile = farm_grid.tiles[pos.x][pos.y]
	var is_covered: bool = BuildingManager.is_tile_covered_by_sprinkler(pos)

	var crop_name: String = "Empty Plot"
	if not t.crop_type.is_empty():
		crop_name = Data.get_crop(t.crop_type).get("display_name", t.crop_type.capitalize())

	var status_str: String = "Normal"
	if t.state == FarmTile.TileState.HARVESTABLE:
		status_str = "⭐ Ready for Harvest"
	elif t.state == FarmTile.TileState.INFECTED or not t.pest_type.is_empty():
		status_str = "⚠️ Infested (%s)" % (t.pest_type.capitalize() if not t.pest_type.is_empty() else "Blight")
	elif t.state == FarmTile.TileState.FLOODED:
		status_str = "🌊 Flooded"
	elif t.soil_moisture < 35.0:
		status_str = "🏜️ Parched (Needs Water)"
	elif t.soil_moisture <= 80.0:
		status_str = "💧 Optimal Moisture"

	return {
		"pos": pos,
		"crop": crop_name,
		"moisture": t.soil_moisture,
		"health": t.health * 100.0,
		"growth": t.growth_progress * 100.0,
		"sprinkler": is_covered,
		"status": status_str,
		"state": t.state
	}
