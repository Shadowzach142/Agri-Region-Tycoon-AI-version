# FarmGrid.gd
# Node2D managing 12x12 farm tiles, visual rendering, tile borders, and task queuing.

extends Node2D

signal tile_inspected(tile_pos: Vector2i, tile_data: FarmTile)
signal task_queued(task: Dictionary)

const GRID_SIZE: Vector2i = Vector2i(12, 12)
const TILE_PIXEL_SIZE: int = 64
const TILE_BORDER_SIZE: int = 2

# 2-D arrays [x][y]
var tiles: Array = []        # FarmTile resource instances
var tile_roots: Array = []    # Node2D containers per tile
var tile_fills: Array = []    # ColorRect inner fills
var tile_overlays: Array = [] # Node2D procedural texture detail layer
var tile_dots: Array = []     # ColorRect indicator dots
var tile_labels: Array = []   # Label icon labels

# Palette colors
const COLOR_BORDER: Color = Color(0.12, 0.12, 0.10, 1.0)
const COLOR_EMPTY: Color = Color(0.35, 0.58, 0.28, 1.0)       # Grass green
const COLOR_PLOWED: Color = Color(0.46, 0.30, 0.18, 1.0)      # Cultivated soil brown
const COLOR_PLANTED: Color = Color(0.24, 0.45, 0.18, 1.0)     # Seedling green
const COLOR_GROWING: Color = Color(0.30, 0.65, 0.22, 1.0)     # Maturing green
const COLOR_HARVESTABLE: Color = Color(0.88, 0.72, 0.15, 1.0) # Ripe golden yellow
const COLOR_FLOODED: Color = Color(0.15, 0.40, 0.70, 1.0)     # Rot / flood water
const COLOR_INFECTED: Color = Color(0.75, 0.20, 0.20, 1.0)    # Pest danger red

# Selection Highlight (single tile)
var selected_tile_pos: Vector2i = Vector2i(-1, -1)
var selection_indicator: Node2D = null

# Drag-select (marquee box) state
var is_box_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_current_pos: Vector2 = Vector2.ZERO
var drag_button_index: int = -1
const DRAG_THRESHOLD: float = 8.0

# Multi-tile selection
var selected_tiles: Array[Vector2i] = []

@onready var action_popup: PopupMenu = get_node_or_null("../TileActionPopup")

func _ready() -> void:
	_create_grid()
	_create_selection_indicator()
	
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	PestManager.pest_spawned.connect(_on_pest_spawned)
	PestManager.pest_cleared.connect(_on_pest_cleared)

	if action_popup and action_popup.has_signal("action_selected"):
		action_popup.action_selected.connect(_on_action_popup_selected)
	if action_popup and action_popup.has_signal("batch_action_selected"):
		action_popup.batch_action_selected.connect(_on_batch_action_selected)

	var info_panel = get_node_or_null("../HUDLayer/Control/TileInfoPanel")
	if info_panel and info_panel.has_method("inspect_tile"):
		if not tile_inspected.is_connected(info_panel.inspect_tile):
			tile_inspected.connect(info_panel.inspect_tile)

	# Call select_tile deferred so child and HUD nodes finish ready initialization
	select_tile.call_deferred(Vector2i(0, 0))

func _create_selection_indicator() -> void:
	selection_indicator = Node2D.new()
	selection_indicator.name = "SelectionIndicator"
	selection_indicator.z_index = 10
	selection_indicator.visible = false
	add_child(selection_indicator)

	var highlight_color: Color = Color(1.0, 0.92, 0.20, 1.0) # Vibrant gold border

	# Top border bar (thickness 3)
	var top: ColorRect = ColorRect.new()
	top.size = Vector2(TILE_PIXEL_SIZE, 3)
	top.position = Vector2.ZERO
	top.color = highlight_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(top)

	# Bottom border bar (thickness 3)
	var btm: ColorRect = ColorRect.new()
	btm.size = Vector2(TILE_PIXEL_SIZE, 3)
	btm.position = Vector2(0, TILE_PIXEL_SIZE - 3)
	btm.color = highlight_color
	btm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(btm)

	# Left border bar (thickness 3)
	var left: ColorRect = ColorRect.new()
	left.size = Vector2(3, TILE_PIXEL_SIZE)
	left.position = Vector2.ZERO
	left.color = highlight_color
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(left)

	# Right border bar (thickness 3)
	var right: ColorRect = ColorRect.new()
	right.size = Vector2(3, TILE_PIXEL_SIZE)
	right.position = Vector2(TILE_PIXEL_SIZE - 3, 0)
	right.color = highlight_color
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(right)

	# Soft translucent golden glow fill
	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(TILE_PIXEL_SIZE - 6, TILE_PIXEL_SIZE - 6)
	fill.position = Vector2(3, 3)
	fill.color = Color(1.0, 0.95, 0.3, 0.22)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_indicator.add_child(fill)

