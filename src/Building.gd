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

const TILE_SIZE: int = 64

# UI nodes
var progress_bar: ProgressBar = null
var progress_label: Label     = null
var level_label: Label        = null

func _ready() -> void:
	z_index = 40  # Render above ground tiles, below marquee drag overlay
	position = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)

	var b_data: Dictionary = Data.get_building(building_type)
	if not b_data.is_empty():
		footprint = b_data.get("grid_size", Vector2i(2, 2))
		max_level = int(b_data.get("max_level", 3))

	_setup_ui()
	queue_redraw()

func _setup_ui() -> void:
	var total_w: float = float(footprint.x * TILE_SIZE)
	var total_h: float = float(footprint.y * TILE_SIZE)

	# Level indicator badge at top-left
	level_label = Label.new()
	level_label.position = Vector2(4, 4)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	add_child(level_label)

	# Overhead Construction/Upgrade Progress Bar
	var pbox := VBoxContainer.new()
	pbox.name = "ProgressBox"
	pbox.position = Vector2(0, -28)
	pbox.custom_minimum_size = Vector2(total_w, 24)
	pbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pbox)

	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	pbox.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(total_w, 8)
	progress_bar.max_value = 100.0
	progress_bar.show_percentage = false
	pbox.add_child(progress_bar)

	_update_ui_state()

func _process(delta: float) -> void:
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
	state_changed.emit(self)

func start_upgrade(up_cost: int, up_duration: float) -> bool:
	if state != BuildingState.ACTIVE or level >= max_level:
		return false
	if not EconomyManager.deduct_cash(up_cost):
		return false

	state          = BuildingState.UPGRADING
	duration       = up_duration
	progress_timer = 0.0
	_update_ui_state()
	state_changed.emit(self)
	return true

func complete_upgrade() -> void:
	level          += 1
	state          = BuildingState.ACTIVE
	progress_timer = 0.0
	_update_ui_state()
	BuildingManager.recalculate_bonuses()
	state_changed.emit(self)

func demolish() -> void:
	var b_data := Data.get_building(building_type)
	var base_cost: int = int(b_data.get("cost", 200))
	var refund: int = int(base_cost * 0.5 * level)
	EconomyManager.add_cash(refund)
	demolished.emit(self)
	queue_free()

# ---------------------------------------------------------------------------
# Rendering: Procedural Clash of Clans / WoW Strategy Art
# ---------------------------------------------------------------------------
func _draw() -> void:
	var w: float = float(footprint.x * TILE_SIZE)
	var h: float = float(footprint.y * TILE_SIZE)

	# 1. Foundation Platform (Base)
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.28, 0.22, 0.16, 0.95), true)
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.18, 0.14, 0.10, 1.0), false, 2.0)

	# 2. Draw building-specific artwork
	match building_type:
		"bahay_kubo":
			_draw_bahay_kubo(w, h)
		"bodega":
			_draw_bodega(w, h)
		"cold_storage":
			_draw_cold_storage(w, h)
		"solar_dryer":
			_draw_solar_dryer(w, h)
		"machine_garage":
			_draw_garage(w, h)
		"climate_silo":
			_draw_silo(w, h)
		_:
			_draw_default_building(w, h)

	# 3. Construction Scaffold Overlay (if building or upgrading)
	if state == BuildingState.CONSTRUCTING or state == BuildingState.UPGRADING:
		_draw_scaffold_overlay(w, h)

func _draw_bahay_kubo(w: float, h: float) -> void:
	# Bamboo stilt posts
	var stilt_col := Color(0.48, 0.36, 0.18)
	draw_rect(Rect2(12, h - 24, 8, 20), stilt_col, true)
	draw_rect(Rect2(w - 20, h - 24, 8, 20), stilt_col, true)
	draw_rect(Rect2(w * 0.5 - 4, h - 24, 8, 20), stilt_col, true)

	# Woven bamboo sawali walls
	var wall_rect := Rect2(10, 24, w - 20, h - 48)
	draw_rect(wall_rect, Color(0.72, 0.58, 0.32), true)
	draw_rect(wall_rect, Color(0.40, 0.28, 0.12), false, 2.0)

	# Door & Window
	draw_rect(Rect2(w * 0.5 - 10, h - 48, 20, 24), Color(0.32, 0.20, 0.08), true)
	draw_rect(Rect2(18, 36, 16, 16), Color(0.85, 0.95, 1.0, 0.8), true)

	# Thatched Nipa Palm Roof (Pyramid pitch)
	var roof_pts := PackedVector2Array([
		Vector2(w * 0.5, 2),
		Vector2(w + 4, 28),
		Vector2(-4, 28)
	])
	draw_colored_polygon(roof_pts, Color(0.82, 0.68, 0.28))
	draw_polyline(roof_pts, Color(0.50, 0.38, 0.12), 2.0)

	# Roof ridges / straw texture lines
	draw_line(Vector2(w * 0.5, 4), Vector2(10, 26), Color(0.65, 0.52, 0.20), 1.5)
	draw_line(Vector2(w * 0.5, 4), Vector2(w - 10, 26), Color(0.65, 0.52, 0.20), 1.5)

