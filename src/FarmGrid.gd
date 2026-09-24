# FarmGrid.gd
# Manages the 12x12 farm grid: tile data, player input, selection, task queuing,
# and farm actions (plow/plant/water/spray/harvest).
#
# Delegates to:
#   TileRenderer        — all visual updates
#   TileAgronomySystem  — daily/hourly crop simulation

extends Node2D

signal tile_inspected(tile_pos: Vector2i, tile_data: FarmTile)
signal selection_inspected(tiles_list: Array, tiles_grid: Array)
signal task_queued(task: Dictionary)

# ---------------------------------------------------------------------------
# Grid constants
# ---------------------------------------------------------------------------
const GRID_SIZE:      Vector2i = Vector2i(12, 12)
const TILE_PIXEL_SIZE: int     = 64
const TILE_BORDER_SIZE: int    = 2

# ---------------------------------------------------------------------------
# Tile data arrays  [x][y]
# ---------------------------------------------------------------------------
var tiles:         Array = []  # FarmTile resource instances
var tile_roots:    Array = []  # Node2D container per tile
var tile_fills:    Array = []  # ColorRect inner fills
var tile_overlays: Array = []  # Node2D procedural texture detail layer
var tile_dots:     Array = []  # ColorRect indicator dots
var tile_labels:   Array = []  # Label icon labels

# ---------------------------------------------------------------------------
# Sub-systems
# ---------------------------------------------------------------------------
var renderer: TileRenderer = null  # Owns all visual update logic

# ---------------------------------------------------------------------------
# Single-tile selection state
# ---------------------------------------------------------------------------
var selected_tile_pos:  Vector2i = Vector2i(-1, -1)
var selection_indicator: Node2D  = null

# ---------------------------------------------------------------------------
# Drag-select (marquee box) state
# ---------------------------------------------------------------------------
var is_box_dragging:  bool    = false
var drag_start_pos:   Vector2 = Vector2.ZERO
var drag_current_pos: Vector2 = Vector2.ZERO
var drag_button_index: int    = -1
const DRAG_THRESHOLD: float   = 8.0

var selected_tiles: Array[Vector2i] = []
var drag_overlay:   Node2D          = null  # Drawn above all tiles (z_index 200)

# ---------------------------------------------------------------------------
# Building Placement & Management State
# ---------------------------------------------------------------------------
var is_placing_building: bool        = false
var placing_building_type: String    = ""
var placing_footprint: Vector2i      = Vector2i(2, 2)
var placing_hover_grid_pos: Vector2i = Vector2i.ZERO
var placement_overlay: Node2D        = null
var building_card_popup: Node        = null

# ---------------------------------------------------------------------------
# Node reference
# ---------------------------------------------------------------------------
@onready var action_popup: PopupMenu = get_node_or_null("../TileActionPopup")


# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	_create_grid()
	_create_selection_indicator()

	renderer = TileRenderer.new()
	renderer.setup(tile_fills, tile_overlays, tile_dots, tile_labels)
	renderer.update_all(tiles, GRID_SIZE)

	# Autoload signals
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	PestManager.pest_spawned.connect(_on_pest_spawned)
	PestManager.pest_cleared.connect(_on_pest_cleared)

	# Popup signals
	if action_popup and action_popup.has_signal("action_selected"):
		action_popup.action_selected.connect(_on_action_popup_selected)
	if action_popup and action_popup.has_signal("batch_action_selected"):
		action_popup.batch_action_selected.connect(_on_batch_action_selected)

	# Tile info panel
	var info_panel = get_node_or_null("../HUDLayer/Control/TileInfoPanel")
	if info_panel:
		if info_panel.has_method("inspect_tile") and not tile_inspected.is_connected(info_panel.inspect_tile):
			tile_inspected.connect(info_panel.inspect_tile)
		if info_panel.has_method("inspect_selection") and not selection_inspected.is_connected(info_panel.inspect_selection):
			selection_inspected.connect(info_panel.inspect_selection)

	# Drag-select overlay — added last so it draws above all tile children
	var overlay_script: GDScript = load("res://src/DragSelectOverlay.gd")
	drag_overlay = Node2D.new()
	drag_overlay.set_script(overlay_script)
	drag_overlay.name        = "DragSelectOverlay"
	drag_overlay.z_index     = 200
	drag_overlay.z_as_relative = false
	add_child(drag_overlay)
	drag_overlay.farm_grid = self

	# Building placement overlay
	var b_overlay_script: GDScript = load("res://src/BuildingPlacementOverlay.gd")
	placement_overlay = Node2D.new()
	placement_overlay.set_script(b_overlay_script)
	placement_overlay.name        = "BuildingPlacementOverlay"
	placement_overlay.z_index     = 210
	placement_overlay.z_as_relative = false
	add_child(placement_overlay)
	placement_overlay.farm_grid = self

	# Building Card Popup (Upgrade & Inspection Modal)
	var card_scene: PackedScene = load("res://scenes/BuildingCardPopup.tscn")
	if card_scene:
		building_card_popup = card_scene.instantiate()
		get_parent().call_deferred("add_child", building_card_popup)

	select_tile.call_deferred(Vector2i(0, 0))

# ---------------------------------------------------------------------------
# Grid construction
# ---------------------------------------------------------------------------
func _create_grid() -> void:
	var region_data:     Dictionary = Data.get_region(Data.current_region)
	var default_moisture: float     = float(region_data.get("soil_moisture", 60))

	tiles.resize(GRID_SIZE.x);         tile_roots.resize(GRID_SIZE.x)
	tile_fills.resize(GRID_SIZE.x);    tile_overlays.resize(GRID_SIZE.x)
	tile_dots.resize(GRID_SIZE.x);     tile_labels.resize(GRID_SIZE.x)

	for x in range(GRID_SIZE.x):
		tiles[x] = [];         tile_roots[x] = []
		tile_fills[x] = [];    tile_overlays[x] = []
		tile_dots[x] = [];     tile_labels[x] = []

		for y in range(GRID_SIZE.y):
			# ── Data ──────────────────────────────────────────────────────
			var tile := FarmTile.new()
			tile.soil_moisture = default_moisture
			tiles[x].append(tile)

			# ── Root node ─────────────────────────────────────────────────
			var root := Node2D.new()
			root.name     = "Tile_%d_%d" % [x, y]
			root.position = Vector2(x, y) * TILE_PIXEL_SIZE
			add_child(root)
			tile_roots[x].append(root)

			# 1. Dark border (64×64)
			var border := ColorRect.new()
			border.color        = TileRenderer.COLOR_BORDER
			border.size         = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(border)

			# 2. Inset fill (60×60)
			var fill := ColorRect.new()
			fill.color        = TileRenderer.COLOR_EMPTY
			fill.size         = Vector2(TILE_PIXEL_SIZE - TILE_BORDER_SIZE * 2, TILE_PIXEL_SIZE - TILE_BORDER_SIZE * 2)
			fill.position     = Vector2(TILE_BORDER_SIZE, TILE_BORDER_SIZE)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(fill)
			tile_fills[x].append(fill)

			# 3. Texture detail overlay
			var overlay := Node2D.new()
			overlay.name = "Overlay"
			root.add_child(overlay)
			tile_overlays[x].append(overlay)

			# 4. Status indicator dot (top-right, 10×10)
			var dot := ColorRect.new()
			dot.size         = Vector2(10, 10)
			dot.position     = Vector2(TILE_PIXEL_SIZE - 14, 4)
			dot.color        = Color.TRANSPARENT
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(dot)
			tile_dots[x].append(dot)

			# 5. Center crop icon label
			var lbl := Label.new()
			lbl.size               = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
			root.add_child(lbl)
			tile_labels[x].append(lbl)

	_seed_natural_obstacles()