func select_tile(pos: Vector2i) -> void:
	if not _is_valid_pos(pos):
		return
	selected_tile_pos = pos
	if selection_indicator:
		selection_indicator.position = Vector2(pos.x, pos.y) * TILE_PIXEL_SIZE
		selection_indicator.visible = true
	var tile: FarmTile = tiles[pos.x][pos.y]
	tile_inspected.emit(pos, tile)

func _create_grid() -> void:
	var region_data: Dictionary = Data.get_region(Data.current_region)
	var default_moisture: float = float(region_data.get("soil_moisture", 60))

	tiles.resize(GRID_SIZE.x)
	tile_roots.resize(GRID_SIZE.x)
	tile_fills.resize(GRID_SIZE.x)
	tile_overlays.resize(GRID_SIZE.x)
	tile_dots.resize(GRID_SIZE.x)
	tile_labels.resize(GRID_SIZE.x)

	for x in range(GRID_SIZE.x):
		tiles[x] = []
		tile_roots[x] = []
		tile_fills[x] = []
		tile_overlays[x] = []
		tile_dots[x] = []
		tile_labels[x] = []

		for y in range(GRID_SIZE.y):
			var tile: FarmTile = FarmTile.new()
			tile.soil_moisture = default_moisture
			tiles[x].append(tile)

			# Parent node for the tile
			var root: Node2D = Node2D.new()
			root.name = "Tile_%d_%d" % [x, y]
			root.position = Vector2(x, y) * TILE_PIXEL_SIZE
			add_child(root)
			tile_roots[x].append(root)

			# 1. Dark outer border (64x64)
			var border: ColorRect = ColorRect.new()
			border.color = COLOR_BORDER
			border.size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			border.position = Vector2.ZERO
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(border)

			# 2. Inset fill (60x60) leaving clean 2px border
			var fill: ColorRect = ColorRect.new()
			fill.color = COLOR_EMPTY
			fill.size = Vector2(TILE_PIXEL_SIZE - TILE_BORDER_SIZE * 2, TILE_PIXEL_SIZE - TILE_BORDER_SIZE * 2)
			fill.position = Vector2(TILE_BORDER_SIZE, TILE_BORDER_SIZE)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(fill)
			tile_fills[x].append(fill)

			# 3. Procedural texture detail overlay layer
			var overlay: Node2D = Node2D.new()
			overlay.name = "Overlay"
			root.add_child(overlay)
			tile_overlays[x].append(overlay)

			# 4. Status indicator dot (top-right, 10x10)
			var dot: ColorRect = ColorRect.new()
			dot.size = Vector2(10, 10)
			dot.position = Vector2(TILE_PIXEL_SIZE - 14, 4)
			dot.color = Color.TRANSPARENT
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(dot)
			tile_dots[x].append(dot)

			# 4. Center icon label for crop/action visual
			var lbl: Label = Label.new()
			lbl.size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			lbl.position = Vector2.ZERO
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.text = ""
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(lbl)
			tile_labels[x].append(lbl)

	_update_visuals()

