# Building.gd
# Placed interactive farm infrastructure building (Clash of Clans / Warcraft RTS style).
# Occupies a multi-tile footprint on the FarmGrid.
# Features:
#   - Construction timer & scaffold visuals
#   - Upgrade system (Level 1 -> 2 -> 3)
#   - Detailed procedural visuals per building type
#   - Real-time overhead construction progress bar

class_name Building
extends Node2D

signal state_changed(building: Node)
signal clicked(building: Node)
signal demolished(building: Node)

enum BuildingState { CONSTRUCTING, ACTIVE, UPGRADING }

# ---------------------------------------------------------------------------
# State & Metadata
# ---------------------------------------------------------------------------
var building_type: String = "bahay_kubo"
var grid_pos: Vector2i    = Vector2i.ZERO
var footprint: Vector2i   = Vector2i(2, 2)
var level: int            = 1
var max_level: int        = 3
var state: int            = BuildingState.CONSTRUCTING

var progress_timer: float = 0.0
var duration: float       = 15.0

# UI nodes
var progress_bar: ProgressBar = null
var progress_label: Label     = null
var level_label: Label        = null

const TEX_KUBO: Texture2D            = preload("res://assets/sprites/buildings/KUBO.png")
const TEX_DRYER: Texture2D           = preload("res://assets/sprites/buildings/DRYER-BARE.PNG")
const TEX_COLD_STORAGE: Texture2D    = preload("res://assets/sprites/buildings/Cold Storage.png")
const TEX_DRONE_STATION: Texture2D   = preload("res://assets/sprites/buildings/Drone Station.png")
const TEX_WATER_STATION: Texture2D   = preload("res://assets/sprites/buildings/Water Station.png")
const TEX_WEATHER_STATION: Texture2D = preload("res://assets/sprites/buildings/Weather Station.png")

const TEX_SILO_0: Texture2D          = preload("res://assets/sprites/buildings/Silo/SILO-0.PNG")
const TEX_SILO_25: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-25.PNG")
const TEX_SILO_50: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-50.PNG")
const TEX_SILO_75: Texture2D         = preload("res://assets/sprites/buildings/Silo/SILO-75.PNG")
const TEX_SILO_100: Texture2D        = preload("res://assets/sprites/buildings/Silo/SILO-100.PNG")

func _get_silo_texture() -> Texture2D:
	var ratio: float = 0.0
	if BuildingManager.total_storage_capacity > 0:
		ratio = clampf(float(BuildingManager.used_storage) / float(BuildingManager.total_storage_capacity), 0.0, 1.0)
	if ratio < 0.125:
		return TEX_SILO_0
	elif ratio < 0.375:
		return TEX_SILO_25
	elif ratio < 0.625:
		return TEX_SILO_50
	elif ratio < 0.875:
		return TEX_SILO_75
	else:
		return TEX_SILO_100

func _ready() -> void:
	z_index = 10  # Match standing object layer (trees, crops in tile_roots) for seamless 2.5D Y-sorting
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var b_data: Dictionary = Data.get_building(building_type)
	if not b_data.is_empty():
		footprint = b_data.get("grid_size", Vector2i(2, 2))
		max_level = int(b_data.get("max_level", 3))

	# Compute center of the isometric footprint
	var pts := FarmerMovement.get_footprint_polygon_local(grid_pos, footprint)
	var center := (pts[0] + pts[2]) * 0.5
	position = center

	_setup_ui()
	TimeManager.period_changed.connect(func(_p, _n): queue_redraw())
	TimeManager.hour_changed.connect(func(_h): queue_redraw())
	if BuildingManager.has_signal("storage_updated"):
		BuildingManager.storage_updated.connect(func(_t, _u): queue_redraw())
	queue_redraw()

func _get_footprint_diamond_pts() -> Array[Vector2]:
	var pts := FarmerMovement.get_footprint_polygon_local(grid_pos, footprint)
	var center := (pts[0] + pts[2]) * 0.5
	return [pts[0] - center, pts[1] - center, pts[2] - center, pts[3] - center]

func _setup_ui() -> void:
	var d_pts := _get_footprint_diamond_pts()
	var roof_apex_y: float = -92.0
	if building_type == "bodega":
		roof_apex_y = -96.0
	elif building_type == "drone_station":
		roof_apex_y = -210.0
	elif building_type == "weather_station":
		roof_apex_y = -198.0
	elif building_type == "water_tower":
		roof_apex_y = -240.0
	elif building_type == "machine_garage":
		roof_apex_y = -65.0
	elif building_type == "cold_storage":
		roof_apex_y = -98.0
	elif building_type == "climate_silo":
		roof_apex_y = -120.0
	elif building_type == "sprinkler":
		roof_apex_y = -28.0

	# Level indicator badge centered above building roof
	level_label = Label.new()
	level_label.position = Vector2(-50, roof_apex_y - 20)
	level_label.size = Vector2(100, 20)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	add_child(level_label)

	# Overhead Construction/Upgrade Progress Bar
	var pbox := VBoxContainer.new()
	pbox.name = "ProgressBox"
	pbox.position = Vector2(-75, roof_apex_y - 48)
	pbox.custom_minimum_size = Vector2(150, 24)
	pbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pbox)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	pbox.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(150, 8)
	progress_bar.max_value = 100.0
	progress_bar.show_percentage = false
	pbox.add_child(progress_bar)

	_update_ui_state()

func _process(delta: float) -> void:
	if building_type in ["drone_station", "weather_station", "water_tower", "machine_garage", "sprinkler"] and state == BuildingState.ACTIVE:
		queue_redraw()

	var speed_scale: float = TimeManager.get_speed_scale()
	if speed_scale <= 0.0:
		return

	var dt: float = delta * speed_scale

	if state == BuildingState.CONSTRUCTING:
		progress_timer += dt
		_update_progress_display("🔨 Building...")
		if progress_timer >= duration:
			complete_construction()

	elif state == BuildingState.UPGRADING:
		progress_timer += dt
		_update_progress_display("⬆️ Upgrading...")
		if progress_timer >= duration:
			complete_upgrade()

func _update_progress_display(prefix: String) -> void:
	if progress_bar and progress_label:
		var pct: float = clampf((progress_timer / max(0.1, duration)) * 100.0, 0.0, 100.0)
		progress_bar.value = pct
		var remain: int = int(ceil(max(0.0, duration - progress_timer)))
		progress_label.text = "%s %ds (%.0f%%)" % [prefix, remain, pct]

func _update_ui_state() -> void:
	var stars: String = ""
	for i in range(level):
		stars += "⭐"
	if level_label:
		level_label.text = "%s Lv.%d" % [stars, level]
		level_label.visible = (state == BuildingState.ACTIVE)

	var pbox = get_node_or_null("ProgressBox")
	if pbox:
		pbox.visible = (state != BuildingState.ACTIVE)

	queue_redraw()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func complete_construction() -> void:
	state          = BuildingState.ACTIVE
	progress_timer = 0.0
	_update_ui_state()
	BuildingManager.recalculate_bonuses()
	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Construction finished: %s (Lv. 1) at (%d, %d)." % [b_name, grid_pos.x, grid_pos.y], "🏛️", Color(0.35, 0.8, 1.0, 1.0))
	state_changed.emit(self)
	AudioManager.play_building("complete")
	AudioManager.unregister_active_construction()

func start_upgrade(up_cost: int, up_duration: float) -> bool:
	if state != BuildingState.ACTIVE or level >= max_level:
		return false
	if not EconomyManager.deduct_cash(up_cost):
		return false

	state          = BuildingState.UPGRADING
	duration       = up_duration
	progress_timer = 0.0
	_update_ui_state()
	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Started upgrade on %s to Lv. %d (₱%d)." % [b_name, level + 1, up_cost], "⬆️", Color(0.7, 0.85, 1.0, 1.0))
	state_changed.emit(self)
	AudioManager.register_active_construction()
	return true

func complete_upgrade() -> void:
	level          += 1
	state          = BuildingState.ACTIVE
	progress_timer = 0.0
	_update_ui_state()
	BuildingManager.recalculate_bonuses()
	var b_data := Data.get_building(building_type)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("buildings", "Upgrade completed: %s upgraded to Lv. %d at (%d, %d)." % [b_name, level, grid_pos.x, grid_pos.y], "⭐", Color(1.0, 0.85, 0.3, 1.0))
	state_changed.emit(self)
	AudioManager.play_building("complete")
	AudioManager.unregister_active_construction()

func demolish() -> void:
	if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
		AudioManager.unregister_active_construction()
	var b_data := Data.get_building(building_type)
	var base_cost: int = int(b_data.get("cost", 200))
	var refund: int = int(base_cost * 0.5 * level)
	EconomyManager.add_cash(refund)
	var b_name: String = str(b_data.get("name", building_type.capitalize()))
	LogManager.log_event("demolish", "Demolished %s (Lv. %d) for +₱%d refund." % [b_name, level, refund], "💥", Color(0.9, 0.4, 0.3, 1.0))
	demolished.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Rendering: Procedural 2.5D Isometric RTS / Clash of Clans Architecture
# ---------------------------------------------------------------------------
func _draw() -> void:
	var d_pts := _get_footprint_diamond_pts()
	var top    := d_pts[0]
	var right  := d_pts[1]
	var bottom := d_pts[2]
	var left   := d_pts[3]

	# 1. Foundation Platform (Isometric Base Slab)
	# Only drawn for heavy industrial facilities without built-in pixel-art bases; Bahay Kubo, Silo, Bilaran dryer, Cold Storage, Drone Station, Water Tower, and Weather Station have authentic pixel-art terrain bases!
	if building_type != "bodega" and building_type != "bahay_kubo" and building_type != "solar_dryer" and building_type != "drone_station" and building_type != "water_tower" and building_type != "sprinkler" and building_type != "cold_storage" and building_type != "weather_station":
		draw_colored_polygon(PackedVector2Array(d_pts), Color(0.25, 0.21, 0.17, 0.95))
		var slab_depth: float = 8.0
		draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0, slab_depth), left + Vector2(0, slab_depth)]), Color(0.18, 0.14, 0.10, 0.95))
		draw_colored_polygon(PackedVector2Array([bottom, right, right + Vector2(0, slab_depth), bottom + Vector2(0, slab_depth)]), Color(0.22, 0.18, 0.13, 0.95))
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.12, 0.10, 0.08, 1.0), 2.0)

	# 2. Draw 2.5D building-specific artwork
	match building_type:
		"bahay_kubo":
			_draw_bahay_kubo(top, right, bottom, left)
		"bodega":
			_draw_bodega(top, right, bottom, left)
		"cold_storage":
			_draw_cold_storage(top, right, bottom, left)
		"solar_dryer":
			_draw_solar_dryer(top, right, bottom, left)
		"machine_garage":
			_draw_garage(top, right, bottom, left)
		"climate_silo":
			_draw_silo(top, right, bottom, left)
		"drone_station":
			_draw_drone_station(top, right, bottom, left)
		"weather_station":
			_draw_weather_station(top, right, bottom, left)
		"water_tower":
			_draw_water_tower(top, right, bottom, left)
		"sprinkler":
			_draw_sprinkler(top, right, bottom, left)
		_:
			_draw_default_building(top, right, bottom, left)

	# 3. Construction Scaffold Overlay (if constructing or upgrading)
	if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
		_draw_scaffold_overlay(top, right, bottom, left)