func _seed_natural_obstacles() -> void:
	# Clash of Clans style natural obstacles (trees & stumps) that block building/harvesting
	var obstacle_coords: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(2, 9), Vector2i(4, 1),
		Vector2i(7, 10), Vector2i(9, 3), Vector2i(10, 8),
		Vector2i(8, 6), Vector2i(3, 10), Vector2i(10, 2),
		Vector2i(6, 4)
	]
	for c in obstacle_coords:
		if _is_valid(c):
			var t: FarmTile = tiles[c.x][c.y]
			t.state = FarmTile.TileState.OBSTACLE
			t.obstacle_type = "tree"


func _create_selection_indicator() -> void:
	selection_indicator          = Node2D.new()
	selection_indicator.name     = "SelectionIndicator"
	selection_indicator.z_index  = 10
	selection_indicator.visible  = false
	add_child(selection_indicator)

	var gold := Color(1.0, 0.92, 0.20, 1.0)
	var ts   := TILE_PIXEL_SIZE
	var t    := 3

	var _add := func(sz: Vector2, pos: Vector2) -> void:
		var r := ColorRect.new()
		r.size         = sz;  r.position = pos
		r.color        = gold; r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_indicator.add_child(r)

	_add.call(Vector2(ts, t),    Vector2(0, 0))          # top
	_add.call(Vector2(ts, t),    Vector2(0, ts - t))     # bottom
	_add.call(Vector2(t, ts),    Vector2(0, 0))          # left
	_add.call(Vector2(t, ts),    Vector2(ts - t, 0))     # right

	# Soft translucent glow fill
	var fill := ColorRect.new()
	fill.size         = Vector2(ts - 6, ts - 6)
	fill.position     = Vector2(3, 3)
	fill.color        = Color(1.0, 0.95, 0.3, 0.22)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(fill)

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------
func select_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	selected_tile_pos = pos
	if selection_indicator:
		selection_indicator.position = Vector2(pos.x, pos.y) * TILE_PIXEL_SIZE
		selection_indicator.visible  = true
	tile_inspected.emit(pos, tiles[pos.x][pos.y])

# ---------------------------------------------------------------------------
# Mouse input  (marquee drag-select + single tile click)
# ---------------------------------------------------------------------------
func _global_pos_in_grid(gp: Vector2) -> bool:
	var lp := to_local(gp)
	return lp.x >= 0 and lp.x < GRID_SIZE.x * TILE_PIXEL_SIZE \
		and lp.y >= 0 and lp.y < GRID_SIZE.y * TILE_PIXEL_SIZE

## Check if any modal or overlay panel is currently open
func _is_any_menu_open() -> bool:
	var hud_layer = get_node_or_null("../HUDLayer")
	if hud_layer:
		var market = hud_layer.get_node_or_null("Control/MarketPanel")
		if market and market.visible:
			return true
		var shop = hud_layer.get_node_or_null("Control/ShopPanel")
		if shop and shop.visible:
			return true
	var admin = get_node_or_null("../AdminPanel")
	if admin and admin.visible:
		return true
	return false

## Global input: used for marquee dragging motion and building placement hover tracking
func _input(event: InputEvent) -> void:
	if is_placing_building and event is InputEventMouseMotion:
		var gpos := FarmerMovement.pixel_to_grid(get_global_mouse_position(), self)
		if gpos != placing_hover_grid_pos:
			placing_hover_grid_pos = gpos
			if placement_overlay:
				placement_overlay.queue_redraw()

	if not is_box_dragging:
		return

	if event is InputEventMouseMotion:
		drag_current_pos = to_local(get_global_mouse_position())
		if drag_overlay:
			drag_overlay.queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == drag_button_index:
			_finish_drag(mb)
			get_viewport().set_input_as_handled()
			return