# ---------------------------------------------------------------------------
# Mouse Input Handling  (marquee drag-select + single tile click)
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse Button Press: start drag tracking ---
	if event is InputEventMouseButton and event.pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
			var local_pos: Vector2 = get_local_mouse_position()
			is_box_dragging = true
			drag_start_pos = local_pos
			drag_current_pos = local_pos
			drag_button_index = button
			get_viewport().set_input_as_handled()
		return

	# --- Mouse Motion: update drag rectangle in real time ---
	if event is InputEventMouseMotion and is_box_dragging:
		drag_current_pos = get_local_mouse_position()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	# --- Mouse Button Release: commit selection or single-click ---
	if event is InputEventMouseButton and not event.pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if not is_box_dragging or button != drag_button_index:
			return

		var release_pos: Vector2 = get_local_mouse_position()
		var drag_distance: float = release_pos.distance_to(drag_start_pos)

		is_box_dragging = false
		queue_redraw()

		if drag_distance > DRAG_THRESHOLD:
			# === DRAG RELEASE: Marquee multi-select ===
			var new_tiles: Array[Vector2i] = _get_drag_rect_tiles(drag_start_pos, release_pos)
			if new_tiles.size() > 0:
				selected_tiles = new_tiles
				# Keep single selection indicator hidden during multi-select
				if selection_indicator:
					selection_indicator.visible = false
				queue_redraw()

				if button == MOUSE_BUTTON_RIGHT and action_popup:
					action_popup.open_for_batch(
						event.global_position,
						selected_tiles,
						tiles
					)
		else:
			# === SINGLE CLICK ===
			var local_pos: Vector2 = drag_start_pos
			var gx: int = int(floor(local_pos.x / float(TILE_PIXEL_SIZE)))
			var gy: int = int(floor(local_pos.y / float(TILE_PIXEL_SIZE)))

			if not _is_valid_pos(Vector2i(gx, gy)):
				return

			var tile_pos: Vector2i = Vector2i(gx, gy)
			var tile: FarmTile = tiles[gx][gy]

			# Clear multi-selection when clicking a single tile
			selected_tiles.clear()
			queue_redraw()

			if button == MOUSE_BUTTON_LEFT:
				select_tile(tile_pos)

			elif button == MOUSE_BUTTON_RIGHT:
				select_tile(tile_pos)
				if action_popup:
					action_popup.open_for_tile(event.global_position, tile_pos, tile)

		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Draw: Marquee Drag Box + Multi-selection Highlight Overlays
# ---------------------------------------------------------------------------
func _draw() -> void:
	# 1) Draw active drag rectangle
	if is_box_dragging:
		var rect: Rect2 = Rect2(drag_start_pos, drag_current_pos - drag_start_pos).abs()
		draw_rect(rect, Color(0.20, 0.85, 0.35, 0.18), true)
		draw_rect(rect, Color(0.35, 1.0, 0.45, 0.95), false, 2.0)

	# 2) Draw golden highlight boxes over selected tiles (multi-select only)
	if selected_tiles.size() > 0:
		for sel_pos in selected_tiles:
			var tile_rect: Rect2 = Rect2(
				Vector2(sel_pos.x, sel_pos.y) * TILE_PIXEL_SIZE,
				Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			)
			draw_rect(tile_rect, Color(1.0, 0.85, 0.15, 0.22), true)
			draw_rect(tile_rect, Color(1.0, 0.90, 0.20, 0.90), false, 2.5)