func _draw_bahay_kubo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_KUBO != null:
		# Soft natural ground shadow on the soil under the stilt hut
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 46.0, sin(rad) * 23.0 + 6.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.30))

		# Darker contact shadows under the 4 stilt footings and ladder on the soil
		draw_circle(Vector2(-1.0, 26.0), 5.5, Color(0.05, 0.08, 0.03, 0.50))   # Front center stilt
		draw_circle(Vector2(-46.0, 14.0), 4.5, Color(0.05, 0.08, 0.03, 0.45))  # Ladder base
		draw_circle(Vector2(-58.0, 10.0), 5.0, Color(0.05, 0.08, 0.03, 0.45))  # Left stilt
		draw_circle(Vector2(48.0, 4.0), 5.0, Color(0.05, 0.08, 0.03, 0.45))   # Right stilt
		draw_circle(Vector2(-2.0, -14.0), 5.0, Color(0.05, 0.08, 0.03, 0.40))  # Back stilt

		# Pixel-art Bahay Kubo sprite (64x96 at 2x scale = 128x192)
		var kubo_w: float = float(TEX_KUBO.get_width()) * 2.0
		var kubo_h: float = float(TEX_KUBO.get_height()) * 2.0
		var kubo_rect := Rect2(-kubo_w * 0.5, -156.0, kubo_w, kubo_h)
		draw_texture_rect(TEX_KUBO, kubo_rect, false)

		# Warm nighttime Capiz window & gasera porch lantern glow
		if TimeManager.is_night():
			var win_pos := Vector2(-12.0, -82.0)
			draw_circle(win_pos, 16.0, Color(1.0, 0.85, 0.35, 0.25))
			draw_circle(win_pos, 8.0, Color(1.0, 0.92, 0.45, 0.45))
			var porch_pos := Vector2(0.0, -60.0)
			draw_circle(porch_pos, 14.0, Color(1.0, 0.80, 0.25, 0.20))
			draw_circle(porch_pos, 6.0, Color(1.0, 0.95, 0.50, 0.45))
			draw_circle(porch_pos, 2.5, Color(1.0, 0.98, 0.80, 0.95))

		# Level upgrade indicators
		if level >= 2:
			draw_circle(Vector2(20.0, -58.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-20.0, -58.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var stilt_h: float = 24.0
	var wall_h: float  = 30.0

	# Bamboo stilts
	var stilt_col := Color(0.48, 0.34, 0.18)
	var pts_base := [top * 0.7, right * 0.7, bottom * 0.7, left * 0.7]
	for p in pts_base:
		draw_line(p, p + Vector2(0, -stilt_h), stilt_col, 4.0)

	# Woven sawali bamboo walls
	var floor_top    := top * 0.7 + Vector2(0, -stilt_h)
	var floor_right  := right * 0.7 + Vector2(0, -stilt_h)
	var floor_bottom := bottom * 0.7 + Vector2(0, -stilt_h)
	var floor_left   := left * 0.7 + Vector2(0, -stilt_h)

	var wall_left_pts := PackedVector2Array([
		floor_left, floor_bottom, floor_bottom + Vector2(0, -wall_h), floor_left + Vector2(0, -wall_h)
	])
	draw_colored_polygon(wall_left_pts, Color(0.72, 0.58, 0.32))
	draw_polyline(wall_left_pts, Color(0.40, 0.28, 0.12), 1.5)

	var wall_right_pts := PackedVector2Array([
		floor_bottom, floor_right, floor_right + Vector2(0, -wall_h), floor_bottom + Vector2(0, -wall_h)
	])
	draw_colored_polygon(wall_right_pts, Color(0.60, 0.48, 0.24))
	draw_polyline(wall_right_pts, Color(0.35, 0.24, 0.10), 1.5)

	# Thatched Nipa Palm Roof (3D Gable Pitch)
	var roof_apex := Vector2(0, -stilt_h - wall_h - 32.0)
	var eave_left := floor_left + Vector2(-8, -wall_h + 4)
	var eave_right := floor_right + Vector2(8, -wall_h + 4)
	var eave_front := floor_bottom + Vector2(0, -wall_h + 8)

	var roof_front_left := PackedVector2Array([roof_apex, eave_front, eave_left])
	draw_colored_polygon(roof_front_left, Color(0.85, 0.70, 0.30))
	draw_polyline(roof_front_left, Color(0.48, 0.36, 0.12), 2.0)

	var roof_front_right := PackedVector2Array([roof_apex, eave_right, eave_front])
	draw_colored_polygon(roof_front_right, Color(0.74, 0.58, 0.22))
	draw_polyline(roof_front_right, Color(0.42, 0.30, 0.10), 2.0)

	# Capiz-shell window on front-left woven bamboo wall
	var win_center: Vector2 = (floor_left + floor_bottom) * 0.5 + Vector2(0, -wall_h * 0.5)
	var win_w: float = 12.0
	var win_h: float = 10.0
	var win_rect := Rect2(win_center.x - win_w * 0.5, win_center.y - win_h * 0.5, win_w, win_h)
	var is_night: bool = TimeManager.is_night()

	if is_night:
		# Warm glowing window lamplight in the dark
		draw_circle(win_center, 18.0, Color(1.0, 0.80, 0.25, 0.22))
		draw_circle(win_center, 10.0, Color(1.0, 0.90, 0.40, 0.45))
		draw_rect(win_rect, Color(1.0, 0.92, 0.45, 0.95))
		draw_rect(win_rect, Color(0.45, 0.30, 0.12, 1.0), false, 1.5)
		draw_line(Vector2(win_rect.position.x + win_w * 0.5, win_rect.position.y), Vector2(win_rect.position.x + win_w * 0.5, win_rect.end.y), Color(0.45, 0.30, 0.12), 1.0)
		draw_line(Vector2(win_rect.position.x, win_rect.position.y + win_h * 0.5), Vector2(win_rect.end.x, win_rect.position.y + win_h * 0.5), Color(0.45, 0.30, 0.12), 1.0)
	else:
		# Translucent natural Capiz oyster shell window
		draw_rect(win_rect, Color(0.88, 0.85, 0.76, 0.92))
		draw_rect(win_rect, Color(0.40, 0.28, 0.12, 1.0), false, 1.2)
		draw_line(Vector2(win_rect.position.x + win_w * 0.5, win_rect.position.y), Vector2(win_rect.position.x + win_w * 0.5, win_rect.end.y), Color(0.40, 0.28, 0.12), 1.0)
		draw_line(Vector2(win_rect.position.x, win_rect.position.y + win_h * 0.5), Vector2(win_rect.end.x, win_rect.position.y + win_h * 0.5), Color(0.40, 0.28, 0.12), 1.0)

	# Porch hanging gasera lantern on front eave
	var lantern_pos := eave_front + Vector2(0, 4)
	if is_night:
		draw_circle(lantern_pos, 14.0, Color(1.0, 0.80, 0.25, 0.20))
		draw_circle(lantern_pos, 6.0, Color(1.0, 0.92, 0.50, 0.40))
		draw_circle(lantern_pos, 2.5, Color(1.0, 0.98, 0.75, 0.95))
		draw_rect(Rect2(lantern_pos.x - 2, lantern_pos.y - 1, 4, 4), Color(0.30, 0.22, 0.12, 0.90))
		draw_line(lantern_pos + Vector2(0, -5), lantern_pos + Vector2(0, -1), Color(0.4, 0.3, 0.2), 1.0)

	# Thatch straw texture lines
	draw_line(roof_apex, (eave_left + eave_front) * 0.5, Color(0.60, 0.46, 0.16), 1.5)
	draw_line(roof_apex, (eave_right + eave_front) * 0.5, Color(0.55, 0.40, 0.14), 1.5)

func _draw_bodega(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var tex := _get_silo_texture()
	if tex != null:
		# Soft ground shadow under Silo base
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 38.0, sin(rad) * 19.0 + 8.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.30))

		# Pixel-art Silo sprite (48x64 at 2x scale = 96x128)
		var silo_w: float = float(tex.get_width()) * 2.0
		var silo_h: float = float(tex.get_height()) * 2.0
		var silo_rect := Rect2(-silo_w * 0.5, -94.0, silo_w, silo_h)
		draw_texture_rect(tex, silo_rect, false)

		# Night work light on intake / base
		if TimeManager.is_night():
			var lamp_p := Vector2(0.0, -50.0)
			draw_circle(lamp_p, 14.0, Color(1.0, 0.80, 0.30, 0.22))
			draw_circle(lamp_p, 5.0, Color(1.0, 0.90, 0.50, 0.50))
			draw_circle(lamp_p, 1.5, Color(1.0, 0.98, 0.80, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(18.0, -82.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-18.0, -82.0), 2.5, Color(0.95, 0.85, 0.3, 0.9))
		return

	# 1. Compact Agricultural Gravel Pad & Concrete Curbing (2x2 Footprint)
	var pad_scale: float = 0.90
	var p_top: Vector2    = top * pad_scale
	var p_right: Vector2  = right * pad_scale
	var p_bottom: Vector2 = bottom * pad_scale
	var p_left: Vector2   = left * pad_scale

	# Low-profile concrete foundation edge curb (3.0px drop)
	var curb_h: float = 3.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.38, 0.36, 0.32))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.46, 0.44, 0.39))

	# Clean compacted gravel / crushed limestone yard
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.72, 0.70, 0.65))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.46, 0.43, 0.38), 1.5)

	# Equipment & grain cart wheel tracks
	var track_col := Color(0.58, 0.55, 0.49, 0.45)
	draw_line(p_bottom * 0.72 + Vector2(-8, 0), (p_bottom + p_right) * 0.36, track_col, 1.2)
	draw_line(p_bottom * 0.72 + Vector2(6, 0), (p_bottom + p_right) * 0.36 + Vector2(5, 2), track_col, 1.2)

	# 2. Compact Grain Bins in a neat straight row along the isometric axis (2x2 layout)
	# Silo height is low-profile (14-15px cylinder + 7-7.5px cone = ~21-22px total height)
	match level:
		1:
			# Level 1: 2 small cone bins side-by-side
			_draw_single_grain_silo(-13.0, -6.5, 12.0, 15.0, 7.5, true, true)
			_draw_single_grain_silo(11.0, 5.5, 12.0, 15.0, 7.5, true, true)
			_draw_grain_auger(Vector2(11.0, 5.5 - 15.0 - 7.5), Vector2(28.0, 14.0))

		2:
			# Level 2: 3 small cone bins in a neat row + catwalk
			_draw_single_grain_silo(-20.0, -10.0, 10.5, 15.0, 7.5, true, true)
			_draw_single_grain_silo(0.0, 0.0, 10.5, 15.0, 7.5, true, true)
			_draw_single_grain_silo(20.0, 10.0, 10.5, 15.0, 7.5, true, true)

			# Small roof catwalk
			var p1 := Vector2(-20.0, -10.0 - 15.0 - 4.0)
			var p2 := Vector2(20.0, 10.0 - 15.0 - 4.0)
			draw_line(p1, p2, Color(0.35, 0.38, 0.44), 2.0)
			draw_line(p1 + Vector2(0, -3), p2 + Vector2(0, -3), Color(0.48, 0.52, 0.58), 1.0)

			_draw_grain_auger(Vector2(20.0, 10.0 - 15.0 - 7.5), Vector2(36.0, 18.0))

		_:
			# Level 3: 4 small cone bins in a neat straight row
			_draw_single_grain_silo(-27.0, -13.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(-9.0, -4.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(9.0, 4.5, 9.5, 14.0, 7.0, true, true)
			_draw_single_grain_silo(27.0, 13.5, 9.5, 14.0, 7.0, true, true)

			# Catwalk connecting all 4 bins
			var p1 := Vector2(-27.0, -13.5 - 14.0 - 4.0)
			var p2 := Vector2(27.0, 13.5 - 14.0 - 4.0)
			draw_line(p1, p2, Color(0.35, 0.38, 0.44), 2.0)
			draw_line(p1 + Vector2(0, -3), p2 + Vector2(0, -3), Color(0.48, 0.52, 0.58), 1.0)

			_draw_grain_auger(Vector2(27.0, 13.5 - 14.0 - 7.0), Vector2(42.0, 21.0))

func _draw_single_grain_silo(cx: float, cy: float, rx: float = 16.0, height: float = 18.0, cone_h: float = 9.0, has_ladder: bool = true, has_spout: bool = true) -> void:
	var ry: float = rx * 0.5  # 2:1 isometric vertical foreshortening

	# 1. Base Concrete Foundation Ring
	var base_ring: PackedVector2Array = []
	for a in range(12):
		var th: float = float(a) / 12.0 * TAU
		base_ring.append(Vector2(cx + (rx + 2.0) * cos(th), cy + (ry + 1.0) * sin(th)))
	draw_colored_polygon(base_ring, Color(0.50, 0.48, 0.44))
	draw_polyline(base_ring, Color(0.32, 0.30, 0.28), 1.0)

	# 2. Corrugated Galvanized Steel Cylinder Body
	const NUM_SEGS: int = 6
	var rim_pts: PackedVector2Array = []

	for i in range(NUM_SEGS):
		var a1: float = PI * (float(i) / float(NUM_SEGS))
		var a2: float = PI * (float(i + 1) / float(NUM_SEGS))
		var x1: float = cx - rx * cos(a1)
		var y1: float = cy + ry * sin(a1)
		var x2: float = cx - rx * cos(a2)
		var y2: float = cy + ry * sin(a2)

		if i == 0:
			rim_pts.append(Vector2(x1, y1 - height))
		rim_pts.append(Vector2(x2, y2 - height))

		# Panel shading: light comes from top-right in RTS isometric
		var t: float = float(i) / float(NUM_SEGS - 1)
		var panel_col: Color = Color(0.56, 0.60, 0.65).lerp(Color(0.88, 0.91, 0.95), t)

		var quad := PackedVector2Array([
			Vector2(x1, y1),
			Vector2(x2, y2),
			Vector2(x2, y2 - height),
			Vector2(x1, y1 - height)
		])
		draw_colored_polygon(quad, panel_col)

		# Vertical panel seam
		draw_line(Vector2(x1, y1), Vector2(x1, y1 - height), Color(0.38, 0.42, 0.48, 0.5), 1.0)
		if i == NUM_SEGS - 1:
			draw_line(Vector2(x2, y2), Vector2(x2, y2 - height), Color(0.38, 0.42, 0.48, 0.5), 1.0)

	# Horizontal Corrugation Ring Lines across the cylinder
	for frac in [0.35, 0.70]:
		var ridge_pts: PackedVector2Array = []
		for k in range(NUM_SEGS + 1):
			var ak: float = PI * (float(k) / float(NUM_SEGS))
			ridge_pts.append(Vector2(cx - rx * cos(ak), cy + ry * sin(ak) - height * frac))
		draw_polyline(ridge_pts, Color(0.40, 0.44, 0.50, 0.45), 1.0)

	# 3. Conical Roof ("Cone Thing")
	var apex := Vector2(cx, cy - height - cone_h)

	for i in range(NUM_SEGS):
		var a1: float = PI * (float(i) / float(NUM_SEGS))
		var a2: float = PI * (float(i + 1) / float(NUM_SEGS))
		var x1: float = cx - rx * cos(a1)
		var y1: float = cy + ry * sin(a1)
		var x2: float = cx - rx * cos(a2)
		var y2: float = cy + ry * sin(a2)

		var t: float = float(i) / float(NUM_SEGS - 1)
		var cone_col: Color = Color(0.62, 0.66, 0.72).lerp(Color(0.92, 0.94, 0.97), t)

		var tri := PackedVector2Array([
			apex,
			Vector2(x1, y1 - height),
			Vector2(x2, y2 - height)
		])
		draw_colored_polygon(tri, cone_col)

		# Radiating roof seam ribs
		draw_line(apex, Vector2(x1, y1 - height), Color(0.42, 0.46, 0.52, 0.6), 1.0)
		if i == NUM_SEGS - 1:
			draw_line(apex, Vector2(x2, y2 - height), Color(0.42, 0.46, 0.52, 0.6), 1.0)

	# Crisp roof eave rim
	draw_polyline(rim_pts, Color(0.32, 0.35, 0.40), 1.2)

	# Silo Apex Cap & Vent
	draw_circle(apex, 3.0, Color(0.38, 0.42, 0.48))
	draw_circle(apex + Vector2(1, -1), 1.2, Color(0.95, 0.96, 0.98))

	# 4. Access Inspection Ladder (Front-Left Face)
	if has_ladder:
		var lx: float = cx - rx * cos(PI * 0.28)
		var ly: float = cy + ry * sin(PI * 0.28)
		draw_line(Vector2(lx - 2.0, ly), Vector2(lx - 2.0, ly - height), Color(0.28, 0.30, 0.35), 1.0)
		draw_line(Vector2(lx + 2.0, ly), Vector2(lx + 2.0, ly - height), Color(0.28, 0.30, 0.35), 1.0)
		for y_step in range(3, int(height), 4):
			draw_line(Vector2(lx - 2.0, ly - float(y_step)), Vector2(lx + 2.0, ly - float(y_step)), Color(0.22, 0.24, 0.28), 1.0)
		draw_line(Vector2(lx, ly - height), Vector2(lx, ly - height - 5), Color(0.28, 0.30, 0.35), 1.0)

	# 5. Base Discharge Chute & Gate
	if has_spout:
		var spout_rect := Rect2(cx - 3.5, cy + ry - 5.0, 7.0, 5.0)
		draw_rect(spout_rect, Color(0.30, 0.33, 0.38), true)
		draw_rect(spout_rect, Color(0.18, 0.20, 0.24), false, 1.0)
		draw_circle(Vector2(cx, cy + ry - 2.5), 1.5, Color(0.85, 0.25, 0.20))

func _draw_grain_auger(apex_target: Vector2, ground_source: Vector2) -> void:
	var hx := ground_source.x
	var hy := ground_source.y

	# Transport wheels
	draw_circle(Vector2(hx - 6, hy + 2), 3.0, Color(0.18, 0.18, 0.20))
	draw_circle(Vector2(hx - 6, hy + 2), 1.2, Color(0.70, 0.70, 0.70))
	draw_circle(Vector2(hx + 6, hy + 2), 3.0, Color(0.18, 0.18, 0.20))
	draw_circle(Vector2(hx + 6, hy + 2), 1.2, Color(0.70, 0.70, 0.70))
	draw_line(Vector2(hx - 6, hy + 2), Vector2(hx + 6, hy + 2), Color(0.35, 0.35, 0.38), 1.5)

	# Red intake hopper bin
	var hopper_poly := PackedVector2Array([
		Vector2(hx - 6, hy + 1),
		Vector2(hx + 6, hy + 1),
		Vector2(hx + 8, hy - 6),
		Vector2(hx - 8, hy - 6)
	])
	draw_colored_polygon(hopper_poly, Color(0.85, 0.22, 0.18))
	draw_polyline(hopper_poly, Color(0.50, 0.12, 0.10), 1.0)

	# Scissor Lift A-Frame Support Truss (Farm Red)
	var mid_pipe: Vector2 = ground_source.lerp(apex_target, 0.48)
	draw_line(mid_pipe, Vector2(hx - 4, hy + 1), Color(0.78, 0.20, 0.15), 1.5)
	draw_line(mid_pipe, Vector2(hx + 4, hy + 1), Color(0.78, 0.20, 0.15), 1.5)

	# Compact Yellow Grain Auger Tube
	var intake_p := Vector2(hx, hy - 3)
	var discharge_p := apex_target + Vector2(2, 2)

	draw_line(intake_p, discharge_p, Color(0.28, 0.22, 0.05), 4.0)
	draw_line(intake_p, discharge_p, Color(0.95, 0.76, 0.12), 2.5)
	draw_line(intake_p + Vector2(0, -1), discharge_p + Vector2(0, -1), Color(1.0, 0.92, 0.45), 1.0)

	# Discharge head spout collar
	draw_circle(discharge_p, 3.0, Color(0.25, 0.28, 0.32))
	draw_circle(discharge_p, 1.5, Color(0.90, 0.75, 0.15))

	# Amber security work light on intake hopper at night
	if TimeManager.is_night():
		var lamp_p := Vector2(hx, hy - 4)
		draw_circle(lamp_p, 14.0, Color(1.0, 0.75, 0.20, 0.22))
		draw_circle(lamp_p, 6.0, Color(1.0, 0.88, 0.40, 0.45))
		draw_circle(lamp_p, 2.0, Color(1.0, 0.98, 0.75, 0.95))

func _draw_cold_storage(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_COLD_STORAGE != null:
		# Soft ground shadow under cold storage base (3x3 footprint)
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 74.0, sin(rad) * 37.0 + 8.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.32))

		# Pixel-art Cold Storage sprite (96x80 at 2x scale = 192x160)
		var cs_w: float = float(TEX_COLD_STORAGE.get_width()) * 2.0
		var cs_h: float = float(TEX_COLD_STORAGE.get_height()) * 2.0
		var cs_rect := Rect2(-cs_w * 0.5, -104.0, cs_w, cs_h)
		draw_texture_rect(TEX_COLD_STORAGE, cs_rect, false)

		# Night AC & entrance security lights
		if TimeManager.is_night():
			var lamp_p := Vector2(-22.0, -32.0)
			draw_circle(lamp_p, 16.0, Color(0.40, 0.85, 1.0, 0.25))
			draw_circle(lamp_p, 6.0, Color(0.60, 0.92, 1.0, 0.50))
			draw_circle(lamp_p, 2.0, Color(0.95, 0.98, 1.0, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(32.0, -78.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-32.0, -78.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var wall_h: float = 46.0

	# Insulated refrigeration walls (clean cooling blue/white)
	var w_left := PackedVector2Array([
		left * 0.85, bottom * 0.85, bottom * 0.85 + Vector2(0, -wall_h), left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_left, Color(0.82, 0.90, 0.96))
	draw_polyline(w_left, Color(0.40, 0.60, 0.78), 2.0)

	var w_right := PackedVector2Array([
		bottom * 0.85, right * 0.85, right * 0.85 + Vector2(0, -wall_h), bottom * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_right, Color(0.68, 0.78, 0.86))
	draw_polyline(w_right, Color(0.35, 0.50, 0.68), 2.0)

	# Heavy airtight cold-vault door with rotary wheel
	var door_p := (left * 0.85 + bottom * 0.85) * 0.5
	var d_pts := PackedVector2Array([
		door_p + Vector2(-15, 0), door_p + Vector2(15, 0),
		door_p + Vector2(15, -28), door_p + Vector2(-15, -28)
	])
	draw_colored_polygon(d_pts, Color(0.38, 0.48, 0.60))
	draw_polyline(d_pts, Color(0.20, 0.32, 0.46), 2.0)
	draw_circle(door_p + Vector2(0, -14), 4.5, Color(0.88, 0.94, 1.0))

	# Insulated Cooling Roof & AC fans
	var roof_pts := PackedVector2Array([
		top * 0.85 + Vector2(0, -wall_h),
		right * 0.85 + Vector2(0, -wall_h),
		bottom * 0.85 + Vector2(0, -wall_h),
		left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(roof_pts, Color(0.28, 0.48, 0.72))
	draw_polyline(roof_pts, Color(0.18, 0.32, 0.52), 2.0)
	# Dual condenser fan circles on roof
	draw_circle(Vector2(-16, -wall_h - 6), 7.0, Color(0.20, 0.35, 0.50))
	draw_circle(Vector2(16, -wall_h - 6), 7.0, Color(0.20, 0.35, 0.50))

func _draw_solar_dryer(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_DRYER != null:
		# Pixel-art Solar Dryer (Bilaran) concrete pavement (160x96)
		# Scaled 2x (320x192) perfectly matching the 2x3 diamond footprint
		var dryer_w: float = float(TEX_DRYER.get_width()) * 2.0
		var dryer_h: float = float(TEX_DRYER.get_height()) * 2.0
		var dryer_rect: Rect2
		if footprint.y == 3 or footprint.x == 3:
			dryer_rect = Rect2(-158.0, -104.0, dryer_w, dryer_h)
		else:
			var s_w := (right.x - left.x)
			var s_h := s_w * (96.0 / 160.0)
			dryer_rect = Rect2(-s_w * 0.5, -s_h * 0.5, s_w, s_h)
		draw_texture_rect(TEX_DRYER, dryer_rect, false)

		# Golden sun-drying palay grain patches spread on the concrete
		var mat1 := PackedVector2Array([Vector2(-45, -12), Vector2(15, -42), Vector2(55, -22), Vector2(-5, 8)])
		draw_colored_polygon(mat1, Color(0.92, 0.80, 0.25, 0.92))
		draw_polyline(PackedVector2Array([mat1[0], mat1[1], mat1[2], mat1[3], mat1[0]]), Color(0.72, 0.58, 0.15, 0.85), 1.0)

		if level >= 2:
			var mat2 := PackedVector2Array([Vector2(30, 0), Vector2(85, -28), Vector2(120, -10), Vector2(65, 18)])
			draw_colored_polygon(mat2, Color(0.95, 0.84, 0.30, 0.92))
			draw_polyline(PackedVector2Array([mat2[0], mat2[1], mat2[2], mat2[3], mat2[0]]), Color(0.74, 0.60, 0.18, 0.85), 1.0)

		if level >= 3:
			var mat3 := PackedVector2Array([Vector2(-110, 10), Vector2(-70, -10), Vector2(-40, 5), Vector2(-80, 25)])
			draw_colored_polygon(mat3, Color(0.28, 0.65, 0.88, 0.90))
		return

	# Polished concrete drying pavement (Bilaran)
	var pad := PackedVector2Array([top * 0.9, right * 0.9, bottom * 0.9, left * 0.9])
	draw_colored_polygon(pad, Color(0.74, 0.72, 0.68))
	draw_polyline(PackedVector2Array([top * 0.9, right * 0.9, bottom * 0.9, left * 0.9, top * 0.9]), Color(0.48, 0.45, 0.40), 2.0)

	# Golden sun-drying palay grain patches
	var mat1 := PackedVector2Array([top * 0.6, (top + right) * 0.35, bottom * 0.1, left * 0.5])
	draw_colored_polygon(mat1, Color(0.92, 0.80, 0.25, 0.95))

	var mat2 := PackedVector2Array([bottom * 0.2, right * 0.65, bottom * 0.75, (bottom + left) * 0.4])
	draw_colored_polygon(mat2, Color(0.92, 0.80, 0.25, 0.95))

func _draw_garage(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var wall_h: float = 46.0

	# 1. Concrete mechanics service apron in front (3x2 footprint)
	var apron := PackedVector2Array([
		left * 0.95, bottom * 0.95, bottom * 0.95 + Vector2(0, 4), left * 0.95 + Vector2(0, 4)
	])
	draw_colored_polygon(apron, Color(0.24, 0.26, 0.28))

	# Apron surface with tire scuff marks and oil stain
	var apron_surf := PackedVector2Array([top * 0.4, right * 0.4, bottom * 0.95, left * 0.95])
	draw_colored_polygon(apron_surf, Color(0.38, 0.40, 0.42))
	draw_circle(Vector2(-14, 10), 6.0, Color(0.20, 0.20, 0.22, 0.60)) # Oil puddle

	# 2. Corrugated iron workshop back & side walls
	var w_left := PackedVector2Array([
		left * 0.85, (left + bottom) * 0.45, (left + bottom) * 0.45 + Vector2(0, -wall_h), left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_left, Color(0.48, 0.52, 0.56))
	draw_polyline(w_left, Color(0.26, 0.30, 0.34), 1.5)

	var w_back := PackedVector2Array([
		left * 0.85 + Vector2(0, -wall_h), top * 0.85 + Vector2(0, -wall_h),
		top * 0.85, left * 0.85
	])
	draw_colored_polygon(w_back, Color(0.40, 0.44, 0.48))

	var w_right := PackedVector2Array([
		top * 0.85, right * 0.85, right * 0.85 + Vector2(0, -wall_h), top * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(w_right, Color(0.34, 0.38, 0.42))
	draw_polyline(w_right, Color(0.20, 0.24, 0.28), 1.5)

	# Corrugated siding rib lines
	for rx in range(int(left.x * 0.8), int(top.x * 0.8), 8):
		draw_line(Vector2(rx, -4), Vector2(rx, -wall_h), Color(0.32, 0.36, 0.40, 0.6), 1.0)

	# 3. OPEN SERVICE BAYS: Inside view
	var bay1_center := Vector2(-22, -6)
	var bay2_center := Vector2(10, -12)

	# Interior back wall shadow & concrete slab
	var bay_floor := PackedVector2Array([
		Vector2(-42, -18), Vector2(28, -26), Vector2(28, -6), Vector2(-42, 2)
	])
	draw_colored_polygon(bay_floor, Color(0.22, 0.24, 0.26))

	# Overhead steel gantry beam across the bay opening
	var beam_left := Vector2(-45, -wall_h + 10)
	var beam_right := Vector2(30, -wall_h + 4)
	draw_line(beam_left, beam_right, Color(0.85, 0.68, 0.15), 4.0) # Safety yellow gantry rail
	draw_line(beam_left, beam_right, Color(0.15, 0.15, 0.15), 1.5)

	# Chains and engine hoist hook
	var hoist_top := beam_left.lerp(beam_right, 0.45)
	draw_line(hoist_top, hoist_top + Vector2(0, 14), Color(0.65, 0.70, 0.75), 1.5)
	draw_circle(hoist_top + Vector2(0, 15), 2.5, Color(0.85, 0.20, 0.15)) # Hoist block

	# -----------------------------------------------------------------------
	# PARKED MACHINERY INSIDE THE SHED:
	# Bay 1 (Left): Parked Red Kuliglig Hand-Tractor
	# -----------------------------------------------------------------------
	var k_pos := bay1_center
	draw_circle(k_pos + Vector2(-6, 2), 5.5, Color(0.18, 0.20, 0.22)) # Left cage wheel
	draw_circle(k_pos + Vector2(6, 4), 5.5, Color(0.18, 0.20, 0.22))  # Right cage wheel
	for a in range(4):
		var ang: float = float(a) * PI / 2.0
		draw_line(k_pos + Vector2(-6, 2), k_pos + Vector2(-6 + cos(ang) * 5.0, 2 + sin(ang) * 5.0), Color(0.50, 0.55, 0.60), 1.2)
		draw_line(k_pos + Vector2(6, 4), k_pos + Vector2(6 + cos(ang) * 5.0, 4 + sin(ang) * 5.0), Color(0.50, 0.55, 0.60), 1.2)
	# Red single cylinder diesel engine cowl
	var eng_poly := PackedVector2Array([
		k_pos + Vector2(-7, -1), k_pos + Vector2(7, 1),
		k_pos + Vector2(7, -8), k_pos + Vector2(-7, -10)
	])
	draw_colored_polygon(eng_poly, Color(0.85, 0.20, 0.15))
	draw_polyline(eng_poly, Color(0.45, 0.10, 0.08), 1.2)
	# Chrome exhaust & handlebars
	draw_line(k_pos + Vector2(-3, -10), k_pos + Vector2(-3, -17), Color(0.75, 0.80, 0.85), 1.5)
	draw_line(k_pos + Vector2(2, -4), k_pos + Vector2(12, -12), Color(0.20, 0.22, 0.25), 1.8)

	# -----------------------------------------------------------------------
	# Bay 2 (Right): Parked Combine Harvester (Unlocked at Lv.2+)
	# -----------------------------------------------------------------------
	if level >= 2:
		var c_pos := bay2_center
		# Caterpillar tracks (dark treads)
		draw_colored_polygon(PackedVector2Array([
			c_pos + Vector2(-12, 4), c_pos + Vector2(14, 4),
			c_pos + Vector2(12, 8), c_pos + Vector2(-14, 8)
		]), Color(0.12, 0.14, 0.16))
		# Green Combine chassis body
		var c_body := PackedVector2Array([
			c_pos + Vector2(-10, 3), c_pos + Vector2(12, 3),
			c_pos + Vector2(12, -14), c_pos + Vector2(-10, -14)
		])
		draw_colored_polygon(c_body, Color(0.22, 0.55, 0.28))
		draw_polyline(c_body, Color(0.12, 0.32, 0.15), 1.2)
		# Yellow reel cutter bar on front
		draw_line(c_pos + Vector2(-14, 2), c_pos + Vector2(-4, 4), Color(0.95, 0.80, 0.15), 3.0)
		# Overhead grain unloading auger tube
		draw_line(c_pos + Vector2(6, -14), c_pos + Vector2(18, -24), Color(0.85, 0.70, 0.12), 2.5)

	# -----------------------------------------------------------------------
	# Mechanics Details: Workbench, Tires, Oil Drums
	# -----------------------------------------------------------------------
	# Stack of 3 black tractor tires leaning against left wall
	var tire_p := Vector2(-38, -6)
	draw_circle(tire_p, 4.5, Color(0.12, 0.12, 0.14))
	draw_circle(tire_p + Vector2(3, -4), 4.5, Color(0.15, 0.15, 0.17))
	draw_circle(tire_p + Vector2(6, -8), 4.5, Color(0.18, 0.18, 0.20))

	# 55-Gallon Oil Drums (1 Blue, 1 Red) on right
	var drum_p := Vector2(26, -2)
	draw_rect(Rect2(drum_p.x - 3, drum_p.y - 10, 6, 10), Color(0.18, 0.42, 0.72))
	draw_rect(Rect2(drum_p.x - 3, drum_p.y - 10, 6, 10), Color(0.10, 0.20, 0.40), false, 1.0)
	draw_rect(Rect2(drum_p.x + 4, drum_p.y - 8, 6, 8), Color(0.78, 0.22, 0.18))
	draw_rect(Rect2(drum_p.x + 4, drum_p.y - 8, 6, 8), Color(0.40, 0.10, 0.08), false, 1.0)

	# Level 3: Air compressor with pressure gauge
	if level >= 3:
		var comp_p := Vector2(20, -18)
		draw_rect(Rect2(comp_p.x - 4, comp_p.y - 7, 8, 14), Color(0.85, 0.25, 0.20))
		draw_circle(comp_p + Vector2(0, -9), 2.5, Color(0.88, 0.75, 0.20))

	# 4. Gabled Corrugated Iron Roof with Weathered Patina
	var roof_pts := PackedVector2Array([
		top * 0.85 + Vector2(0, -wall_h - 10),
		right * 0.85 + Vector2(0, -wall_h),
		(bottom + right) * 0.40 + Vector2(0, -wall_h),
		left * 0.85 + Vector2(0, -wall_h)
	])
	draw_colored_polygon(roof_pts, Color(0.65, 0.28, 0.22))
	draw_polyline(roof_pts, Color(0.38, 0.16, 0.12), 2.0)

	# Overhang awning timber posts
	draw_line(left * 0.85 + Vector2(0, -wall_h), (left + bottom) * 0.45, Color(0.35, 0.25, 0.15), 3.0)
	draw_line((bottom + right) * 0.40 + Vector2(0, -wall_h), right * 0.45, Color(0.35, 0.25, 0.15), 3.0)

	# Night Floodlights
	if TimeManager.is_night():
		var lamp1 := Vector2(-20, -wall_h + 4)
		draw_circle(lamp1, 24.0, Color(1.0, 0.85, 0.40, 0.25))
		draw_circle(lamp1, 6.0, Color(1.0, 0.95, 0.60, 0.60))
		draw_circle(lamp1, 2.0, Color(1.0, 1.0, 0.90, 0.95))
		var lamp2 := Vector2(10, -wall_h + 2)
		draw_circle(lamp2, 24.0, Color(1.0, 0.85, 0.40, 0.25))
		draw_circle(lamp2, 6.0, Color(1.0, 0.95, 0.60, 0.60))

func _draw_water_tower(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_WATER_STATION != null:
		# Soft ground shadow under water tower footings (2x2 footprint)
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 44.0, sin(rad) * 22.0 + 6.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.30))

		# Pixel-art Water Station sprite (64x144 at 2x scale = 128x288)
		var ws_w: float = float(TEX_WATER_STATION.get_width()) * 2.0
		var ws_h: float = float(TEX_WATER_STATION.get_height()) * 2.0
		var ws_rect := Rect2(-ws_w * 0.5, -252.0, ws_w, ws_h)
		draw_texture_rect(TEX_WATER_STATION, ws_rect, false)

		# Night safety light
		if TimeManager.is_night():
			var lamp_p := Vector2(0.0, -110.0)
			draw_circle(lamp_p, 16.0, Color(0.40, 0.75, 1.0, 0.22))
			draw_circle(lamp_p, 5.0, Color(0.60, 0.90, 1.0, 0.50))
			draw_circle(lamp_p, 1.8, Color(0.95, 0.98, 1.0, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(22.0, -165.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-22.0, -165.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.88
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	var t: float = float(Time.get_ticks_msec()) * 0.001

	# 1. Reinforced stone/concrete diamond base pad
	var pad_h: float = 6.0
	var pad_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, pad_h), p_left + Vector2(0, pad_h)
	])
	draw_colored_polygon(pad_left, Color(0.28, 0.30, 0.34))
	draw_polyline(pad_left, Color(0.18, 0.20, 0.22), 1.5)

	var pad_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, pad_h), p_bottom + Vector2(0, pad_h)
	])
	draw_colored_polygon(pad_right, Color(0.36, 0.38, 0.42))
	draw_polyline(pad_right, Color(0.22, 0.24, 0.26), 1.5)

	var pad_top := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad_top, Color(0.48, 0.50, 0.54))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.25, 0.28, 0.30), 1.5)

	# Catchment drain channel on pad perimeter
	draw_polyline(PackedVector2Array([
		p_top * 0.85, p_right * 0.85, p_bottom * 0.85, p_left * 0.85, p_top * 0.85
	]), Color(0.20, 0.25, 0.30, 0.8), 1.5)

	if level == 1:
		# =======================================================================
		# TIER 1: GROUNDWATER DEEP WELL PUMP (BOMBA NG TUBIG)
		# =======================================================================
		var basin_center := Vector2(8, 6)
		var basin_w: float = 16.0
		draw_set_transform(basin_center, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, basin_w + 3.0, Color(0.30, 0.32, 0.35))
		draw_circle(Vector2.ZERO, basin_w, Color(0.18, 0.42, 0.65, 0.90))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Animated water ripples in catch basin
		var ripple_phase: float = fmod(t * 1.5, 1.0)
		draw_set_transform(basin_center, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, (basin_w - 2.0) * ripple_phase, 0.0, TAU, 16, Color(0.60, 0.85, 1.0, 0.70 * (1.0 - ripple_phase)), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Wellhead borehole casing flange (dark cast iron)
		var well_p := Vector2(-12, -4)
		draw_circle(well_p + Vector2(0, 3), 9.0, Color(0.18, 0.20, 0.22))
		draw_circle(well_p + Vector2(0, 3), 6.5, Color(0.10, 0.12, 0.14))

		# Vertical suction column rising from wellhead
		draw_line(well_p + Vector2(0, 3), well_p + Vector2(0, -22), Color(0.25, 0.28, 0.32), 6.0)
		draw_line(well_p + Vector2(-1, 3), well_p + Vector2(-1, -22), Color(0.45, 0.50, 0.56), 2.0)

		# Reciprocating pump arm and cylinder
		var pump_top := well_p + Vector2(0, -22)
		draw_circle(pump_top, 5.0, Color(0.20, 0.24, 0.28))
		var arm_angle: float = sin(t * 6.0) * 0.22
		var arm_end := pump_top + Vector2(cos(arm_angle) * 16.0, sin(arm_angle) * 8.0 - 4.0)
		draw_line(pump_top, arm_end, Color(0.35, 0.40, 0.46), 3.0)
		draw_circle(arm_end, 3.0, Color(0.75, 0.25, 0.20))

		# Red Yanmar/Kubota utility single-cylinder diesel motor
		var eng_p := Vector2(-28, -2)
		var eng_body := PackedVector2Array([
			eng_p + Vector2(-8, 4), eng_p + Vector2(12, 4),
			eng_p + Vector2(12, -14), eng_p + Vector2(-8, -14)
		])
		draw_colored_polygon(eng_body, Color(0.78, 0.22, 0.18))
		draw_polyline(eng_body, Color(0.42, 0.10, 0.08), 1.5)

		# Spinning flywheel & drive belt
		var fly_p := eng_p + Vector2(14, -5)
		draw_circle(fly_p, 6.0, Color(0.25, 0.28, 0.32))
		draw_circle(fly_p, 4.0, Color(0.55, 0.60, 0.66))
		var spoke_rot: float = t * 12.0
		draw_line(fly_p, fly_p + Vector2(cos(spoke_rot) * 5.0, sin(spoke_rot) * 5.0), Color(0.18, 0.20, 0.22), 1.5)
		draw_line(fly_p, pump_top + Vector2(2, 6), Color(0.15, 0.15, 0.15), 1.5)

		# Exhaust pipe & puffing diesel smoke
		var exh_p := eng_p + Vector2(-4, -14)
		draw_line(exh_p, exh_p + Vector2(0, -12), Color(0.30, 0.30, 0.32), 2.5)
		var smoke_t: float = fmod(t * 2.0, 1.0)
		var smoke_p := exh_p + Vector2(-2.0 - smoke_t * 6.0, -14.0 - smoke_t * 14.0)
		draw_circle(smoke_p, 2.0 + smoke_t * 4.0, Color(0.60, 0.62, 0.65, 0.50 * (1.0 - smoke_t)))

		# Arching discharge pipe pouring into basin
		var pipe_pts := PackedVector2Array([
			pump_top + Vector2(3, 4),
			pump_top + Vector2(16, 8),
			basin_center + Vector2(0, -6)
		])
		draw_polyline(pipe_pts, Color(0.22, 0.45, 0.70), 3.5)
		draw_line(basin_center + Vector2(0, -6), basin_center + Vector2(0, -1), Color(0.45, 0.80, 1.0, 0.85), 2.5)

	elif level == 2:
		# =======================================================================
		# TIER 2: ELEVATED WATER TOWER (TANGKE NG TUBIG)
		# =======================================================================
		var tower_h: float = 58.0
		var tank_w: float = 34.0
		var tank_h: float = 36.0
		var tank_y: float = -tower_h

		# 4 Heavy wooden/steel trestle stanchion legs
		var leg_col := Color(0.38, 0.28, 0.18)
		var brace_col := Color(0.50, 0.38, 0.25)
		var foot_pts := [Vector2(-24, 6), Vector2(0, 14), Vector2(24, 6), Vector2(0, -6)]
		var top_pts := [Vector2(-16, tank_y + 10), Vector2(0, tank_y + 16), Vector2(16, tank_y + 10), Vector2(0, tank_y + 2)]

		for i in range(4):
			draw_line(foot_pts[i], top_pts[i], leg_col, 3.5)
			draw_circle(foot_pts[i], 3.5, Color(0.28, 0.30, 0.34))

		# Diagonal X-bracing between legs
		draw_line(foot_pts[0], top_pts[1], brace_col, 1.5)
		draw_line(foot_pts[1], top_pts[0], brace_col, 1.5)
		draw_line(foot_pts[1], top_pts[2], brace_col, 1.5)
		draw_line(foot_pts[2], top_pts[1], brace_col, 1.5)
		draw_line(foot_pts[0], top_pts[3], brace_col, 1.2)
		draw_line(foot_pts[2], top_pts[3], brace_col, 1.2)

		# Central vertical high-pressure downspout pipe
		draw_line(Vector2(0, 4), Vector2(0, tank_y + 8), Color(0.24, 0.38, 0.52), 4.5)
		draw_line(Vector2(0, 4), Vector2(0, tank_y + 8), Color(0.40, 0.60, 0.78), 2.0)
		draw_circle(Vector2(0, -12), 4.0, Color(0.85, 0.68, 0.15))
		draw_circle(Vector2(0, -12), 2.0, Color(0.40, 0.30, 0.08))

		# Service ladder up left leg
		for step in range(5):
			var sy: float = lerpf(0.0, tank_y + 8, float(step + 1) / 6.0)
			var lx: float = lerpf(-24.0, -16.0, float(step + 1) / 6.0)
			draw_line(Vector2(lx - 2, sy), Vector2(lx + 4, sy), Color(0.20, 0.22, 0.25), 1.5)

		# Wooden stave cylindrical water cistern tank body
		var tank_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y - tank_h),
			Vector2(-tank_w * 0.5, tank_y - tank_h)
		])
		draw_colored_polygon(tank_rect, Color(0.55, 0.40, 0.26))
		draw_polyline(tank_rect, Color(0.28, 0.18, 0.10), 2.0)

		# Vertical timber staves
		for x in range(int(-tank_w * 0.5 + 5), int(tank_w * 0.5), 6):
			draw_line(Vector2(x, tank_y), Vector2(x, tank_y - tank_h), Color(0.42, 0.30, 0.18), 1.2)

		# Black iron reinforcement barrel hoops
		var hoop_ys := [tank_y - 4, tank_y - 16, tank_y - 28, tank_y - tank_h + 2]
		for hy in hoop_ys:
			draw_line(Vector2(-tank_w * 0.5 - 1, hy), Vector2(tank_w * 0.5 + 1, hy), Color(0.18, 0.18, 0.20), 2.5)

		# Water level sight-glass tube on front
		var tube_x: float = 6.0
		draw_line(Vector2(tube_x, tank_y - 4), Vector2(tube_x, tank_y - tank_h + 4), Color(0.20, 0.20, 0.20), 3.0)
		draw_line(Vector2(tube_x, tank_y - 4), Vector2(tube_x, tank_y - tank_h + 4), Color(0.60, 0.85, 1.0, 0.70), 1.5)
		var bobber_y: float = tank_y - 18 + sin(t * 2.0) * 3.0
		draw_circle(Vector2(tube_x, bobber_y), 2.0, Color(0.95, 0.25, 0.20))

		# Conical galvanized tin roof with finial
		var roof_peak := Vector2(0, tank_y - tank_h - 18.0)
		var roof_pts := PackedVector2Array([
			roof_peak,
			Vector2(tank_w * 0.5 + 3, tank_y - tank_h),
			Vector2(-tank_w * 0.5 - 3, tank_y - tank_h)
		])
		draw_colored_polygon(roof_pts, Color(0.68, 0.72, 0.78))
		draw_polyline(roof_pts, Color(0.38, 0.42, 0.48), 2.0)
		draw_circle(roof_peak, 3.5, Color(0.92, 0.78, 0.20))

	elif level >= 3:
		# =======================================================================
		# TIER 3: SOLAR-POWERED PRESSURIZED DRIP NETWORK
		# =======================================================================
		var tower_h: float = 64.0
		var tank_w: float = 38.0
		var tank_h: float = 38.0
		var tank_y: float = -tower_h

		var steel_col := Color(0.48, 0.54, 0.60)
		var foot_pts: Array[Vector2] = [Vector2(-26, 6), Vector2(0, 16), Vector2(26, 6), Vector2(0, -6)]
		var top_pts: Array[Vector2] = [Vector2(-18, tank_y + 10), Vector2(0, tank_y + 18), Vector2(18, tank_y + 10), Vector2(0, tank_y + 2)]

		for i in range(4):
			draw_line(foot_pts[i], top_pts[i], steel_col, 4.0)
			draw_circle(foot_pts[i], 4.0, Color(0.24, 0.26, 0.30))

		# Double steel X-braces
		for i in range(3):
			var pA: Vector2 = foot_pts[i]
			var pB: Vector2 = foot_pts[(i + 1) % 4]
			var tA: Vector2 = top_pts[i]
			var tB: Vector2 = top_pts[(i + 1) % 4]
			draw_line(pA, tB, Color(0.60, 0.66, 0.72), 1.5)
			draw_line(pB, tA, Color(0.60, 0.66, 0.72), 1.5)

		# Ground booster pump station & dual inline filtration canisters
		var pump1_p := Vector2(-12, 6)
		draw_rect(Rect2(pump1_p.x - 5, pump1_p.y - 7, 10, 14), Color(0.18, 0.42, 0.72))
		draw_rect(Rect2(pump1_p.x - 5, pump1_p.y - 7, 10, 14), Color(0.10, 0.22, 0.40), false, 1.2)
		var pump2_p := Vector2(12, 6)
		draw_rect(Rect2(pump2_p.x - 5, pump2_p.y - 7, 10, 14), Color(0.18, 0.42, 0.72))
		draw_rect(Rect2(pump2_p.x - 5, pump2_p.y - 7, 10, 14), Color(0.10, 0.22, 0.40), false, 1.2)

		# Pressurized manifold pipe running down
		draw_line(Vector2(0, 6), Vector2(0, tank_y + 8), Color(0.15, 0.35, 0.65), 5.5)
		draw_line(Vector2(0, 6), Vector2(0, tank_y + 8), Color(0.35, 0.70, 0.95), 2.5)

		# Glistening cyan water flow pulses travelling down the main line
		var flow_pos: float = fmod(t * 3.0, 1.0)
		var flow_y: float = lerpf(tank_y + 8, 6.0, flow_pos)
		draw_circle(Vector2(0, flow_y), 3.0, Color(0.60, 0.95, 1.0, 0.90))

		# Modern high-capacity cylindrical stainless steel water cistern
		var tank_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y),
			Vector2(tank_w * 0.5, tank_y - tank_h),
			Vector2(-tank_w * 0.5, tank_y - tank_h)
		])
		draw_colored_polygon(tank_rect, Color(0.85, 0.90, 0.95))
		draw_polyline(tank_rect, Color(0.40, 0.48, 0.56), 2.0)

		# Hydro-blue municipal utility paint stripe around middle
		var stripe_rect := PackedVector2Array([
			Vector2(-tank_w * 0.5 + 1, tank_y - 12),
			Vector2(tank_w * 0.5 - 1, tank_y - 12),
			Vector2(tank_w * 0.5 - 1, tank_y - 24),
			Vector2(-tank_w * 0.5 + 1, tank_y - 24)
		])
		draw_colored_polygon(stripe_rect, Color(0.18, 0.52, 0.88))

		# Digital LED flow / telemetry display on tank front
		var screen_p := Vector2(0, tank_y - 18)
		draw_rect(Rect2(screen_p.x - 7, screen_p.y - 4, 14, 8), Color(0.10, 0.12, 0.15))
		var led_pulse: float = 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(screen_p + Vector2(-3, 0), 1.5, Color(0.20, 0.95, 0.35))
		draw_circle(screen_p + Vector2(3, 0), 1.5, Color(0.20, 0.80, 1.0, 0.5 + led_pulse * 0.5))

		# Photovoltaic Solar Panel Array atop the cistern
		var sol_y: float = tank_y - tank_h
		var sol_pts := PackedVector2Array([
			Vector2(-tank_w * 0.5 - 4, sol_y + 2),
			Vector2(tank_w * 0.5 + 4, sol_y + 2),
			Vector2(tank_w * 0.5 + 2, sol_y - 16),
			Vector2(-tank_w * 0.5 - 2, sol_y - 16)
		])
		draw_colored_polygon(sol_pts, Color(0.12, 0.22, 0.42))
		draw_polyline(sol_pts, Color(0.70, 0.75, 0.82), 2.0)

		# Solar panel cell grid lines
		draw_line(Vector2(0, sol_y + 2), Vector2(0, sol_y - 16), Color(0.40, 0.55, 0.75), 1.2)
		draw_line(Vector2(-tank_w * 0.5, sol_y - 7), Vector2(tank_w * 0.5, sol_y - 7), Color(0.40, 0.55, 0.75), 1.2)

		# Night illuminators
		if TimeManager.is_night():
			var lamp_p := Vector2(0, tank_y + 2)
			draw_circle(lamp_p, 16.0, Color(0.35, 0.75, 1.0, 0.22))
			draw_circle(lamp_p, 6.0, Color(0.50, 0.90, 1.0, 0.50))
			draw_circle(lamp_p, 2.0, Color(0.90, 0.98, 1.0, 0.95))

func _draw_silo(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var silo_w: float = 46.0
	var silo_h: float = 75.0

	# 2.5D Cylindrical steel silo body
	var body := PackedVector2Array([
		Vector2(-silo_w, 0), Vector2(silo_w, 0),
		Vector2(silo_w, -silo_h), Vector2(-silo_w, -silo_h)
	])
	draw_colored_polygon(body, Color(0.76, 0.80, 0.86))
	draw_polyline(body, Color(0.42, 0.46, 0.52), 2.0)

	# Horizontal steel reinforcement rings
	for y in range(int(-silo_h + 15), 0, 16):
		draw_line(Vector2(-silo_w, y), Vector2(silo_w, y), Color(0.55, 0.60, 0.68), 2.0)

	# Conical Silo Steel Dome Roof
	var dome_peak := Vector2(0, -silo_h - 32.0)
	var dome_pts := PackedVector2Array([dome_peak, Vector2(silo_w + 4, -silo_h), Vector2(-silo_w - 4, -silo_h)])
	draw_colored_polygon(dome_pts, Color(0.62, 0.66, 0.74))
	draw_polyline(dome_pts, Color(0.38, 0.42, 0.48), 2.0)
	draw_circle(dome_peak, 4.0, Color(0.85, 0.90, 0.95))

func _draw_drone_station(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_DRONE_STATION != null:
		# Soft ground shadow under drone hangar base (2x2 footprint)
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 54.0, sin(rad) * 27.0 + 6.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.30))

		# Pixel-art Drone Station sprite (80x128 at 2x scale = 160x256)
		var ds_w: float = float(TEX_DRONE_STATION.get_width()) * 2.0
		var ds_h: float = float(TEX_DRONE_STATION.get_height()) * 2.0
		var ds_rect := Rect2(-ds_w * 0.5, -216.0, ds_w, ds_h)
		draw_texture_rect(TEX_DRONE_STATION, ds_rect, false)

		# Blinking red aircraft warning beacon at the antenna mast tip
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var mast_tip := Vector2(-16.0, -204.0)
		var blink: float = 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
		draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

		# Night helipad lighting
		if TimeManager.is_night():
			var h_lights := [Vector2(-36, -8), Vector2(0, 10), Vector2(36, -8), Vector2(0, -26)]
			for lp in h_lights:
				draw_circle(lp, 5.0, Color(0.30, 0.85, 1.0, 0.30))
				draw_circle(lp, 1.8, Color(0.70, 0.95, 1.0, 0.90))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(24.0, -112.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-24.0, -112.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.92
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	# 1. Reinforced concrete foundation curb
	var curb_h: float = 4.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.24, 0.26, 0.30))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.32, 0.35, 0.40))

	# 2. Modern dark tarmac landing pad
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.18, 0.20, 0.24))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.10, 0.12, 0.15), 1.5)

	# 3. Yellow/black perimeter hazard warning chevrons
	var caution_gold := Color(0.95, 0.78, 0.20, 0.85)
	var caution_dark := Color(0.12, 0.12, 0.15, 0.85)
	for i in range(8):
		var t1: float = float(i) / 8.0
		var t2: float = float(i + 0.5) / 8.0
		var col: Color = caution_gold if (i % 2 == 0) else caution_dark
		draw_line(p_left.lerp(p_bottom, t1), p_left.lerp(p_bottom, t2), col, 2.5)
		draw_line(p_bottom.lerp(p_right, t1), p_bottom.lerp(p_right, t2), col, 2.5)

	# 4. Central circular landing target with glowing cyan ring and 'H' / crosshair
	var pad_center := (p_top + p_bottom) * 0.5 + Vector2(0, -2.0)
	draw_set_transform(pad_center, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 20.0, Color(0.10, 0.14, 0.18, 0.95))
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 24, Color(0.30, 0.85, 1.0, 0.90), 2.0)
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(0.30, 0.85, 1.0, 0.45), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Letter 'H' inside the helipad target ring
	var h_col := Color(0.95, 0.98, 1.0, 0.95)
	draw_line(pad_center + Vector2(-6, -6), pad_center + Vector2(-6, 6), h_col, 2.0)
	draw_line(pad_center + Vector2(6, -6), pad_center + Vector2(6, 6), h_col, 2.0)
	draw_line(pad_center + Vector2(-6, 0), pad_center + Vector2(6, 0), h_col, 2.0)

	# 5. Back Command Wall & Battery Recharging Bays
	var wall_base_l := p_left.lerp(p_top, 0.25)
	var wall_base_r := p_top.lerp(p_right, 0.75)
	var wall_h: float = 24.0
	var wall_top_l := wall_base_l + Vector2(0, -wall_h)
	var wall_top_r := wall_base_r + Vector2(0, -wall_h)

	var back_wall := PackedVector2Array([wall_base_l, wall_base_r, wall_top_r, wall_top_l])
	draw_colored_polygon(back_wall, Color(0.25, 0.28, 0.35))
	draw_polyline(back_wall, Color(0.12, 0.14, 0.18), 1.5)

	# Battery charging dock slots with green indicator LEDs
	var num_bays: int = clampi(level, 1, 3)
	for b in range(num_bays):
		var frac: float = float(b + 1) / float(num_bays + 1)
		var bay_pos := wall_base_l.lerp(wall_base_r, frac) + Vector2(0, -wall_h * 0.4)
		draw_rect(Rect2(bay_pos.x - 4, bay_pos.y - 6, 8, 10), Color(0.12, 0.14, 0.18))
		draw_rect(Rect2(bay_pos.x - 3, bay_pos.y - 5, 6, 8), Color(0.20, 0.75, 0.35)) # Green battery LED

	# 6. Radio Telemetry Antenna Mast on the back-left
	var mast_base := wall_top_l + Vector2(4, 0)
	var mast_tip := mast_base + Vector2(0, -32.0)
	draw_line(mast_base, mast_tip, Color(0.70, 0.75, 0.82), 2.0)
	draw_line(mast_tip + Vector2(-6, 8), mast_tip + Vector2(6, 8), Color(0.70, 0.75, 0.82), 1.5)
	draw_line(mast_tip + Vector2(-4, 14), mast_tip + Vector2(4, 14), Color(0.70, 0.75, 0.82), 1.5)

	# Blinking red aircraft warning beacon at the tip
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var blink: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
	draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

	# 7. Level-specific attachments
	if level >= 2:
		# Seed hopper dispensing terminal on the right side
		var hopper_pos := wall_top_r + Vector2(-4, 2)
		var hopper_poly := PackedVector2Array([
			hopper_pos + Vector2(-8, -12), hopper_pos + Vector2(8, -12),
			hopper_pos + Vector2(4, 0), hopper_pos + Vector2(-4, 0)
		])
		draw_colored_polygon(hopper_poly, Color(0.85, 0.72, 0.30)) # Amber seed hopper
		draw_polyline(hopper_poly, Color(0.35, 0.25, 0.10), 1.2)

	if level >= 3:
		# High-gain communications dish & automated maintenance arm
		var dish_center := mast_tip + Vector2(14, 4)
		draw_arc(dish_center, 9.0, -PI * 0.6, PI * 0.4, 12, Color(0.88, 0.92, 0.98), 2.5)
		draw_line(mast_tip + Vector2(2, 6), dish_center, Color(0.50, 0.55, 0.62), 1.5)
		draw_circle(dish_center, 2.5, Color(0.35, 0.85, 1.0)) # Telemetry uplink light