func _find_farmer_at(gp: Vector2) -> Node:
	var farmers := get_tree().get_nodes_in_group("farmers")
	var best_farmer: Node = null
	var best_dist: float = 32.0  # Click tolerance radius in pixels
	for f in farmers:
		if not is_instance_valid(f):
			continue
		var dist: float = f.global_position.distance_to(gp)
		if dist < best_dist:
			best_dist = dist
			best_farmer = f
	return best_farmer

## Unhandled input: only fires if NO UI control or HUD button on screen absorbed the mouse click
func _unhandled_input(event: InputEvent) -> void:
	if _is_any_menu_open():
		if is_box_dragging:
			is_box_dragging = false
			if drag_overlay:
				drag_overlay.queue_redraw()
		return

	# Handle building placement clicks
	if is_placing_building:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_building_placement()
			get_viewport().set_input_as_handled()
			return

		if event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				place_building(placing_hover_grid_pos, placing_building_type)
				get_viewport().set_input_as_handled()
				return
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				cancel_building_placement()
				get_viewport().set_input_as_handled()
				return

	# Handle Escape to clear worker selection
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if TaskManager.get_selected_farmers().size() > 0:
			TaskManager.deselect_all_farmers()
			get_viewport().set_input_as_handled()
			return

	# Press — begin drag tracking or single click
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return

		var world_mouse := get_global_mouse_position()

		# Left-click on worker: select worker (supports Ctrl+click for multi-selection)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var clicked_worker = _find_farmer_at(world_mouse)
			if clicked_worker != null:
				var is_multi: bool = mb.is_command_or_control_pressed() or mb.shift_pressed
				TaskManager.select_farmer(clicked_worker, is_multi)
				get_viewport().set_input_as_handled()
				return

			# Left-click on placed building: open building upgrade card
			var clicked_building := BuildingManager.get_building_at_tile(FarmerMovement.pixel_to_grid(world_mouse, self))
			if clicked_building != null:
				_on_building_clicked(clicked_building)
				get_viewport().set_input_as_handled()
				return

		if not _global_pos_in_grid(world_mouse):
			return
		drag_start_pos    = to_local(world_mouse)
		drag_current_pos  = drag_start_pos
		drag_button_index = mb.button_index
		is_box_dragging   = true
		get_viewport().set_input_as_handled()
		return