# Returns all valid grid positions contained in the rectangle between two local points
func _get_drag_rect_tiles(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_x: float = min(a.x, b.x)
	var max_x: float = max(a.x, b.x)
	var min_y: float = min(a.y, b.y)
	var max_y: float = max(a.y, b.y)

	var gx_min: int = int(floor(min_x / float(TILE_PIXEL_SIZE)))
	var gx_max: int = int(floor(max_x / float(TILE_PIXEL_SIZE)))
	var gy_min: int = int(floor(min_y / float(TILE_PIXEL_SIZE)))
	var gy_max: int = int(floor(max_y / float(TILE_PIXEL_SIZE)))

	for gx in range(gx_min, gx_max + 1):
		for gy in range(gy_min, gy_max + 1):
			var pos: Vector2i = Vector2i(gx, gy)
			if _is_valid_pos(pos):
				result.append(pos)
	return result

func _handle_fast_right_click(tile_pos: Vector2i, tile: FarmTile) -> void:
	var task: Dictionary = {}
	match tile.state:
		FarmTile.TileState.EMPTY:
			task = {"type": "plow", "position": tile_pos}
		FarmTile.TileState.PLOWED:
			# Fast plant default staple (palay)
			task = {"type": "plant", "crop_type": "palay", "position": tile_pos}
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
			if tile.pest_type != "":
				task = {"type": "spray_pest", "method": "chemical", "position": tile_pos}
			elif tile.soil_moisture < 50.0:
				task = {"type": "water", "amount": 25.0, "position": tile_pos}
		FarmTile.TileState.INFECTED:
			task = {"type": "spray_pest", "method": "chemical", "position": tile_pos}
		FarmTile.TileState.HARVESTABLE:
			task = {"type": "harvest", "position": tile_pos}
		FarmTile.TileState.FLOODED:
			task = {"type": "plow", "position": tile_pos}

	if not task.is_empty():
		TaskManager.add_task(task)
		task_queued.emit(task)

func _on_action_popup_selected(action_type: String, tile_pos: Vector2i, extra: Dictionary) -> void:
	var task: Dictionary = {"type": action_type, "position": tile_pos}
	for key in extra.keys():
		task[key] = extra[key]
	TaskManager.add_task(task)
	task_queued.emit(task)

## Batch action handler: queues a task for every eligible tile in the selection
func _on_batch_action_selected(action_type: String, target_tiles: Array, extra: Dictionary) -> void:
	for pos in target_tiles:
		if not _is_valid_pos(pos):
			continue
		# Skip duplicate tasks already in the queue for this position+type
		if TaskManager.has_task_at(pos, action_type):
			continue
		var task: Dictionary = {"type": action_type, "position": pos}
		for key in extra.keys():
			task[key] = extra[key]
		TaskManager.add_task(task)
		task_queued.emit(task)

# ---------------------------------------------------------------------------
# Core Farm Actions (Executed by Farmer Worker)
# ---------------------------------------------------------------------------
func plow_tile(pos: Vector2i) -> void:
	if not _is_valid_pos(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	tile.reset()
	tile.state = FarmTile.TileState.PLOWED
	_update_tile_visual(pos)
	tile_inspected.emit(pos, tile)

func plant_crop(pos: Vector2i, crop_name: String) -> void:
	if not _is_valid_pos(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state != FarmTile.TileState.PLOWED and tile.state != FarmTile.TileState.EMPTY:
		return

	var crop_data: Dictionary = Data.get_crop(crop_name)
	var seed_cost: int = int(crop_data.get("seed_cost", 25))
	if not EconomyManager.deduct_cash(seed_cost):
		print("[FarmGrid] Not enough cash to plant %s!" % crop_name)
		return

	var region_data: Dictionary = Data.get_region(Data.current_region)
	tile.crop_type = crop_name
	tile.state = FarmTile.TileState.PLANTED
	tile.growth_progress = 0.0
	tile.health = 1.0
	tile.quality = FarmTile.QualityGrade.A
	tile.soil_moisture = float(region_data.get("soil_moisture", 60))
	tile.days_overwatered = 0
	tile.pest_type = ""

	PestManager.evaluate_spawn(pos, crop_name, int(tile.soil_moisture))
	_update_tile_visual(pos)
	tile_inspected.emit(pos, tile)

func water_tile(pos: Vector2i, amount: float = 25.0) -> void:
	if not _is_valid_pos(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	tile.soil_moisture = clampf(tile.soil_moisture + amount, 0.0, 100.0)
	_update_tile_visual(pos)
	tile_inspected.emit(pos, tile)

func spray_pest(pos: Vector2i, method: String) -> void:
	if not _is_valid_pos(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.FLOODED:
		return

	var cost: int = 30 if method == "chemical" else 45
	if not EconomyManager.deduct_cash(cost):
		return

	match method:
		"chemical":
			# Immediate, permanently caps quality at Grade B, degrades soil fertility 10%
			tile.pest_type = ""
			if tile.quality == FarmTile.QualityGrade.A:
				tile.quality = FarmTile.QualityGrade.B
			tile.soil_fertility = maxf(tile.soil_fertility - 0.10, 0.4)
			tile.soil_moisture = maxf(tile.soil_moisture - 10.0, 0.0)
		"biological":
			# Cleans organically and preserves Grade A Organic status and soil fertility
			tile.pest_type = ""
		_:
			tile.pest_type = ""

	if tile.crop_type != "":
		tile.state = FarmTile.TileState.HARVESTABLE if tile.growth_progress >= 1.0 else FarmTile.TileState.GROWING
	else:
		tile.state = FarmTile.TileState.EMPTY

	PestManager.treat_tile(pos, method)
	_update_tile_visual(pos)
	tile_inspected.emit(pos, tile)

func harvest_tile(pos: Vector2i) -> void:
	if not _is_valid_pos(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state != FarmTile.TileState.HARVESTABLE:
		return

	var grade_str: String = _grade_to_string(tile.quality)
	var quantity: int = tile.yield_quantity

	# Deposit into Farm Storage
	MarketManager.add_harvest_to_storage(tile.crop_type, quantity, grade_str, 100.0)
	
	tile.reset()
	_update_tile_visual(pos)
	tile_inspected.emit(pos, tile)

# ---------------------------------------------------------------------------
# Time & Climate Engine Logic
# ---------------------------------------------------------------------------
func _on_day_changed(_day: int) -> void:
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
				_process_crop_day(tile, Vector2i(x, y))
	_update_visuals()

func _on_hour_changed(_hour: int) -> void:
	# Hourly evaporation (3x accelerated during El Nino: 1.5/hr vs 0.5/hr baseline)
	var evap: float = 0.5
	if WeatherManager.current_climate == WeatherManager.Climate.EL_NINO:
		evap = 1.5
	
	var has_drip: bool = BuildingManager.has_tech("drip_irrigation")

	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			tile.soil_moisture = maxf(tile.soil_moisture - evap, 0.0)

			# Automated Smart Drip Irrigation: maintains moisture within safe crop thresholds
			if has_drip and (tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING):
				var c_info: Dictionary = Data.get_crop(tile.crop_type)
				var req_min: float = float(c_info.get("water_min", 40))
				if tile.soil_moisture < req_min:
					tile.soil_moisture = req_min + 5.0

			# Palay 12-hour waterlogging check (>95% moisture)
			if tile.crop_type == "palay" and tile.soil_moisture > 95.0:
				tile.hours_waterlogged += 1
				if tile.hours_waterlogged >= 12:
					tile.state = FarmTile.TileState.FLOODED
					tile.growth_progress = 0.0
					tile.yield_quantity = int(tile.yield_quantity * 0.3)
					tile.quality = FarmTile.QualityGrade.C
					tile.health = 0.2
			else:
				tile.hours_waterlogged = 0

	_update_visuals()

func _process_crop_day(tile: FarmTile, _pos: Vector2i) -> void:
	var crop_data: Dictionary = Data.get_crop(tile.crop_type)
	if crop_data.is_empty():
		return

	# Agronomy Rule: Palay halts growth if soil moisture < 30%
	var is_halted: bool = false
	if tile.crop_type == "palay" and tile.soil_moisture < 30.0:
		is_halted = true

	var growth_days: float = float(crop_data.get("growth_days", 30))
	if not is_halted:
		# Soil fertility scales daily growth rate
		var growth_delta: float = (1.0 / growth_days) * tile.soil_fertility
		tile.growth_progress = clampf(tile.growth_progress + growth_delta, 0.0, 1.0)

	if tile.growth_progress >= 1.0:
		tile.state = FarmTile.TileState.HARVESTABLE
		tile.quality = _determine_quality(tile)
	else:
		tile.state = FarmTile.TileState.GROWING

	_apply_climate_effects(tile, crop_data)

	# Pest damage
	if tile.pest_type != "":
		tile.health = maxf(tile.health - 0.15, 0.0)
		tile.yield_quantity = int(tile.yield_quantity * 0.85)
		if tile.health < 0.4:
			tile.quality = FarmTile.QualityGrade.C
		elif tile.health < 0.8:
			tile.quality = FarmTile.QualityGrade.B

func _apply_climate_effects(tile: FarmTile, crop_data: Dictionary) -> void:
	var wm = WeatherManager
	var water_min: float = float(crop_data.get("water_min", 40))
	var water_max: float = float(crop_data.get("water_max", 80))

	# Agronomy Rule: Arabica Coffee flooded tiles permanently kill trees!
	if tile.crop_type == "arabica_coffee" and (tile.soil_moisture >= 90.0 or tile.state == FarmTile.TileState.FLOODED):
		tile.reset()
		return

	match wm.current_climate:
		WeatherManager.Climate.EL_NINO:
			tile.soil_moisture = maxf(tile.soil_moisture - 15.0, 0.0)
			# Yellow Corn resists high temps up to 45°C
			var heat_resilient: bool = (tile.crop_type == "yellow_corn" and wm.temperature <= 45.0)
			if tile.soil_moisture < water_min and not heat_resilient:
				tile.days_without_water += 1
				tile.health = maxf(tile.health - 0.20, 0.0)
				if tile.health < 0.4:
					tile.quality = FarmTile.QualityGrade.C
				elif tile.health < 0.7:
					tile.quality = FarmTile.QualityGrade.B

		WeatherManager.Climate.LA_NINA:
			tile.soil_moisture = minf(tile.soil_moisture + 22.0, 100.0)
			if tile.soil_moisture > water_max:
				tile.days_overwatered += 1
				if tile.soil_moisture >= 90.0:
					# Spec: Soil moisture > 90% causes crop rot, resetting progress and yield drops 50-100%
					tile.state = FarmTile.TileState.FLOODED
					tile.growth_progress = 0.0
					tile.yield_quantity = int(tile.yield_quantity * 0.3)
					tile.quality = FarmTile.QualityGrade.C
					tile.health = 0.2

		WeatherManager.Climate.NORMAL:
			tile.days_without_water = 0
			tile.days_overwatered = 0
			# Maintain moisture toward neutral
			tile.soil_moisture = clampf(tile.soil_moisture + randf_range(-2.0, 4.0), 30.0, 75.0)

# ---------------------------------------------------------------------------
# Visual Updates
# ---------------------------------------------------------------------------
func _update_visuals() -> void:
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			_update_tile_visual(Vector2i(x, y))

func _update_tile_visual(pos: Vector2i) -> void:
	var tile: FarmTile = tiles[pos.x][pos.y]
	var fill: ColorRect = tile_fills[pos.x][pos.y]
	var dot: ColorRect = tile_dots[pos.x][pos.y]
	var lbl: Label = tile_labels[pos.x][pos.y]

	# Base fill color with moisture modulation
	match tile.state:
		FarmTile.TileState.EMPTY:
			if tile.soil_moisture < 35.0:
				fill.color = Color(0.48, 0.58, 0.32) # Dry parched grass
			elif tile.soil_moisture > 75.0:
				fill.color = Color(0.24, 0.44, 0.18) # Deep lush wet meadow
			else:
				fill.color = COLOR_EMPTY
			lbl.text = ""

		FarmTile.TileState.PLOWED:
			if tile.soil_moisture > 70.0:
				fill.color = Color(0.32, 0.20, 0.11) # Dark wet loam
			elif tile.soil_moisture < 35.0:
				fill.color = Color(0.56, 0.42, 0.28) # Dusty dry soil
			else:
				fill.color = COLOR_PLOWED
			lbl.text = ""

		FarmTile.TileState.PLANTED:
			fill.color = COLOR_PLANTED
			var crop_info = Data.get_crop(tile.crop_type)
			lbl.text = crop_info.get("icon", "🌱")

		FarmTile.TileState.GROWING:
			fill.color = COLOR_GROWING.lerp(COLOR_HARVESTABLE, tile.growth_progress * 0.7)
			var crop_info = Data.get_crop(tile.crop_type)
			lbl.text = crop_info.get("icon", "🌿")

		FarmTile.TileState.HARVESTABLE:
			fill.color = COLOR_HARVESTABLE
			var crop_info = Data.get_crop(tile.crop_type)
			lbl.text = crop_info.get("icon", "🌾")

		FarmTile.TileState.FLOODED:
			fill.color = COLOR_FLOODED
			lbl.text = "🌊"

		FarmTile.TileState.INFECTED:
			fill.color = COLOR_INFECTED
			lbl.text = "🐛"

	# Render realistic procedural texture details onto the overlay
	_render_tile_texture(pos, tile)

	# Indicator Dot (Top-Right)
	if tile.pest_type != "" or tile.state == FarmTile.TileState.INFECTED:
		dot.color = Color(0.95, 0.15, 0.15, 1.0) # Red: Pest
	elif tile.state == FarmTile.TileState.HARVESTABLE:
		dot.color = Color(1.0, 0.88, 0.15, 1.0)  # Gold: Ready
	elif tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
		var c_data = Data.get_crop(tile.crop_type)
		if tile.soil_moisture < float(c_data.get("water_min", 40)):
			dot.color = Color(0.25, 0.65, 1.0, 1.0) # Blue: Thirsty
		else:
			dot.color = Color.TRANSPARENT
	else:
		dot.color = Color.TRANSPARENT

func _create_overlay_rect(r_size: Vector2, r_pos: Vector2, r_color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.size = r_size
	r.position = r_pos
	r.color = r_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _render_tile_texture(pos: Vector2i, tile: FarmTile) -> void:
	var overlay: Node2D = tile_overlays[pos.x][pos.y]
	for c in overlay.get_children():
		c.queue_free()

	match tile.state:
		FarmTile.TileState.EMPTY:
			# Stippled grass blade specks
			var speck_offsets = [Vector2(12, 14), Vector2(42, 18), Vector2(20, 42), Vector2(46, 44), Vector2(28, 24)]
			for i in range(speck_offsets.size()):
				var c_col = Color(0.44, 0.72, 0.32, 0.7) if (i % 2 == 0) else Color(0.20, 0.38, 0.14, 0.7)
				overlay.add_child(_create_overlay_rect(Vector2(4, 4), speck_offsets[i], c_col))

		FarmTile.TileState.PLOWED:
			# 4 horizontal soil furrow ridges (shadow trench + highlight ridge)
			for i in range(4):
				var y_pos = 6 + i * 14
				overlay.add_child(_create_overlay_rect(Vector2(56, 3), Vector2(4, y_pos), Color(0.22, 0.12, 0.05, 0.75)))
				overlay.add_child(_create_overlay_rect(Vector2(56, 3), Vector2(4, y_pos + 3), Color(0.55, 0.36, 0.20, 0.75)))

		FarmTile.TileState.FLOODED:
			# Waterlogged ripples & dark rot sludge
			overlay.add_child(_create_overlay_rect(Vector2(46, 3), Vector2(8, 16), Color(0.40, 0.70, 0.95, 0.6)))
			overlay.add_child(_create_overlay_rect(Vector2(40, 3), Vector2(12, 42), Color(0.40, 0.70, 0.95, 0.6)))
			overlay.add_child(_create_overlay_rect(Vector2(20, 14), Vector2(22, 24), Color(0.14, 0.09, 0.04, 0.9)))

		FarmTile.TileState.PLANTED:
			# Raised seedbed mound
			overlay.add_child(_create_overlay_rect(Vector2(34, 10), Vector2(15, 38), Color(0.30, 0.18, 0.08, 0.85)))

		FarmTile.TileState.GROWING:
			# Foliage growth bar
			var f_width = clampf(tile.growth_progress * 46.0, 10.0, 46.0)
			overlay.add_child(_create_overlay_rect(Vector2(f_width, 4), Vector2(32 - f_width / 2.0, 50), Color(0.25, 0.80, 0.30, 0.85)))

		FarmTile.TileState.HARVESTABLE:
			# Golden ripe accent
			overlay.add_child(_create_overlay_rect(Vector2(52, 4), Vector2(6, 50), Color(1.0, 0.90, 0.20, 0.95)))

func _is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y

func _determine_quality(tile: FarmTile) -> int:
	if tile.health >= 0.85:
		return FarmTile.QualityGrade.A
	elif tile.health >= 0.55:
		return FarmTile.QualityGrade.B
	else:
		return FarmTile.QualityGrade.C

func _grade_to_string(grade: int) -> String:
	match grade:
		FarmTile.QualityGrade.A: return "Grade A"
		FarmTile.QualityGrade.B: return "Grade B"
		_: return "Grade C"

func _on_weather_changed(_t: float, _h: float) -> void: pass
func _on_disaster_warning(_h: String) -> void: pass

func _on_pest_spawned(pest: String, pos: Vector2i) -> void:
	if _is_valid_pos(pos):
		tiles[pos.x][pos.y].state = FarmTile.TileState.INFECTED
		tiles[pos.x][pos.y].pest_type = pest
		_update_tile_visual(pos)

func _on_pest_cleared(_pest: String, pos: Vector2i) -> void:
	if _is_valid_pos(pos):
		var tile: FarmTile = tiles[pos.x][pos.y]
		tile.pest_type = ""
		if tile.crop_type != "":
			tile.state = FarmTile.TileState.HARVESTABLE if tile.growth_progress >= 1.0 else FarmTile.TileState.GROWING
		else:
			tile.state = FarmTile.TileState.EMPTY
		_update_tile_visual(pos)