func _draw_bodega(w: float, h: float) -> void:
	# Concrete foundation base
	draw_rect(Rect2(6, 16, w - 12, h - 24), Color(0.55, 0.52, 0.48), true)

	# Corrugated warehouse metal siding
	draw_rect(Rect2(10, 26, w - 20, h - 38), Color(0.70, 0.35, 0.25), true)
	# Corrugated ribs
	for x in range(16, int(w - 20), 14):
		draw_line(Vector2(x, 26), Vector2(x, h - 14), Color(0.50, 0.22, 0.15), 1.5)

	# Large sliding cargo bay door with hazard stripes
	var door_rect := Rect2(w * 0.5 - 32, h - 54, 64, 40)
	draw_rect(door_rect, Color(0.22, 0.24, 0.28), true)
	draw_rect(door_rect, Color(0.85, 0.70, 0.15), false, 2.5)

	# Gabled warehouse roof
	var roof_pts := PackedVector2Array([
		Vector2(w * 0.5, 4),
		Vector2(w - 2, 26),
		Vector2(2, 26)
	])
	draw_colored_polygon(roof_pts, Color(0.35, 0.40, 0.48))
	draw_polyline(roof_pts, Color(0.20, 0.25, 0.32), 2.5)

func _draw_cold_storage(w: float, h: float) -> void:
	# Clean insulated industrial refrigeration facility
	draw_rect(Rect2(8, 20, w - 16, h - 30), Color(0.80, 0.88, 0.95), true)
	draw_rect(Rect2(8, 20, w - 16, h - 30), Color(0.35, 0.55, 0.75), false, 2.5)

	# Heavy airtight cold-vault door
	draw_rect(Rect2(w * 0.5 - 28, h - 58, 56, 46), Color(0.40, 0.50, 0.62), true)
	draw_rect(Rect2(w * 0.5 - 28, h - 58, 56, 46), Color(0.20, 0.35, 0.50), false, 2.0)
	# Vault spin handle
	draw_circle(Vector2(w * 0.5 + 16, h - 35), 5.0, Color(0.85, 0.90, 0.95))

	# Industrial AC condenser fans on left
	draw_circle(Vector2(26, 46), 12.0, Color(0.30, 0.42, 0.55))
	draw_circle(Vector2(26, 76), 12.0, Color(0.30, 0.42, 0.55))

	# Tiled insulated cooling roof with snowflake motif
	var roof_pts := PackedVector2Array([
		Vector2(w * 0.5, 4),
		Vector2(w - 2, 22),
		Vector2(2, 22)
	])
	draw_colored_polygon(roof_pts, Color(0.25, 0.45, 0.72))
	draw_polyline(roof_pts, Color(0.15, 0.30, 0.55), 2.0)

func _draw_solar_dryer(w: float, h: float) -> void:
	# Polished concrete drying pavement (Bilaran)
	draw_rect(Rect2(6, 6, w - 12, h - 12), Color(0.72, 0.70, 0.65), true)
	draw_rect(Rect2(6, 6, w - 12, h - 12), Color(0.45, 0.42, 0.38), false, 2.5)

	# Spread-out golden grain patches (drying palay mats)
	draw_rect(Rect2(16, 16, w * 0.45, h * 0.38), Color(0.92, 0.80, 0.25, 0.9), true)
	draw_rect(Rect2(w * 0.52, 18, w * 0.38, h * 0.42), Color(0.92, 0.80, 0.25, 0.9), true)
	draw_rect(Rect2(20, h * 0.56, w * 0.65, h * 0.32), Color(0.92, 0.80, 0.25, 0.9), true)

func _draw_garage(w: float, h: float) -> void:
	# Heavy vehicle workshop
	draw_rect(Rect2(6, 14, w - 12, h - 22), Color(0.38, 0.42, 0.46), true)
	draw_rect(Rect2(6, 14, w - 12, h - 22), Color(0.20, 0.24, 0.28), false, 2.5)

	# Dual roll-up bay doors
	var bay_w: float = (w - 36) * 0.5
	draw_rect(Rect2(14, 28, bay_w, h - 38), Color(0.65, 0.68, 0.72), true)
	draw_rect(Rect2(22 + bay_w, 28, bay_w, h - 38), Color(0.65, 0.68, 0.72), true)

	# Overhead corrugated metal visor
	draw_rect(Rect2(4, 8, w - 8, 14), Color(0.75, 0.28, 0.20), true)

func _draw_silo(w: float, h: float) -> void:
	# Giant cylindrical corrugated grain silo
	var center_x: float = w * 0.5
	var tank_rect := Rect2(center_x - 48, 36, 96, h - 46)
	draw_rect(tank_rect, Color(0.76, 0.80, 0.85), true)
	draw_rect(tank_rect, Color(0.40, 0.45, 0.52), false, 2.5)

	# Horizontal steel rings
	for y in range(48, int(h - 16), 18):
		draw_line(Vector2(center_x - 48, y), Vector2(center_x + 48, y), Color(0.55, 0.60, 0.68), 1.5)

	# Silo conical dome roof
	var dome_pts := PackedVector2Array([
		Vector2(center_x, 6),
		Vector2(center_x + 52, 36),
		Vector2(center_x - 52, 36)
	])
	draw_colored_polygon(dome_pts, Color(0.60, 0.65, 0.72))
	draw_polyline(dome_pts, Color(0.35, 0.40, 0.48), 2.0)

func _draw_default_building(w: float, h: float) -> void:
	draw_rect(Rect2(8, 16, w - 16, h - 24), Color(0.6, 0.5, 0.4), true)
	draw_rect(Rect2(8, 16, w - 16, h - 24), Color(0.3, 0.2, 0.1), false, 2.0)

func _draw_scaffold_overlay(w: float, h: float) -> void:
	# Translucent construction veil
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.1, 0.35), true)

	# Wooden scaffold cross-beams
	var wood := Color(0.78, 0.55, 0.24, 0.95)
	draw_line(Vector2(0, 0), Vector2(w, h), wood, 3.0)
	draw_line(Vector2(w, 0), Vector2(0, h), wood, 3.0)

	# Safety warning perimeter border (yellow & black stripes)
	draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.85, 0.15, 0.9), false, 3.0)