func _finish_drag(mb: InputEventMouseButton) -> void:
	var release_local := to_local(get_global_mouse_position())
	var drag_dist     := release_local.distance_to(drag_start_pos)

	is_box_dragging = false
	if drag_overlay:
		drag_overlay.queue_redraw()

	if drag_dist > DRAG_THRESHOLD:
		# ── Multi-tile marquee select ─────────────────────────────────
		var new_tiles := _get_drag_rect_tiles(drag_start_pos, release_local)
		if new_tiles.size() == 1:
			selected_tiles.clear()
			if drag_overlay:
				drag_overlay.queue_redraw()
			select_tile(new_tiles[0])
			if mb.button_index == MOUSE_BUTTON_RIGHT and action_popup:
				action_popup.open_for_tile(mb.global_position, new_tiles[0], tiles[new_tiles[0].x][new_tiles[0].y])
		elif new_tiles.size() > 1:
			selected_tiles = new_tiles
			if selection_indicator:
				selection_indicator.visible = false
			if drag_overlay:
				drag_overlay.queue_redraw()
			selection_inspected.emit(selected_tiles, tiles)
			if mb.button_index == MOUSE_BUTTON_RIGHT and action_popup:
				action_popup.open_for_batch(mb.global_position, selected_tiles, tiles)
	else:
		# ── Single tile click ─────────────────────────────────────────
		var gx := int(floor(drag_start_pos.x / float(TILE_PIXEL_SIZE)))
		var gy := int(floor(drag_start_pos.y / float(TILE_PIXEL_SIZE)))
		if not _is_valid(Vector2i(gx, gy)):
			return

		var tile_pos := Vector2i(gx, gy)

		if mb.button_index == MOUSE_BUTTON_LEFT:
			selected_tiles.clear()
			if drag_overlay:
				drag_overlay.queue_redraw()
			select_tile(tile_pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if selected_tiles.size() > 1 and selected_tiles.has(tile_pos):
				if action_popup:
					action_popup.open_for_batch(mb.global_position, selected_tiles, tiles)
			else:
				selected_tiles.clear()
				if drag_overlay:
					drag_overlay.queue_redraw()
				select_tile(tile_pos)
				if action_popup:
					action_popup.open_for_tile(mb.global_position, tile_pos, tiles[gx][gy])

func _get_drag_rect_tiles(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var gx_min := int(floor(min(a.x, b.x) / float(TILE_PIXEL_SIZE)))
	var gx_max := int(floor(max(a.x, b.x) / float(TILE_PIXEL_SIZE)))
	var gy_min := int(floor(min(a.y, b.y) / float(TILE_PIXEL_SIZE)))
	var gy_max := int(floor(max(a.y, b.y) / float(TILE_PIXEL_SIZE)))
	for gx in range(gx_min, gx_max + 1):
		for gy in range(gy_min, gy_max + 1):
			var pos := Vector2i(gx, gy)
			if _is_valid(pos):
				result.append(pos)
	return result

# ---------------------------------------------------------------------------
# Task popup callbacks
# ---------------------------------------------------------------------------
func _on_action_popup_selected(action_type: String, tile_pos: Vector2i, extra: Dictionary) -> void:
	if action_type == "clear_obstacle":
		var cost: int = int(extra.get("cost", 50))
		if not EconomyManager.deduct_cash(cost):
			return
	var task: Dictionary = {"type": action_type, "position": tile_pos}
	task.merge(extra)
	TaskManager.assign_tasks([task])
	task_queued.emit(task)

func _on_batch_action_selected(action_type: String, target_tiles: Array, extra: Dictionary) -> void:
	var tasks: Array = []
	for pos in target_tiles:
		if not _is_valid(pos) or TaskManager.has_task_at(pos, action_type):
			continue
		if action_type == "clear_obstacle":
			var cost: int = int(extra.get("cost", 50))
			if not EconomyManager.deduct_cash(cost):
				break
		var task: Dictionary = {"type": action_type, "position": pos}
		task.merge(extra)
		tasks.append(task)
	TaskManager.assign_tasks(tasks)
	for t in tasks:
		task_queued.emit(t)

# ---------------------------------------------------------------------------
# Farm actions  (public API — called by Farmer workers)
# ---------------------------------------------------------------------------
func plow_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING:
		return # Blocked by tree obstacle or placed building
	tile.reset()
	tile.state = FarmTile.TileState.PLOWED
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)

func plant_crop(pos: Vector2i, crop_name: String) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING:
		return # Blocked by tree obstacle or placed building
	if tile.state != FarmTile.TileState.PLOWED and tile.state != FarmTile.TileState.EMPTY:
		return


	var crop_data: Dictionary = Data.get_crop(crop_name)
	if not EconomyManager.deduct_cash(int(crop_data.get("seed_cost", 25))):
		print("[FarmGrid] Not enough cash to plant %s!" % crop_name)
		return

	var region_data: Dictionary = Data.get_region(Data.current_region)
	tile.crop_type       = crop_name
	tile.state           = FarmTile.TileState.PLANTED
	tile.growth_progress = 0.0
	tile.health          = 1.0
	tile.quality         = FarmTile.QualityGrade.A
	tile.soil_moisture   = float(region_data.get("soil_moisture", 60))
	tile.days_overwatered = 0
	tile.pest_type       = ""

	PestManager.evaluate_spawn(pos, crop_name, int(tile.soil_moisture))
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)