func _draw_weather_station(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	if TEX_WEATHER_STATION != null:
		# Soft ground shadow under weather station platform (2x2 footprint)
		var shadow_poly := PackedVector2Array()
		for a in range(16):
			var rad: float = float(a) * TAU / 16.0
			shadow_poly.append(Vector2(cos(rad) * 50.0, sin(rad) * 25.0 + 6.0))
		draw_colored_polygon(shadow_poly, Color(0.06, 0.10, 0.04, 0.30))

		# Pixel-art Weather Station sprite (112x128 at 2x scale = 224x256)
		var wea_w: float = float(TEX_WEATHER_STATION.get_width()) * 2.0
		var wea_h: float = float(TEX_WEATHER_STATION.get_height()) * 2.0
		var wea_rect := Rect2(-wea_w * 0.5, -194.0, wea_w, wea_h)
		draw_texture_rect(TEX_WEATHER_STATION, wea_rect, false)

		# Blinking red aircraft warning beacon at tower mast tip
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var mast_tip := Vector2(-2.0, -192.0)
		var blink: float = 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(mast_tip, 3.5, Color(1.0, 0.20, 0.20, 0.95))
		draw_circle(mast_tip, 7.0, Color(1.0, 0.20, 0.20, 0.35 * blink))

		# Night cabinet lantern
		if TimeManager.is_night():
			var cab_lamp := Vector2(28.0, -42.0)
			draw_circle(cab_lamp, 14.0, Color(1.0, 0.85, 0.35, 0.22))
			draw_circle(cab_lamp, 4.5, Color(1.0, 0.92, 0.50, 0.50))
			draw_circle(cab_lamp, 1.5, Color(1.0, 0.98, 0.85, 0.95))

		# Level indicators
		if level >= 2:
			draw_circle(Vector2(30.0, -90.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		if level >= 3:
			draw_circle(Vector2(-30.0, -90.0), 3.0, Color(0.95, 0.85, 0.3, 0.9))
		return

	var s: float = 0.88
	var p_top := top * s
	var p_right := right * s
	var p_bottom := bottom * s
	var p_left := left * s

	# 1. Reinforced concrete foundation curb
	var curb_h: float = 5.0
	var curb_left := PackedVector2Array([
		p_left, p_bottom, p_bottom + Vector2(0, curb_h), p_left + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_left, Color(0.24, 0.26, 0.30))

	var curb_right := PackedVector2Array([
		p_bottom, p_right, p_right + Vector2(0, curb_h), p_bottom + Vector2(0, curb_h)
	])
	draw_colored_polygon(curb_right, Color(0.32, 0.35, 0.40))

	# 2. Modern concrete foundation slab
	var pad := PackedVector2Array([p_top, p_right, p_bottom, p_left])
	draw_colored_polygon(pad, Color(0.42, 0.45, 0.50))
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), Color(0.20, 0.22, 0.26), 1.5)

	# Expansion joint lines on slab
	draw_line((p_top + p_left) * 0.5, (p_right + p_bottom) * 0.5, Color(0.34, 0.37, 0.42), 1.0)
	draw_line((p_top + p_right) * 0.5, (p_left + p_bottom) * 0.5, Color(0.34, 0.37, 0.42), 1.0)

	# 3. Ground Telemetry Cabinet (Rear-Left Corner)
	var cab_pos := p_left.lerp(p_top, 0.6) + Vector2(6, -2)
	var cab_w: float = 14.0
	var cab_h: float = 16.0
	var cab_d: float = 8.0
	var cab_front := PackedVector2Array([
		cab_pos + Vector2(0, 0),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h),
		cab_pos + Vector2(0, -cab_h)
	])
	var cab_side := PackedVector2Array([
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5),
		cab_pos + Vector2(cab_w, 0),
		cab_pos + Vector2(cab_w, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h)
	])
	var cab_top := PackedVector2Array([
		cab_pos + Vector2(0, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, cab_d * 0.5 - cab_h),
		cab_pos + Vector2(cab_w, -cab_h),
		cab_pos + Vector2(cab_w * 0.5, -cab_d * 0.5 - cab_h)
	])
	draw_colored_polygon(cab_front, Color(0.70, 0.74, 0.80))
	draw_colored_polygon(cab_side, Color(0.55, 0.59, 0.65))
	draw_colored_polygon(cab_top, Color(0.82, 0.86, 0.92))
	draw_polyline(cab_front, Color(0.20, 0.22, 0.26), 1.0)
	draw_polyline(cab_side, Color(0.20, 0.22, 0.26), 1.0)

	# Cabinet status LEDs
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	draw_circle(cab_pos + Vector2(3, -11), 1.2, Color(0.20, 0.85, 0.35)) # Green power
	var led_blink: float = 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(cab_pos + Vector2(5.5, -10), 1.2, Color(0.20, 0.75, 1.0, 0.5 + led_blink * 0.5)) # Cyan telemetry
	if level >= 2:
		draw_circle(cab_pos + Vector2(4, -7), 1.0, Color(1.0, 0.75, 0.20)) # Amber sensor link

	# 4. Central Tower Base & Mast Structure
	var center_pt := (p_top + p_bottom) * 0.5
	var mast_base := center_pt + Vector2(2, -2)
	var mast_h: float = 58.0 if level == 1 else (64.0 if level == 2 else 72.0)
	var mast_tip := mast_base + Vector2(0, -mast_h)

	# Guy-wires from mast to platform corners
	var steel_wire := Color(0.40, 0.45, 0.52, 0.65)
	draw_line(mast_base + Vector2(0, -mast_h * 0.55), p_left + Vector2(4, 0), steel_wire, 1.0)
	draw_line(mast_base + Vector2(0, -mast_h * 0.55), p_right + Vector2(-4, 0), steel_wire, 1.0)
	draw_line(mast_base + Vector2(0, -mast_h * 0.85), p_bottom + Vector2(0, -2), steel_wire, 1.0)

	# Steel lattice triangular truss
	var steel_col := Color(0.68, 0.72, 0.78)
	var steel_shadow := Color(0.35, 0.38, 0.44)
	var leg_w: float = 5.0
	var num_rungs: int = int(mast_h / 8.0)

	# Left and right truss legs
	draw_line(mast_base + Vector2(-leg_w, 0), mast_tip, steel_col, 1.8)
	draw_line(mast_base + Vector2(leg_w, 0), mast_tip, steel_shadow, 1.8)
	draw_line(mast_base + Vector2(0, 2), mast_tip, steel_col, 1.2) # center spine

	# Diagonal cross rungs
	for r in range(num_rungs):
		var frac1: float = float(r) / float(num_rungs)
		var frac2: float = float(r + 1) / float(num_rungs)
		var y1: float = lerpf(mast_base.y, mast_tip.y, frac1)
		var y2: float = lerpf(mast_base.y, mast_tip.y, frac2)
		var w1: float = lerpf(leg_w, 1.0, frac1)
		var w2: float = lerpf(leg_w, 1.0, frac2)

		var p1_l := Vector2(mast_base.x - w1, y1)
		var p1_r := Vector2(mast_base.x + w1, y1)
		var p2_l := Vector2(mast_base.x - w2, y2)
		var p2_r := Vector2(mast_base.x + w2, y2)

		draw_line(p1_l, p1_r, steel_col, 1.0)
		draw_line(p1_l, p2_r, steel_col, 1.0)
		draw_line(p1_r, p2_l, steel_shadow, 0.8)

	# 5. Mast Tip Aircraft Warning Beacon
	var beacon_glow: float = 0.5 + 0.5 * sin(t * 5.0)
	draw_circle(mast_tip, 4.0, Color(1.0, 0.20, 0.20, 0.30 + beacon_glow * 0.40)) # Soft glow halo
	draw_circle(mast_tip, 2.5, Color(1.0, 0.20, 0.20, 0.95)) # Core LED

	# Top dipole T-crossbar
	draw_line(mast_tip + Vector2(-6, 2), mast_tip + Vector2(6, 2), steel_col, 1.5)
	draw_line(mast_tip + Vector2(0, -6), mast_tip, steel_col, 1.5)

	# ── LEVEL SPECIFIC EQUIPMENT ──────────────────────────────────────
	if level == 1:
		# AM Broadcast Waves (Faint expanding arcs)
		var wave_cycle: float = fmod(t * 1.5, 2.0) / 2.0
		var r_wave: float = 8.0 + wave_cycle * 22.0
		var alpha_wave: float = maxf(0.0, (1.0 - wave_cycle) * 0.6)
		draw_arc(mast_tip, r_wave, -PI * 0.8, -PI * 0.2, 12, Color(0.40, 0.85, 1.0, alpha_wave), 1.2)
		draw_arc(mast_tip, r_wave * 0.6, -PI * 0.8, -PI * 0.2, 12, Color(0.40, 0.85, 1.0, alpha_wave * 0.8), 1.0)

	elif level >= 2:
		# AWS Crossbar Boom at mid-mast
		var boom_y: float = mast_base.y - mast_h * 0.62
		var boom_l := Vector2(mast_base.x - 16, boom_y)
		var boom_r := Vector2(mast_base.x + 16, boom_y)
		draw_line(boom_l, boom_r, Color(0.80, 0.84, 0.90), 1.8)

		# Left side: Anemometer (3 spinning wind cups)
		var ane_center := boom_l + Vector2(0, -4)
		draw_line(boom_l, ane_center, Color(0.65, 0.70, 0.78), 1.5)
		var ane_rot: float = t * 14.0
		for c in range(3):
			var ang: float = ane_rot + float(c) * (TAU / 3.0)
			var cup_pos := ane_center + Vector2(cos(ang) * 6.0, sin(ang) * 2.5)
			draw_line(ane_center, cup_pos, Color(0.50, 0.55, 0.62), 1.0)
			draw_circle(cup_pos, 1.8, Color(0.85, 0.88, 0.92))

		# Right side: Wind Vane Arrow
		var vane_center := boom_r + Vector2(0, -4)
		draw_line(boom_r, vane_center, Color(0.65, 0.70, 0.78), 1.5)
		var vane_ang: float = sin(t * 0.8) * 0.35 - 0.4
		var v_head := vane_center + Vector2(cos(vane_ang) * 7.0, sin(vane_ang) * 3.0)
		var v_tail := vane_center - Vector2(cos(vane_ang) * 6.0, sin(vane_ang) * 2.5)
		draw_line(v_tail, v_head, Color(0.95, 0.85, 0.25), 1.5)
		draw_line(v_head, v_head + Vector2(-2, 2), Color(0.95, 0.85, 0.25), 1.5)
		# Vane tail fin
		draw_line(v_tail + Vector2(0, -3), v_tail + Vector2(0, 3), Color(0.90, 0.30, 0.25), 1.5)

		# Stevenson Screen (White Louvered Thermometer Box below boom)
		var stev_pos := Vector2(mast_base.x - 2, boom_y + 4)
		for l_idx in range(4):
			draw_rect(Rect2(stev_pos.x - 5, stev_pos.y + l_idx * 2.2, 10, 1.5), Color(0.92, 0.95, 0.98))

		# Photovoltaic Solar Panel on South-East mast leg
		var sol_center := mast_base + Vector2(11, -14)
		var sol_poly := PackedVector2Array([
			sol_center + Vector2(-6, -4),
			sol_center + Vector2(6, -8),
			sol_center + Vector2(8, 2),
			sol_center + Vector2(-4, 6)
		])
		draw_colored_polygon(sol_poly, Color(0.12, 0.25, 0.55)) # Dark solar blue
		draw_polyline(PackedVector2Array([sol_poly[0], sol_poly[1], sol_poly[2], sol_poly[3], sol_poly[0]]), Color(0.70, 0.75, 0.82), 1.2) # Aluminum frame
		draw_line((sol_poly[0] + sol_poly[1]) * 0.5, (sol_poly[2] + sol_poly[3]) * 0.5, Color(0.35, 0.50, 0.80, 0.8), 1.0)

		# Rain Gauge Funnel on Ground Right Pier
		var gauge_pos := p_right + Vector2(-8, -4)
		draw_rect(Rect2(gauge_pos.x - 3, gauge_pos.y - 7, 6, 8), Color(0.72, 0.76, 0.82))
		draw_colored_polygon(PackedVector2Array([
			gauge_pos + Vector2(-4, -7), gauge_pos + Vector2(4, -7), gauge_pos + Vector2(2, -4), gauge_pos + Vector2(-2, -4)
		]), Color(0.85, 0.88, 0.92))

	if level >= 3:
		# ── LEVEL 3: HIGH-GAIN PARABOLIC SATELLITE DISH ────────────────
		var dish_pivot := mast_base + Vector2(0, -mast_h * 0.40)
		draw_circle(dish_pivot, 3.5, Color(0.28, 0.32, 0.38)) # Gimbal bearing

		# 3D Parabolic Dish (Elliptical projection angled upward at 45°)
		var dish_center := dish_pivot + Vector2(7, -12)
		var dish_rx: float = 13.0

		# Back bracket & convex dish exterior
		draw_set_transform(dish_center + Vector2(-1, 1), -0.32, Vector2(1.0, 0.65))
		draw_circle(Vector2.ZERO, dish_rx, Color(0.40, 0.44, 0.50)) # Outer shadow rim
		draw_set_transform(dish_center, -0.32, Vector2(1.0, 0.65))
		draw_circle(Vector2.ZERO, dish_rx - 1.0, Color(0.92, 0.94, 0.97)) # White dish surface
		draw_circle(Vector2.ZERO, dish_rx * 0.6, Color(0.78, 0.82, 0.88)) # Center concave depression
		draw_arc(Vector2.ZERO, dish_rx - 1.0, 0, TAU, 24, Color(0.55, 0.60, 0.68), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Sub-reflector Feed Horn and tripod support arms
		var horn_pos := dish_center + Vector2(9, -8)
		draw_line(dish_center + Vector2(-6, -3), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_line(dish_center + Vector2(4, 5), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_line(dish_center + Vector2(6, -6), horn_pos, Color(0.30, 0.34, 0.40), 1.2)
		draw_circle(horn_pos, 2.2, Color(0.25, 0.28, 0.34))

		# Glowing Satellite Telemetry Uplink Beam Burst
		var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
		draw_circle(horn_pos, 3.5, Color(0.20, 0.85, 1.0, 0.40 + pulse * 0.40))
		draw_circle(horn_pos, 1.5, Color(0.85, 0.98, 1.0, 0.95))

func _draw_sprinkler(_top: Vector2, _right: Vector2, _bottom: Vector2, _left: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001

	# 1. Subtle wet ground patch around the sprinkler base
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(0.12, 0.22, 0.28, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Black HDPE high-pressure feeder hose with brass compression fitting
	var hose_start := Vector2(-20, 10)
	var hose_end := Vector2(0, 0)
	draw_line(hose_start, hose_end, Color(0.12, 0.12, 0.14), 3.0)
	draw_line(hose_start, hose_end, Color(0.25, 0.26, 0.28), 1.2)
	draw_circle(hose_end + Vector2(-3, 1), 2.5, Color(0.85, 0.70, 0.22))

	# 3. Octagonal concrete anchor footing pad (small chamfered block)
	var pad_pts := PackedVector2Array([
		Vector2(-8, 0), Vector2(0, 4), Vector2(8, 0), Vector2(0, -4)
	])
	draw_colored_polygon(pad_pts, Color(0.38, 0.40, 0.44))
	draw_polyline(pad_pts, Color(0.20, 0.22, 0.25), 1.2)

	# Pad thickness
	var pad_front := PackedVector2Array([
		Vector2(-8, 0), Vector2(0, 4), Vector2(0, 7), Vector2(-8, 3)
	])
	draw_colored_polygon(pad_front, Color(0.26, 0.28, 0.32))
	var pad_side := PackedVector2Array([
		Vector2(0, 4), Vector2(8, 0), Vector2(8, 3), Vector2(0, 7)
	])
	draw_colored_polygon(pad_side, Color(0.32, 0.34, 0.38))

	# 4 Corner anchor bolts
	draw_circle(Vector2(-5, 0), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(5, 0), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(0, 2.5), 1.0, Color(0.85, 0.75, 0.30))
	draw_circle(Vector2(0, -2.5), 1.0, Color(0.85, 0.75, 0.30))

	# 4. Galvanized steel vertical riser pipe
	var riser_h: float = 18.0
	var riser_tip := Vector2(0, -riser_h)
	draw_line(Vector2(0, 0), riser_tip, Color(0.48, 0.52, 0.58), 3.5)
	draw_line(Vector2(-0.5, 0), riser_tip + Vector2(-0.5, 0), Color(0.75, 0.80, 0.88), 1.2)

	# 5. Brass impact rotary sprinkler head
	draw_circle(riser_tip, 3.2, Color(0.85, 0.70, 0.22))
	draw_circle(riser_tip, 1.8, Color(0.55, 0.42, 0.12))

	# Rotary oscillation
	var rot_speed: float = 4.2
	var head_angle: float = fmod(t * rot_speed, TAU)
	var dir := Vector2(cos(head_angle), sin(head_angle) * 0.5)

	# Brass nozzle barrel pointing along dir
	var nozzle_len: float = 7.0
	var nozzle_tip: Vector2 = riser_tip + dir * nozzle_len
	draw_line(riser_tip, nozzle_tip, Color(0.92, 0.78, 0.25), 2.4)
	draw_line(riser_tip, nozzle_tip, Color(0.60, 0.48, 0.15), 1.0)

	# Oscillating impact spring hammer arm (clicks back and forth)
	var hammer_kick: float = sin(t * 26.0) * 0.4
	var hammer_dir := dir.rotated(hammer_kick)
	var hammer_tip := riser_tip + hammer_dir * 5.0 + Vector2(0, -2)
	draw_line(riser_tip, hammer_tip, Color(0.70, 0.55, 0.18), 1.8)
	draw_circle(hammer_tip, 1.5, Color(0.85, 0.72, 0.28))

	# 6. Active water spray visuals
	if state == BuildingState.ACTIVE:
		# Rotating high-velocity water jet stream (gravity ballistic curve)
		var stream_pts := PackedVector2Array()
		stream_pts.append(nozzle_tip)
		var stream_len: float = 38.0
		for step in range(1, 6):
			var frac: float = float(step) / 5.0
			var arc_p: Vector2 = nozzle_tip + dir * (stream_len * frac) + Vector2(0, -frac * 4.0 + frac * frac * 12.0)
			stream_pts.append(arc_p)
		draw_polyline(stream_pts, Color(0.55, 0.88, 1.0, 0.75), 1.8)

		# Flying water droplets along the stream
		for d in range(4):
			var d_offset: float = fmod(t * 12.0 + float(d) * 0.25, 1.0)
			var d_pos: Vector2 = nozzle_tip + dir * (stream_len * d_offset) + Vector2(0, -d_offset * 4.0 + d_offset * d_offset * 12.0)
			draw_circle(d_pos, 1.6, Color(0.85, 0.96, 1.0, 0.90))

		# Water mist spray cone (fine glistening droplets fanning out)
		for m in range(6):
			var m_phase: float = fmod(t * 8.0 + float(m) * 0.16, 1.0)
			var m_spread: float = (float(m % 3) - 1.0) * 0.22
			var m_dir: Vector2 = dir.rotated(m_spread)
			var m_pos: Vector2 = nozzle_tip + m_dir * (28.0 * m_phase) + Vector2(0, 4.0 * m_phase)
			draw_circle(m_pos, 1.0, Color(0.65, 0.92, 1.0, 0.60 * (1.0 - m_phase)))

		# Ground impact ripple at spray landing spot
		var ground_splash: Vector2 = Vector2.ZERO + dir * 36.0
		draw_set_transform(ground_splash, 0.0, Vector2(1.0, 0.5))
		var rip_p: float = fmod(t * 3.0, 1.0)
		draw_arc(Vector2.ZERO, 3.0 + rip_p * 6.0, 0, TAU, 12, Color(0.55, 0.88, 1.0, 0.65 * (1.0 - rip_p)), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Ground droplet bounces
		var bounce_p := ground_splash + Vector2(sin(t * 14.0) * 2.0, -2.0 - absf(cos(t * 16.0)) * 3.0)
		draw_circle(bounce_p, 1.2, Color(0.75, 0.95, 1.0, 0.85))

		# Faint 360° ambient mist halo around the sprinkler
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 20, Color(0.45, 0.85, 1.0, 0.18 + 0.08 * sin(t * 3.0)), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_default_building(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var w := PackedVector2Array([
		left * 0.8, bottom * 0.8, bottom * 0.8 + Vector2(0, -36), left * 0.8 + Vector2(0, -36)
	])
	draw_colored_polygon(w, Color(0.55, 0.45, 0.35))
	draw_polyline(w, Color(0.3, 0.2, 0.1), 2.0)

func _draw_scaffold_overlay(top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	# 2.5D Isometric construction timber scaffolding
	var wood := Color(0.80, 0.58, 0.25, 0.95)
	var scaffold_h: float = 55.0
	if building_type in ["water_tower", "drone_station", "weather_station"]:
		scaffold_h = 75.0
	elif building_type == "cold_storage":
		scaffold_h = 65.0

	var p_top    := top + Vector2(0, -scaffold_h)
	var p_right  := right + Vector2(0, -scaffold_h)
	var p_bottom := bottom + Vector2(0, -scaffold_h)
	var p_left   := left + Vector2(0, -scaffold_h)

	# Corner vertical scaffold posts
	draw_line(top, p_top, wood, 3.0)
	draw_line(right, p_right, wood, 3.0)
	draw_line(bottom, p_bottom, wood, 3.0)
	draw_line(left, p_left, wood, 3.0)

	# Diagonal crossbeams
	draw_line(left, p_bottom, wood, 2.0)
	draw_line(bottom, p_left, wood, 2.0)
	draw_line(bottom, p_right, wood, 2.0)
	draw_line(right, p_bottom, wood, 2.0)

	# Top perimeter beam
	draw_polyline(PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top]), wood, 2.5)