func water_tile(pos: Vector2i, amount: float = 25.0) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING:
		return
	tile.soil_moisture = clampf(tile.soil_moisture + amount, 0.0, 100.0)
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)

func spray_pest(pos: Vector2i, method: String) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.FLOODED \
		or tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING:
		return

	var cost: int = 30 if method == "chemical" else 45
	if not EconomyManager.deduct_cash(cost):
		return

	match method:
		"chemical":
			# Caps quality at B, degrades soil fertility
			tile.pest_type = ""
			if tile.quality == FarmTile.QualityGrade.A:
				tile.quality = FarmTile.QualityGrade.B
			tile.soil_fertility = maxf(tile.soil_fertility - 0.10, 0.4)
			tile.soil_moisture  = maxf(tile.soil_moisture  - 10.0,  0.0)
		"biological":
			# Organic — preserves Grade A and soil fertility
			tile.pest_type = ""
		_:
			tile.pest_type = ""

	tile.state = FarmTile.TileState.HARVESTABLE if tile.growth_progress >= 1.0 else FarmTile.TileState.GROWING if tile.crop_type != "" else FarmTile.TileState.EMPTY

	PestManager.treat_tile(pos, method)
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)

func harvest_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING \
		or tile.crop_type == "" or tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.PLOWED:
		return

	var harvest_info: Dictionary = TileAgronomySystem.calculate_harvest(tile)
	var quantity: int = int(harvest_info.get("yield", 0))
	var grade_str: String = str(harvest_info.get("grade_string", "Grade C"))

	# Deposit into Farm Storage
	MarketManager.add_harvest_to_storage(tile.crop_type, quantity, grade_str, 100.0)
	tile.reset()
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)

func clear_obstacle(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state != FarmTile.TileState.OBSTACLE:
		return
	tile.reset()
	tile.state = FarmTile.TileState.EMPTY
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)
	# Clash of Clans resource bonus for clearing obstacles (salvage ₱15)
	EconomyManager.add_cash(15)


# ---------------------------------------------------------------------------
# Time & climate callbacks  (delegate heavy simulation to TileAgronomySystem)
# ---------------------------------------------------------------------------
func _on_day_changed(_day: int) -> void:
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
				TileAgronomySystem.process_day(tile, Vector2i(x, y))
	renderer.update_all(tiles, GRID_SIZE)

func _on_hour_changed(_hour: int) -> void:
	var has_drip: bool = BuildingManager.has_tech("drip_irrigation")
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			TileAgronomySystem.process_hour(tiles[x][y], has_drip)
	renderer.update_all(tiles, GRID_SIZE)

func _on_pest_spawned(pest: String, pos: Vector2i) -> void:
	if _is_valid(pos):
		tiles[pos.x][pos.y].state    = FarmTile.TileState.INFECTED
		tiles[pos.x][pos.y].pest_type = pest
		renderer.update_tile(pos, tiles)

func _on_pest_cleared(_pest: String, pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	tile.pest_type = ""
	tile.state = FarmTile.TileState.HARVESTABLE if tile.growth_progress >= 1.0 and tile.crop_type != "" \
		else FarmTile.TileState.GROWING if tile.crop_type != "" \
		else FarmTile.TileState.EMPTY
	renderer.update_tile(pos, tiles)

func _on_weather_changed(_t: float, _h: float) -> void: pass
func _on_disaster_warning(_h: String) -> void: pass

# ---------------------------------------------------------------------------
# Building Placement  (public API — called by ShopPanel)
# ---------------------------------------------------------------------------

## Begin placement mode: player drags ghost footprint to choose where to build.
func start_building_placement(b_type: String) -> void:
	var b_data: Dictionary = Data.get_building(b_type)
	if b_data.is_empty():
		push_warning("[FarmGrid] Unknown building type: %s" % b_type)
		return

	is_placing_building   = true
	placing_building_type = b_type
	placing_footprint     = b_data.get("grid_size", Vector2i(2, 2))

	# Seed the hover position to grid centre so overlay appears immediately
	placing_hover_grid_pos = Vector2i(
		GRID_SIZE.x / 2 - placing_footprint.x / 2,
		GRID_SIZE.y / 2 - placing_footprint.y / 2
	)

	if placement_overlay:
		placement_overlay.queue_redraw()

## Cancel placement mode without building anything.
func cancel_building_placement() -> void:
	is_placing_building   = false
	placing_building_type = ""
	if placement_overlay:
		placement_overlay.queue_redraw()

## Returns true if the given footprint starting at start_pos is fully within bounds
## and every tile is free (not OBSTACLE, not BUILDING, not FLOODED).
func is_valid_building_placement(start_pos: Vector2i, fp: Vector2i) -> bool:
	for dx in range(fp.x):
		for dy in range(fp.y):
			var check := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if not _is_valid(check):
				return false
			var tile: FarmTile = tiles[check.x][check.y]
			if tile.state == FarmTile.TileState.OBSTACLE \
				or tile.state == FarmTile.TileState.BUILDING \
				or tile.state == FarmTile.TileState.FLOODED:
				return false
	return true

## Attempt to place the building at start_pos.  Returns true on success.
func place_building(start_pos: Vector2i, b_type: String) -> bool:
	var b_data: Dictionary = Data.get_building(b_type)
	if b_data.is_empty():
		return false

	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))

	if not is_valid_building_placement(start_pos, fp):
		if placement_overlay:
			placement_overlay.queue_redraw()
		return false

	# Deduct cost
	var cost: int = int(b_data.get("cost", 400))
	if not EconomyManager.deduct_cash(cost):
		return false

	# Mark tiles as BUILDING
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			tiles[tp.x][tp.y].state        = FarmTile.TileState.BUILDING
			tiles[tp.x][tp.y].building_ref = null

	# Instantiate Building node
	var b_script: GDScript = load("res://src/Building.gd")
	var building := Node2D.new()
	building.set_script(b_script)
	building.name          = "Building_%s_%d_%d" % [b_type, start_pos.x, start_pos.y]
	building.building_type = b_type
	building.grid_pos      = start_pos
	building.footprint     = fp
	building.duration      = float(b_data.get("build_time", 20.0))

	add_child(building)

	# Store back-reference in every occupied tile
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			tiles[tp.x][tp.y].building_ref = building

	# Connect lifecycle signals
	if building.has_signal("clicked") and not building.clicked.is_connected(_on_building_clicked):
		building.clicked.connect(_on_building_clicked)
	if building.has_signal("demolished") and not building.demolished.is_connected(_on_building_demolished):
		building.demolished.connect(_on_building_demolished)

	# Register in BuildingManager
	BuildingManager.register_building(building)

	# Renderer update for all affected tiles
	for dx in range(fp.x):
		for dy in range(fp.y):
			renderer.update_tile(Vector2i(start_pos.x + dx, start_pos.y + dy), tiles)

	# Exit placement mode
	cancel_building_placement()
	return true

## Open the upgrade/inspect card for a placed building.
func _on_building_clicked(building: Node) -> void:
	if building_card_popup and is_instance_valid(building_card_popup):
		building_card_popup.open_for_building(building)

## Called when a building is demolished — free tiles and update renderer.
func _on_building_demolished(building: Node) -> void:
	if not is_instance_valid(building):
		return

	var fp: Vector2i = building.footprint
	var gp: Vector2i = building.grid_pos

	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(gp.x + dx, gp.y + dy)
			if _is_valid(tp):
				tiles[tp.x][tp.y].state        = FarmTile.TileState.EMPTY
				tiles[tp.x][tp.y].building_ref  = null
				renderer.update_tile(tp, tiles)

	BuildingManager.unregister_building(building)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y
