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
signal parcel_unlocked(parcel_id: String)

# ---------------------------------------------------------------------------
# Grid constants (32x32 world island with expandable 16x16 parcels)
# ---------------------------------------------------------------------------
const GRID_SIZE:      Vector2i = Vector2i(32, 32)
const TILE_PIXEL_SIZE: int     = 64
const TILE_BORDER_SIZE: int    = 2

var unlocked_parcels: Array[String] = ["homestead"]
var parcel_sign_nodes: Dictionary = {}  # parcel_id -> Node2D
var land_modal: LandExpansionModal = null
var early_harvest_modal: EarlyHarvestModal = null

# ---------------------------------------------------------------------------
# Tile data arrays  [x][y]
# ---------------------------------------------------------------------------
var tiles:         Array = []  # FarmTile resource instances
var tile_roots:    Array = []  # Node2D container per tile
var tile_fills:    Array = []  # Polygon2D diamond fills
var tile_sprites:  Array = []  # Sprite2D custom ground sprites (4x scaled pixel art)
var tile_overlays: Array = []  # Node2D procedural texture detail layer
var tile_dots:     Array = []  # ColorRect indicator dots
var tile_labels:   Array = []  # Label icon labels
var ground_layer:  Node2D = null  # Dedicated ground layer (Z=0) for terrain slabs and diamond fills

# ---------------------------------------------------------------------------
# Sub-systems
# ---------------------------------------------------------------------------
var renderer: TileRenderer = null  # Owns all visual update logic
var drones: Array = []              # Autonomous precision farm drone fleet
var is_drone_targeting: bool = false # Independent drone zone designation mode
signal drone_selected(drone_index: int)
var selected_drone_index: int = 0   # 0 = none selected, 1-based index when drone is selected
var drone: FarmDrone:               # Backward-compatible accessor for drone #0
	get:
		for d in drones:
			if is_instance_valid(d):
				return d
		return null

# ---------------------------------------------------------------------------
# Single-tile selection state
# ---------------------------------------------------------------------------
var selected_tile_pos:  Vector2i = Vector2i(-1, -1)
var selection_indicator: Node2D  = null
var hover_indicator:     Node2D  = null
var parcel_boundaries_node: Node2D = null
var hovered_grid_pos:   Vector2i = Vector2i(-1, -1)

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
var heatmap_overlay: FarmHeatmapOverlay = null # Soil & Farm Diagnostic Heatmap (z_index 195)
const OutOfBoundsForestScript: GDScript = preload("res://src/world/OutOfBoundsForest.gd")
var forest_overlay: Node2D = null # Out-of-bounds forest perimeter (CoC style)

# ---------------------------------------------------------------------------
# Building Placement & Management State
# ---------------------------------------------------------------------------
var is_placing_building: bool        = false
var placing_building_type: String    = ""
var placing_footprint: Vector2i      = Vector2i(2, 2)
var placing_hover_grid_pos: Vector2i = Vector2i.ZERO
var placing_is_flipped: bool         = false
var placement_overlay: Node2D        = null
var building_card_popup: Node        = null
var weather_app_modal: WeatherAppModal = null

# ---------------------------------------------------------------------------
# Foliage & Crop Occlusion State (See-through transparency for workers)
# ---------------------------------------------------------------------------
var _occluded_tiles: Dictionary = {}

# ---------------------------------------------------------------------------
# Node reference
# ---------------------------------------------------------------------------
@onready var action_popup: PopupMenu = get_node_or_null("../TileActionPopup")


# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	if Data.game_mode == "sandbox" and not SaveManager.has_pending_save_data():
		unlocked_parcels = ["homestead", "east_meadows", "south_plains", "highland_plateau"]
		EconomyManager.cash = 999999
		EconomyManager.cash_changed.emit(EconomyManager.cash)
		for t_key in Data.TECH.keys():
			if not BuildingManager.unlocked_techs.has(t_key):
				BuildingManager.unlocked_techs.append(t_key)
		for c_key in Data.CROPS.keys():
			if not BuildingManager.unlocked_crops.has(c_key):
				BuildingManager.unlocked_crops.append(c_key)
		BuildingManager.total_storage_capacity = 25000
		BuildingManager.worker_capacity = 20
		BuildingManager.storage_updated.emit(BuildingManager.total_storage_capacity, BuildingManager.used_storage)
		BuildingManager.worker_capacity_changed.emit(BuildingManager.worker_capacity, BuildingManager.active_workers)
		LogManager.log_event("system", "✨ Creative Sandbox Mode active! ₱999,999 treasury, all 4 parcels, and all tech unlocked.", "✨", Color(1.0, 0.85, 0.20))

	_create_grid()
	if not SaveManager.has_pending_save_data():
		_spawn_starting_homestead_buildings()
	_create_selection_indicator()
	_create_hover_indicator()
	_update_parcel_boundaries()

	renderer = TileRenderer.new()
	renderer.setup(tile_fills, tile_overlays, tile_dots, tile_labels, tile_sprites)
	if renderer.ground_sprites:
		renderer.ground_sprites.world_seed = randi()

	if SaveManager.has_pending_save_data():
		SaveManager.apply_pending_save(self)
	else:
		renderer.update_all(tiles, GRID_SIZE)

	# Autoload signals
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.hour_changed.connect(_on_hour_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	WeatherManager.disaster_warning.connect(_on_disaster_warning)
	WeatherManager.disaster_struck.connect(_on_disaster_struck)
	PestManager.pest_spawned.connect(_on_pest_spawned)
	PestManager.pest_cleared.connect(_on_pest_cleared)

	# Popup signals
	if action_popup and action_popup.has_signal("action_selected"):
		action_popup.action_selected.connect(_on_action_popup_selected)
	if action_popup and action_popup.has_signal("batch_action_selected"):
		action_popup.batch_action_selected.connect(_on_batch_action_selected)

	# Tile info panel
	var info_panel = get_tree().root.find_child("TileInfoPanel", true, false)
	if info_panel:
		if info_panel.has_method("inspect_tile") and not tile_inspected.is_connected(info_panel.inspect_tile):
			tile_inspected.connect(info_panel.inspect_tile)
		if info_panel.has_method("inspect_selection") and not selection_inspected.is_connected(info_panel.inspect_selection):
			selection_inspected.connect(info_panel.inspect_selection)

	# Drag-select overlay — added last so it draws above all tile children
	var overlay_script: GDScript = load("res://src/world/DragSelectOverlay.gd")
	drag_overlay = Node2D.new()
	drag_overlay.set_script(overlay_script)
	drag_overlay.name        = "DragSelectOverlay"
	drag_overlay.z_index     = 200
	drag_overlay.z_as_relative = false
	add_child(drag_overlay)
	drag_overlay.farm_grid = self

	# Regional Environment Map (Unique terrain, monuments, cultural props, and regional water per province)
	_load_regional_map()

	# Soil & Farm Diagnostic Heatmap Overlay (z_index 195)
	heatmap_overlay = FarmHeatmapOverlay.new()
	heatmap_overlay.name = "FarmHeatmapOverlay"
	heatmap_overlay.farm_grid = self
	add_child(heatmap_overlay)

	# Building placement overlay
	var b_overlay_script: GDScript = load("res://src/buildings/BuildingPlacementOverlay.gd")
	placement_overlay = Node2D.new()
	placement_overlay.set_script(b_overlay_script)
	placement_overlay.name        = "BuildingPlacementOverlay"
	placement_overlay.z_index     = 210
	placement_overlay.z_as_relative = false
	add_child(placement_overlay)
	placement_overlay.farm_grid = self

	# Precision farm drone fleet (autonomous mechanized labor)
	BuildingManager.drone_commissioned.connect(_on_drone_commissioned)
	BuildingManager.building_placed.connect(func(_b): _sync_drones())
	_sync_drones()

	# Building Card Popup (Upgrade & Inspection Modal)
	var card_scene: PackedScene = load("res://scenes/BuildingCardPopup.tscn")
	if card_scene:
		building_card_popup = card_scene.instantiate()
		get_parent().call_deferred("add_child", building_card_popup)

	# Weather App Modal (PAGASA Meteorological Telemetry & Predictions Dashboard)
	weather_app_modal = WeatherAppModal.new()
	weather_app_modal.name = "WeatherAppModal"
	get_parent().call_deferred("add_child", weather_app_modal)

	# Land Expansion Modal
	land_modal = LandExpansionModal.new()
	land_modal.name = "LandExpansionModal"
	get_parent().call_deferred("add_child", land_modal)

	# Early Harvest Confirmation Modal
	early_harvest_modal = EarlyHarvestModal.new()
	early_harvest_modal.name = "EarlyHarvestModal"
	get_parent().call_deferred("add_child", early_harvest_modal)
	early_harvest_modal.harvest_confirmed.connect(_on_early_harvest_confirmed)

	var plant_hotbar = get_tree().root.find_child("PlantHotbar", true, false)
	if plant_hotbar and plant_hotbar.has_signal("tool_selected"):
		plant_hotbar.tool_selected.connect(func(_t): if drag_overlay: drag_overlay.queue_redraw())

	if TaskManager.has_signal("selection_changed"):
		TaskManager.selection_changed.connect(func(_sel): if drag_overlay: drag_overlay.queue_redraw())

	if TaskManager.has_signal("tasks_changed"):
		TaskManager.tasks_changed.connect(func(): if drag_overlay: drag_overlay.queue_redraw())

	if TaskManager.has_signal("tasks_assigned"):
		TaskManager.tasks_assigned.connect(func(_w, _t): if drag_overlay: drag_overlay.queue_redraw())

	select_tile.call_deferred(Vector2i(0, 0))

func _load_regional_map() -> void:
	# Check if a RegionalMap node already exists in this FarmGrid (e.g. from an inherited or custom scene)
	var existing_map = get_node_or_null("RegionalMap")
	if existing_map:
		forest_overlay = existing_map.get_node_or_null("OutOfBoundsForest")
		return

	var map_path := Data.get_region_map_path(Data.current_region)
	if ResourceLoader.exists(map_path):
		var map_scene = load(map_path) as PackedScene
		if map_scene:
			var map_inst = map_scene.instantiate()
			map_inst.name = "RegionalMap"
			add_child(map_inst)
			forest_overlay = map_inst.get_node_or_null("OutOfBoundsForest")
			return

	# Fallback if map scene not found
	var sea_water = SeaWater.new()
	sea_water.name = "SeaWater"
	add_child(sea_water)

	forest_overlay = OutOfBoundsForestScript.new()
	forest_overlay.name = "OutOfBoundsForest"
	add_child(forest_overlay)

func _process(delta: float) -> void:
	if renderer:
		renderer.process_animations(delta)
	_update_foliage_occlusion(delta)
	_update_hover_cursor()

## Checks all active workers against standing crops, 2x2 groves, and obstacle trees,
## smoothly fading occluding foliage to 35% translucent alpha so workers are never hidden.
func _update_foliage_occlusion(delta: float) -> void:
	var farmers := get_tree().get_nodes_in_group("farmers")
	if farmers.is_empty():
		if not _occluded_tiles.is_empty():
			var restored: Array = []
			for tp in _occluded_tiles.keys():
				if _is_valid(tp):
					var ov: Node2D = tile_overlays[tp.x][tp.y]
					if is_instance_valid(ov):
						ov.modulate.a = move_toward(ov.modulate.a, 1.0, delta * 6.0)
						if ov.modulate.a >= 0.99:
							ov.modulate.a = 1.0
							restored.append(tp)
				else:
					restored.append(tp)
			for tp in restored:
				_occluded_tiles.erase(tp)
		return

	var new_occluded: Dictionary = {}

	for f_node in farmers:
		var f := f_node as Node2D
		if f == null or not is_instance_valid(f):
			continue

		var f_local: Vector2 = to_local(f.global_position)
		var fg: Vector2i = FarmerMovement.pixel_to_grid(f.global_position, self)

		# Inspect candidate tiles around and south of the worker that could occlude them
		for dx in range(-1, 3):
			for dy in range(-1, 3):
				var tp := fg + Vector2i(dx, dy)
				if not _is_valid(tp):
					continue

				var tile: FarmTile = tiles[tp.x][tp.y]
				var has_standing_foliage: bool = false
				if tile.crop_type != "" and tile.state in [
					FarmTile.TileState.PLANTED,
					FarmTile.TileState.GROWING,
					FarmTile.TileState.HARVESTABLE,
					FarmTile.TileState.INFECTED,
					FarmTile.TileState.FLOODED
				]:
					has_standing_foliage = true
				elif tile.state == FarmTile.TileState.OBSTACLE or (tile.state == FarmTile.TileState.LOCKED and tile.obstacle_type != ""):
					has_standing_foliage = true

				if not has_standing_foliage:
					continue

				# Bounding box check in local pixel space
				var root_pos: Vector2 = tile_roots[tp.x][tp.y].position
				var dx_px: float = absf(f_local.x - root_pos.x)
				var dy_px: float = (root_pos.y + 24.0) - f_local.y

				var max_w: float = 88.0 if tile.is_multi_tile_root else 52.0
				var max_h: float = 240.0 if tile.is_multi_tile_root else 180.0

				# If farmer is horizontally within sprite spread and vertically under foliage
				if dx_px <= max_w and dy_px >= -12.0 and dy_px <= max_h:
					new_occluded[tp] = true
					if tile.is_multi_tile_root:
						for mdx in range(2):
							for mdy in range(2):
								var sub_p := tp + Vector2i(mdx, mdy)
								if _is_valid(sub_p):
									new_occluded[sub_p] = true

	# Fade in occlusion transparency (0.35) for occluding tiles
	for tp in new_occluded.keys():
		_occluded_tiles[tp] = true
		var ov: Node2D = tile_overlays[tp.x][tp.y]
		if is_instance_valid(ov):
			ov.modulate.a = move_toward(ov.modulate.a, 0.35, delta * 8.0)

	# Fade out restored tiles back to opaque (1.0)
	var to_clean: Array = []
	for tp in _occluded_tiles.keys():
		if not new_occluded.has(tp):
			if _is_valid(tp):
				var ov: Node2D = tile_overlays[tp.x][tp.y]
				if is_instance_valid(ov):
					ov.modulate.a = move_toward(ov.modulate.a, 1.0, delta * 6.0)
					if ov.modulate.a >= 0.99:
						ov.modulate.a = 1.0
						to_clean.append(tp)
				else:
					to_clean.append(tp)
			else:
				to_clean.append(tp)

	for tp in to_clean:
		_occluded_tiles.erase(tp)

# ---------------------------------------------------------------------------
# Grid construction
# ---------------------------------------------------------------------------
func _create_grid() -> void:
	y_sort_enabled = true
	var region_data:     Dictionary = Data.get_region(Data.current_region)
	var default_moisture: float     = float(region_data.get("soil_moisture", 60))

	# Dedicated ground terrain container (z_index = 0, y_sort_enabled = true)
	# Ensures all terrain diamond fills, depth slabs, and border lines render
	# beneath all standing objects (trees, buildings, workers) without clipping.
	# Enabling y_sort_enabled ensures front depth slabs correctly sort southwards.
	ground_layer = Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = 0
	ground_layer.y_sort_enabled = true
	add_child(ground_layer)

	tiles.resize(GRID_SIZE.x);         tile_roots.resize(GRID_SIZE.x)
	tile_fills.resize(GRID_SIZE.x);    tile_overlays.resize(GRID_SIZE.x)
	tile_dots.resize(GRID_SIZE.x);     tile_labels.resize(GRID_SIZE.x)
	tile_sprites.resize(GRID_SIZE.x)

	for x in range(GRID_SIZE.x):
		tiles[x] = [];         tile_roots[x] = []
		tile_fills[x] = [];    tile_overlays[x] = []
		tile_dots[x] = [];     tile_labels[x] = []
		tile_sprites[x] = []

		for y in range(GRID_SIZE.y):
			# ── Data ──────────────────────────────────────────────────────
			var tile := FarmTile.new()
			tile.soil_moisture = default_moisture
			var parcel: Dictionary = Data.get_parcel_for_tile(Vector2i(x, y))
			if Data.game_mode == "sandbox" or parcel.is_empty() or parcel.get("unlocked_by_default", false):
				tile.state = FarmTile.TileState.EMPTY
			else:
				tile.state = FarmTile.TileState.LOCKED
			tiles[x].append(tile)

			var tile_pos_px := FarmerMovement.grid_to_pixel_center(Vector2i(x, y), null)

			# ── Ground nodes in GroundLayer (Z=0, drawn beneath all standing objects) ──
			var ground_node := Node2D.new()
			ground_node.name     = "Ground_%d_%d" % [x, y]
			ground_node.position = tile_pos_px
			ground_layer.add_child(ground_node)

			# 1. 3D Isometric Soil Depth Slab (Bottom/Right Front Faces) - procedural fallback only
			var slab_left := Polygon2D.new()
			slab_left.polygon = PackedVector2Array([
				Vector2(-64, 0), Vector2(0, 32), Vector2(0, 38), Vector2(-64, 6)
			])
			slab_left.color = Color(0.20, 0.15, 0.10, 0.95)
			slab_left.visible = false
			ground_node.add_child(slab_left)

			var slab_right := Polygon2D.new()
			slab_right.polygon = PackedVector2Array([
				Vector2(0, 32), Vector2(64, 0), Vector2(64, 6), Vector2(0, 38)
			])
			slab_right.color = Color(0.26, 0.20, 0.14, 0.95)
			slab_right.visible = false
			ground_node.add_child(slab_right)

			# 2. Organic isometric grid border seam
			var border := Line2D.new()
			border.width = 1.0
			border.default_color = Color(0.18, 0.28, 0.14, 0.45)
			border.closed = true
			border.add_point(Vector2(0, -32))
			border.add_point(Vector2(64, 0))
			border.add_point(Vector2(0, 32))
			border.add_point(Vector2(-64, 0))
			ground_node.add_child(border)

			# 3. Inset 2:1 Isometric Diamond Fill (128×64)
			var fill := Polygon2D.new()
			fill.polygon = PackedVector2Array([
				Vector2(0, -31), Vector2(63, 0), Vector2(0, 31), Vector2(-63, 0)
			])
			fill.color = TileRenderer.COLOR_EMPTY
			ground_node.add_child(fill)
			tile_fills[x].append(fill)

			# 4. Custom pixel-art ground sprite (32×32 source, 4x scale = 128×64 diamond + 32px slab)
			var sprite := Sprite2D.new()
			sprite.name = "GroundSprite"
			sprite.centered = true
			sprite.scale = Vector2(4.0, 4.0)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.visible = false
			ground_node.add_child(sprite)
			tile_sprites[x].append(sprite)

			# ── Standing object root node (Z=10, Y-sorted with Buildings & Workers) ───
			var root := Node2D.new()
			root.name     = "Tile_%d_%d" % [x, y]
			root.position = tile_pos_px
			root.z_index  = 10
			root.y_sort_enabled = true
			add_child(root)
			tile_roots[x].append(root)

			# 4. Texture detail overlay (trees, crops, weeds)
			var overlay := Node2D.new()
			overlay.name = "Overlay"
			overlay.y_sort_enabled = true
			root.add_child(overlay)
			tile_overlays[x].append(overlay)

			# 5. Status indicator dot (top-right diamond shoulder)
			var dot := ColorRect.new()
			dot.size         = Vector2(8, 8)
			dot.position     = Vector2(36, -8)
			dot.color        = Color.TRANSPARENT
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(dot)
			tile_dots[x].append(dot)

			# 6. Center crop icon label (upright 2.5D elevation)
			var lbl := Label.new()
			lbl.size                 = Vector2(48, 48)
			lbl.position             = Vector2(-24, -32)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
			root.add_child(lbl)
			tile_labels[x].append(lbl)

	if not SaveManager.has_pending_save_data():
		_seed_natural_obstacles()
		_create_parcel_signposts()

func _seed_natural_obstacles() -> void:
	# Starting 16x16 homestead: exactly 1 tree and 1 rock as requested
	var h_rect: Rect2i = Data.get_parcel("homestead").get("rect", Rect2i(0, 0, 16, 16))
	_procedural_generate_obstacles_in_rect(h_rect, 1, 1)

## Procedurally places a balanced scattering of trees and rocks within a parcel rectangle.
## Guarantees obstacles NEVER layer on buildings, starting courtyard, signposts, or adjacent to other obstacles.
func _procedural_generate_obstacles_in_rect(rect: Rect2i, num_trees: int, num_rocks: int) -> void:
	var candidates: Array[Vector2i] = []
	var compound_clearance := Rect2i(0, 0, 5, 3)

	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var pos := Vector2i(x, y)
			if not _is_valid(pos):
				continue
			var tile: FarmTile = tiles[x][y]

			# 1. Tile must be empty
			if tile.state != FarmTile.TileState.EMPTY:
				continue

			# 2. Never layer on buildings or building manager registrations
			if tile.building_ref != null or BuildingManager.is_tile_occupied_by_building(pos):
				continue

			# 3. Never layer in starter homestead courtyard (front of Bahay Kubo & Silo)
			if rect.position == Vector2i(0, 0) and compound_clearance.has_point(pos):
				continue

			# 4. Never layer on parcel purchase signposts or Bayanihan field posts
			var is_sign_tile: bool = false
			for p in Data.get_parcels():
				if p.get("sign_tile", Vector2i(-1, -1)) == pos:
					is_sign_tile = true
					break
			if pos in [Vector2i(0, 4), Vector2i(16, 4), Vector2i(4, 16), Vector2i(16, 16)]:
				is_sign_tile = true
			if is_sign_tile:
				continue

			candidates.append(pos)

	candidates.shuffle()

	var chosen_obstacles: Array[Vector2i] = []
	var total_target: int = num_trees + num_rocks

	for pos in candidates:
		if chosen_obstacles.size() >= total_target:
			break

		# Spacing constraint: ensure at least 2 tiles separation from already chosen obstacles
		# so trees and rocks do not bunch together or overlap canopies
		var too_close: bool = false
		for existing in chosen_obstacles:
			if maxi(absi(pos.x - existing.x), absi(pos.y - existing.y)) < 2:
				too_close = true
				break

		if not too_close:
			chosen_obstacles.append(pos)

	# Assign types: first num_trees as "tree", remainder as "rock"
	for i in range(chosen_obstacles.size()):
		var c_pos: Vector2i = chosen_obstacles[i]
		var t: FarmTile = tiles[c_pos.x][c_pos.y]
		t.state = FarmTile.TileState.OBSTACLE
		if i < num_trees:
			t.obstacle_type = "tree"
		else:
			t.obstacle_type = "rock"

## Spawns visible starter farm infrastructure: Bahay Kubo & Grain Bodega stuck together in the top-right corner with 0 unused space
func _spawn_starting_homestead_buildings() -> void:
	# 1. Bahay Kubo at (0, 0) — 2x2 footprint, fills the top apex corner completely
	_spawn_starter_building(Vector2i(0, 0), "bahay_kubo")

	# 2. Grain Silo Compound at (2, 0) — 2x2 footprint, stuck directly against Kubo's right wall along the top-right edge (y=0)
	_spawn_starter_building(Vector2i(2, 0), "bodega")

func _spawn_starter_building(start_pos: Vector2i, b_type: String) -> Building:
	var b_data: Dictionary = Data.get_building(b_type)
	if b_data.is_empty():
		return null

	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))

	# Mark occupied tiles as BUILDING
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if _is_valid(tp):
				tiles[tp.x][tp.y].state        = FarmTile.TileState.BUILDING
				tiles[tp.x][tp.y].crop_type    = ""
				tiles[tp.x][tp.y].pest_type    = ""
				tiles[tp.x][tp.y].growth_progress = 0.0
				tiles[tp.x][tp.y].hours_waterlogged = 0

	# Instantiate Building node
	var building := Building.new()
	building.name          = "Building_%s_%d_%d" % [b_type, start_pos.x, start_pos.y]
	building.building_type = b_type
	building.grid_pos      = start_pos
	building.footprint     = fp
	building.level         = 1
	building.state         = Building.BuildingState.ACTIVE
	building.duration      = 0.0
	building.progress_timer = 0.0

	add_child(building)

	# Store back-reference in every occupied tile
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if _is_valid(tp):
				tiles[tp.x][tp.y].building_ref = building

	# Connect lifecycle signals
	if building.has_signal("clicked") and not building.clicked.is_connected(_on_building_clicked):
		building.clicked.connect(_on_building_clicked)
	if building.has_signal("demolished") and not building.demolished.is_connected(_on_building_demolished):
		building.demolished.connect(_on_building_demolished)

	# Register in BuildingManager
	BuildingManager.register_building(building)

	return building

func _create_parcel_signposts() -> void:
	# 1. Clean up any existing signposts across all parcels and clear tracking
	for pid in parcel_sign_nodes.keys():
		var sn = parcel_sign_nodes[pid]
		if is_instance_valid(sn):
			if sn.get_parent():
				sn.get_parent().remove_child(sn)
			sn.queue_free()
	parcel_sign_nodes.clear()

	# Also sweep all parcel sign tiles directly to remove any orphaned Signpost nodes
	for p in Data.get_parcels():
		var spos: Vector2i = p.get("sign_tile", Vector2i(-1, -1))
		if _is_valid(spos):
			var troot: Node2D = tile_roots[spos.x][spos.y]
			for child in troot.get_children():
				if child.name.begins_with("Signpost"):
					troot.remove_child(child)
					child.queue_free()

	# 2. Only create signposts for locked expansion parcels
	for p in Data.get_parcels():
		var pid: String = p.get("id", "")
		if pid == "homestead" or unlocked_parcels.has(pid):
			continue
		var sign_pos: Vector2i = p.get("sign_tile", Vector2i(0, 0))
		if not _is_valid(sign_pos):
			continue
		var root: Node2D = tile_roots[sign_pos.x][sign_pos.y]
		var sign_container := Node2D.new()
		sign_container.name = "Signpost_" + pid
		sign_container.z_index = 45
		root.add_child(sign_container)
		parcel_sign_nodes[pid] = sign_container

		# 2.5D wooden signpost pole
		var pole := Line2D.new()
		pole.width = 4.0
		pole.default_color = Color(0.35, 0.22, 0.12, 1.0)
		pole.add_point(Vector2(0, 0))
		pole.add_point(Vector2(0, -36))
		sign_container.add_child(pole)

		# Wooden sign board / button
		var r_sz: Vector2i = p.get("rect", Rect2i()).size
		var btn := Button.new()
		btn.text = "📜 %d×%d LAND\n%s\n₱%s" % [r_sz.x, r_sz.y, p.get("name"), Utils.format_number(p.get("cost", 0))]
		btn.custom_minimum_size = Vector2(130, 48)
		btn.position = Vector2(-65, -88)
		btn.add_theme_font_size_override("font_size", 9)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): open_land_expansion_modal(pid))
		sign_container.add_child(btn)

func open_land_expansion_modal(parcel_id: String) -> void:
	if land_modal:
		land_modal.open_for_parcel(parcel_id, self)

func open_bayanihan_modal(_parcel_id: String = "homestead") -> void:
	pass

func is_tile_unlocked(pos: Vector2i) -> bool:
	if not _is_valid(pos):
		return false
	var parcel: Dictionary = Data.get_parcel_for_tile(pos)
	if not parcel.is_empty() and not unlocked_parcels.has(parcel.get("id", "")):
		return false
	return tiles[pos.x][pos.y].state != FarmTile.TileState.LOCKED

func unlock_parcel(parcel_id: String) -> bool:
	var p: Dictionary = Data.get_parcel(parcel_id)
	if p.is_empty():
		return false
	if unlocked_parcels.has(parcel_id):
		return false
	var cost: int = p.get("cost", 0)
	if EconomyManager.cash < cost:
		return false

	EconomyManager.deduct_cash(cost)
	unlocked_parcels.append(parcel_id)
	AudioManager.play_tech("tech_unlock")

	var rect: Rect2i = p.get("rect", Rect2i())
	var region_data: Dictionary = Data.get_region(Data.current_region)
	var default_moisture: float = float(region_data.get("soil_moisture", 60))

	# Unlock all plots in the parcel
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if _is_valid(Vector2i(x, y)):
				var tile: FarmTile = tiles[x][y]
				tile.state = FarmTile.TileState.EMPTY
				tile.crop_type = ""
				tile.growth_progress = 0.0
				tile.soil_moisture = default_moisture
				tile.health = 1.0

	# Procedurally place a balanced, modest scattering of trees and rocks in newly unlocked land
	_procedural_generate_obstacles_in_rect(rect, randi_range(5, 6), randi_range(3, 4))

	# Remove signpost from tracking dictionary and scene tree
	if parcel_sign_nodes.has(parcel_id):
		var sn: Node2D = parcel_sign_nodes[parcel_id]
		if is_instance_valid(sn):
			if sn.get_parent():
				sn.get_parent().remove_child(sn)
			sn.queue_free()
		parcel_sign_nodes.erase(parcel_id)

	# Direct cleanup on parcel sign tile to eliminate any duplicate or orphaned sign node
	var sign_pos: Vector2i = p.get("sign_tile", Vector2i(-1, -1))
	if _is_valid(sign_pos):
		var sroot: Node2D = tile_roots[sign_pos.x][sign_pos.y]
		for child in sroot.get_children():
			if child.name.begins_with("Signpost"):
				sroot.remove_child(child)
				child.queue_free()

	# Also sweep all tiles in newly unlocked parcel to ensure zero stray signpost nodes
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if _is_valid(Vector2i(x, y)):
				var troot: Node2D = tile_roots[x][y]
				for child in troot.get_children():
					if child.name.begins_with("Signpost"):
						troot.remove_child(child)
						child.queue_free()

	if land_modal and is_instance_valid(land_modal):
		land_modal.close()

	renderer.update_all(tiles, GRID_SIZE)
	_update_parcel_boundaries()
	parcel_unlocked.emit(parcel_id)

	var num_plots: int = rect.size.x * rect.size.y
	LogManager.log_event("buildings", "🗺️ Territory Expanded: Acquired %s (%d×%d - %d new plots)!" % [p.get("name"), rect.size.x, rect.size.y, num_plots], "🗺️", Color(0.35, 0.95, 0.45))
	return true


# ---------------------------------------------------------------------------
# Floating Text Popup (e.g. "Not enough Money", warnings, etc.)
# ---------------------------------------------------------------------------
var _last_floating_text_time: float = 0.0
var _last_floating_text_pos: Vector2i = Vector2i(-1, -1)

func show_floating_text(grid_pos: Vector2i, text: String, color: Color = Color(1.0, 0.35, 0.35, 1.0)) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if grid_pos == _last_floating_text_pos and (now - _last_floating_text_time) < 0.35:
		return
	_last_floating_text_pos = grid_pos
	_last_floating_text_time = now

	var world_pos: Vector2 = FarmerMovement.grid_to_pixel_center(grid_pos, null) + Vector2(0, -32)
	spawn_floating_text_at_world(world_pos, text, color)

func spawn_floating_text_at_world(world_pos: Vector2, text: String, color: Color = Color(1.0, 0.35, 0.35, 1.0)) -> void:
	var container := PanelContainer.new()
	container.name = "FloatingTextBadge"
	container.z_index = 300
	container.z_as_relative = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.06, 0.92)
	sb.border_color = Color(0.92, 0.30, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	container.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	var font = load("res://assets/font/quill_and_antler/quill-and-antler.ttf")
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 12)

	container.add_child(label)
	add_child(container)

	container.reset_size()
	var sz := container.get_combined_minimum_size()
	container.position = world_pos - Vector2(sz.x * 0.5, sz.y)
	container.pivot_offset = sz * 0.5

	# Snappy Pop-In & Float Up Tween
	container.scale = Vector2(0.7, 0.7)
	container.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 1.0, 0.12)
	tw.tween_property(container, "position:y", container.position.y - 30.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var tw_fade := create_tween()
	tw_fade.tween_interval(0.7)
	tw_fade.tween_property(container, "modulate:a", 0.0, 0.4)
	tw_fade.tween_callback(container.queue_free)


func _create_selection_indicator() -> void:
	selection_indicator          = Node2D.new()
	selection_indicator.name     = "SelectionIndicator"
	selection_indicator.z_index  = 2  # Render above ground fill (Z=0), but below standing trees & buildings (Z=10)
	selection_indicator.visible  = false
	add_child(selection_indicator)

	var gold := Color(1.0, 0.92, 0.20, 1.0)
	var glow := Color(1.0, 0.95, 0.30, 0.25)

	# Translucent diamond glow fill
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(60, 0), Vector2(0, 30), Vector2(-60, 0)
	])
	fill.color = glow
	selection_indicator.add_child(fill)

	# Glowing diamond border outline
	var border := Line2D.new()
	border.name = "Border"
	border.width = 3.0
	border.default_color = gold
	border.closed = true
	border.add_point(Vector2(0, -32))
	border.add_point(Vector2(64, 0))
	border.add_point(Vector2(0, 32))
	border.add_point(Vector2(-64, 0))
	selection_indicator.add_child(border)

func _create_hover_indicator() -> void:
	hover_indicator          = Node2D.new()
	hover_indicator.name     = "HoverIndicator"
	hover_indicator.z_index  = 2  # Above ground fill (Z=0), below crops & buildings (Z=10)
	hover_indicator.visible  = false
	add_child(hover_indicator)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(60, 0), Vector2(0, 30), Vector2(-60, 0)
	])
	fill.color = Color(1.0, 0.95, 0.65, 0.12)
	hover_indicator.add_child(fill)

	var border := Line2D.new()
	border.name = "Border"
	border.width = 2.0
	border.default_color = Color(1.0, 0.95, 0.65, 0.70)
	border.closed = true
	border.add_point(Vector2(0, -32))
	border.add_point(Vector2(64, 0))
	border.add_point(Vector2(0, 32))
	border.add_point(Vector2(-64, 0))
	hover_indicator.add_child(border)

func _update_hover_cursor() -> void:
	if hover_indicator == null:
		return
	if _is_any_menu_open() or is_box_dragging or is_placing_building:
		hover_indicator.visible = false
		return

	var gpos: Vector2i = hovered_grid_pos
	if not _is_valid(gpos):
		hover_indicator.visible = false
		return

	var tile: FarmTile = tiles[gpos.x][gpos.y]
	var is_multi: bool = (tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1))
	var root_pos: Vector2i = gpos if not is_multi else (gpos if tile.is_multi_tile_root else tile.multi_tile_root_pos)
	var root_tile: FarmTile = tiles[root_pos.x][root_pos.y]

	# Hide hover cursor if the tile is already selected by selection indicator
	if selection_indicator and selection_indicator.visible and selected_tile_pos == root_pos:
		hover_indicator.visible = false
		return

	# Hide ground hover cursor if the tile has a standing crop, so the crop sprite itself is highlighted!
	if not root_tile.crop_type.is_empty():
		hover_indicator.visible = false
		return

	var fill_node: Polygon2D = hover_indicator.get_node_or_null("Fill") as Polygon2D
	var border_node: Line2D = hover_indicator.get_node_or_null("Border") as Line2D

	var poly: PackedVector2Array
	if is_multi:
		poly = FarmerMovement.get_footprint_polygon_local(root_pos, Vector2i(2, 2))
	else:
		poly = FarmerMovement.get_tile_diamond_local(gpos)

	if fill_node:
		fill_node.polygon = poly
	if border_node:
		var pts := PackedVector2Array(poly)
		pts.append(poly[0])
		border_node.points = pts

	var border_col: Color
	var fill_col: Color

	if not is_tile_unlocked(gpos):
		border_col = Color(0.85, 0.35, 0.35, 0.65) # Soft Crimson for Locked land
		fill_col   = Color(0.85, 0.35, 0.35, 0.12)
	elif root_tile.state == FarmTile.TileState.HARVESTABLE or (root_tile.crop_type != "" and root_tile.growth_progress >= 1.0):
		border_col = Color(0.40, 0.95, 0.40, 0.85) # Vibrant Emerald for Harvest ready
		fill_col   = Color(0.40, 0.95, 0.40, 0.18)
	elif root_tile.state == FarmTile.TileState.OBSTACLE:
		border_col = Color(0.95, 0.65, 0.25, 0.75) # Warm Amber for Obstacles
		fill_col   = Color(0.95, 0.65, 0.25, 0.14)
	elif root_tile.state == FarmTile.TileState.INFECTED:
		border_col = Color(0.85, 0.40, 0.90, 0.80) # Purple for Pest Infected
		fill_col   = Color(0.85, 0.40, 0.90, 0.15)
	else:
		border_col = Color(1.0, 0.92, 0.55, 0.70) # Soft Warm Gold for Plowable/Plantable/Growing
		fill_col   = Color(1.0, 0.92, 0.55, 0.10)

	if fill_node:
		fill_node.color = fill_col
	if border_node:
		border_node.default_color = border_col

	hover_indicator.position = Vector2.ZERO
	hover_indicator.visible = true

## Rebuilds the visual boundaries demarcating unlocked homestead from locked parcels
func _update_parcel_boundaries() -> void:
	if parcel_boundaries_node == null:
		parcel_boundaries_node = Node2D.new()
		parcel_boundaries_node.name = "ParcelBoundaries"
		parcel_boundaries_node.z_index = 1 # Above terrain at Z=0, below crops and workers
		add_child(parcel_boundaries_node)

	for child in parcel_boundaries_node.get_children():
		child.queue_free()

	for p in Data.get_parcels():
		var pid: String = p.get("id", "")
		var rect: Rect2i = p.get("rect", Rect2i())
		var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(rect.position, rect.size)
		var is_unlocked: bool = unlocked_parcels.has(pid)

		if is_unlocked:
			# Deep boundary shadow
			var shadow := Line2D.new()
			shadow.width = 4.0
			shadow.default_color = Color(0.10, 0.08, 0.05, 0.45)
			shadow.closed = true
			var pts_s := PackedVector2Array(poly)
			pts_s.append(poly[0])
			shadow.points = pts_s
			parcel_boundaries_node.add_child(shadow)

			# Warm golden boundary line
			var border := Line2D.new()
			border.width = 2.5
			border.default_color = Color(1.0, 0.88, 0.45, 0.85)
			border.closed = true
			var pts_b := PackedVector2Array(poly)
			pts_b.append(poly[0])
			border.points = pts_b
			parcel_boundaries_node.add_child(border)

			# Corner boundary survey pegs with red ribbons
			for corner_pt in poly:
				var peg := Line2D.new()
				peg.width = 3.5
				peg.default_color = Color(0.40, 0.25, 0.14, 1.0)
				peg.add_point(corner_pt + Vector2(0, 2))
				peg.add_point(corner_pt + Vector2(0, -12))
				parcel_boundaries_node.add_child(peg)

				var ribbon := Line2D.new()
				ribbon.width = 2.0
				ribbon.default_color = Color(0.95, 0.30, 0.22, 1.0)
				ribbon.add_point(corner_pt + Vector2(-3, -10))
				ribbon.add_point(corner_pt + Vector2(3, -10))
				parcel_boundaries_node.add_child(ribbon)
		else:
			# Atmospheric parcel fog of war overlay (soft wilderness mist veil over unbought land)
			var parcel_fog := Polygon2D.new()
			parcel_fog.polygon = poly
			parcel_fog.color = Color(0.08, 0.14, 0.09, 0.18)
			parcel_boundaries_node.add_child(parcel_fog)

			# Locked parcel subtle dashed boundary line
			var locked_border := Line2D.new()
			locked_border.width = 1.5
			locked_border.default_color = Color(0.55, 0.42, 0.30, 0.35)
			locked_border.closed = true
			var pts_l := PackedVector2Array(poly)
			pts_l.append(poly[0])
			locked_border.points = pts_l
			parcel_boundaries_node.add_child(locked_border)

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------
func select_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	var is_multi: bool = (tile.is_multi_tile_root or tile.multi_tile_root_pos != Vector2i(-1, -1))
	var root_pos: Vector2i = pos if not is_multi else (pos if tile.is_multi_tile_root else tile.multi_tile_root_pos)

	selected_tile_pos = root_pos
	if selection_indicator:
		# If the tile has a standing crop, suppress ground selection indicator so crop sprite itself is highlighted
		if not tiles[root_pos.x][root_pos.y].crop_type.is_empty():
			selection_indicator.visible = false
		else:
			var fill_node: Polygon2D = selection_indicator.get_node_or_null("Fill") as Polygon2D
			var border_node: Line2D = selection_indicator.get_node_or_null("Border") as Line2D
			if is_multi:
				var poly: PackedVector2Array = FarmerMovement.get_footprint_polygon_local(root_pos, Vector2i(2, 2))
				if fill_node:
					fill_node.polygon = poly
				if border_node:
					var pts := PackedVector2Array(poly)
					pts.append(poly[0])
					border_node.points = pts
				selection_indicator.position = Vector2.ZERO
			else:
				var diamond: PackedVector2Array = FarmerMovement.get_tile_diamond_local(pos)
				if fill_node:
					fill_node.polygon = diamond
				if border_node:
					var pts := PackedVector2Array(diamond)
					pts.append(diamond[0])
					border_node.points = pts
				selection_indicator.position = Vector2.ZERO
			selection_indicator.visible = true

	if drag_overlay:
		drag_overlay.queue_redraw()

	tile_inspected.emit(root_pos, tiles[root_pos.x][root_pos.y])
	AudioManager.play_ui("tile_select")

func get_tile(pos: Vector2i) -> FarmTile:
	if not _is_valid(pos):
		return null
	return tiles[pos.x][pos.y]

# ---------------------------------------------------------------------------
# Mouse input  (marquee drag-select + single tile click)
# ---------------------------------------------------------------------------
func _global_pos_in_grid(gp: Vector2) -> bool:
	var gpos := FarmerMovement.pixel_to_grid(gp, self)
	return _is_valid(gpos)

## Check if any modal or overlay panel is currently open
func _is_any_menu_open() -> bool:
	var hud_layer = get_node_or_null("../HUDLayer")
	if hud_layer:
		var market = hud_layer.find_child("MarketPanel", true, false)
		if market and market.visible:
			return true
		var sell = hud_layer.find_child("SellPanel", true, false)
		if sell and sell.visible:
			return true
		var shop = hud_layer.find_child("ShopPanel", true, false)
		if shop and shop.visible:
			return true
	var admin = get_tree().root.find_child("AdminPanel", true, false)
	if admin and admin.visible:
		return true
	var pause = get_tree().root.find_child("PauseMenu", true, false)
	if pause and pause.visible:
		return true
	if early_harvest_modal and is_instance_valid(early_harvest_modal) and early_harvest_modal.visible:
		return true
	if land_modal and is_instance_valid(land_modal) and land_modal.visible:
		return true
	return false

## Global input: used for marquee dragging motion, building placement, and tool hover tracking
func _input(event: InputEvent) -> void:
	if is_placing_building and event is InputEventMouseMotion:
		var gpos := FarmerMovement.pixel_to_grid(get_global_mouse_position(), self)
		if gpos != placing_hover_grid_pos:
			placing_hover_grid_pos = gpos
			if placement_overlay:
				placement_overlay.queue_redraw()

	if is_box_dragging:
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
	elif not is_placing_building and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var mouse_world: Vector2 = get_canvas_transform().affine_inverse() * mm.position if mm.position != Vector2.ZERO else get_global_mouse_position()
		var gpos: Vector2i = Vector2i(-1, -1)
		var over_ui: bool = false
		var vp := get_viewport()
		if vp:
			var h_ctrl := vp.gui_get_hovered_control()
			if h_ctrl != null and h_ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				over_ui = true
		if not over_ui and not _is_any_menu_open() and _global_pos_in_grid(mouse_world):
			gpos = FarmerMovement.pixel_to_grid(mouse_world, self)
		if gpos != hovered_grid_pos:
			hovered_grid_pos = gpos
			if drag_overlay:
				drag_overlay.queue_redraw()

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
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				cancel_building_placement()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_R:
				placing_is_flipped = not placing_is_flipped
				AudioManager.play_ui("click")
				if placement_overlay:
					placement_overlay.queue_redraw()
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

	# Press R to flip hovered building or currently inspected building
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if building_card_popup and is_instance_valid(building_card_popup) and building_card_popup.visible and is_instance_valid(building_card_popup.current_building):
			building_card_popup.current_building.toggle_flip()
			AudioManager.play_ui("click")
			building_card_popup.refresh()
			show_floating_text(building_card_popup.current_building.grid_pos, "🔄 Flipped!", Color(1.0, 0.9, 0.4))
			get_viewport().set_input_as_handled()
			return
		var world_mouse := get_global_mouse_position()
		var hover_b := BuildingManager.get_building_at_tile(FarmerMovement.pixel_to_grid(world_mouse, self))
		if hover_b != null and is_instance_valid(hover_b):
			hover_b.toggle_flip()
			AudioManager.play_ui("click")
			show_floating_text(hover_b.grid_pos, "🔄 Flipped!", Color(1.0, 0.9, 0.4))
			get_viewport().set_input_as_handled()
			return


	# Press — begin drag tracking or single click
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if is_drone_targeting:
				cancel_drone_zone_designation()
				get_viewport().set_input_as_handled()
				return

			var world_mouse_rc: Vector2 = get_canvas_transform().affine_inverse() * mb.position if mb.position != Vector2.ZERO else get_global_mouse_position()
			var clicked_tile_pos := FarmerMovement.pixel_to_grid(world_mouse_rc, self)
			var cancelled_count: int = 0

			# 1. If clicked on a tile with a task or assigned worker, cancel it immediately
			if _is_valid(clicked_tile_pos):
				var t_tile: FarmTile = tiles[clicked_tile_pos.x][clicked_tile_pos.y]
				var eff_pos: Vector2i = clicked_tile_pos if not (t_tile.is_multi_tile_root or t_tile.multi_tile_root_pos != Vector2i(-1, -1)) else (clicked_tile_pos if t_tile.is_multi_tile_root else t_tile.multi_tile_root_pos)
				cancelled_count = TaskManager.cancel_task_at(eff_pos)
				if cancelled_count == 0 and eff_pos != clicked_tile_pos:
					cancelled_count = TaskManager.cancel_task_at(clicked_tile_pos)

			# 2. If workers were selected, also halt their tasks
			var selected_workers := TaskManager.get_selected_farmers()
			if not selected_workers.is_empty():
				var halted := TaskManager.cancel_active_or_selected_tasks()
				if cancelled_count == 0:
					cancelled_count = halted

			if cancelled_count > 0:
				AudioManager.play_ui("click")
				if _is_valid(clicked_tile_pos):
					show_floating_text(clicked_tile_pos, "🛑 Action Cancelled", Color(1.0, 0.4, 0.4))
				else:
					spawn_floating_text_at_world(to_local(world_mouse_rc), "🛑 Action Cancelled")
				LogManager.log_event("task", "Cancelled %d task(s) on right-click" % cancelled_count, "🛑", Color(1.0, 0.5, 0.5))

			# Right-click cancels selections, clears active highlights, and deselects workers (right click menu removed)
			if action_popup and action_popup.visible:
				action_popup.hide()
			selected_tiles.clear()
			selected_tile_pos = Vector2i(-1, -1)
			if drag_overlay:
				drag_overlay.queue_redraw()
			if selection_indicator:
				selection_indicator.visible = false
			TaskManager.deselect_all_farmers()
			Input.set_custom_mouse_cursor(null)
			get_viewport().set_input_as_handled()
			return

		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		var world_mouse: Vector2 = get_canvas_transform().affine_inverse() * mb.position if mb.position != Vector2.ZERO else get_global_mouse_position()

		# Left-click on worker: select/toggle worker (supports Ctrl+click for multi-selection)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# Left-click on active drone in world: select drone directly (like a worker!)
			for d in drones:
				if is_instance_valid(d) and d.visible:
					if d.global_position.distance_to(world_mouse) < 32.0:
						TaskManager.deselect_all_farmers()
						select_drone(d)
						get_viewport().set_input_as_handled()
						return

			var clicked_worker = _find_farmer_at(world_mouse)
			if clicked_worker != null:
				deselect_all_drones()
				var is_multi: bool = mb.is_command_or_control_pressed() or mb.shift_pressed
				if not is_multi and TaskManager.get_selected_farmers().size() == 1 and TaskManager.get_selected_farmers()[0] == clicked_worker:
					TaskManager.deselect_all_farmers()
				else:
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

	var active_tool: String = ""
	var plant_hotbar = get_tree().root.find_child("PlantHotbar", true, false)
	if plant_hotbar and plant_hotbar.has_method("get_selected_tool"):
		active_tool = plant_hotbar.get_selected_tool()

	var has_selected_farmers: bool = (TaskManager.get_selected_farmers().size() > 0)
	if not is_drone_targeting and active_tool != "drone_zone" and active_tool != "inspect" and active_tool != "cancel_task" and not has_selected_farmers and not active_tool.is_empty():
		var workers := get_tree().get_nodes_in_group("farmers")
		if not workers.is_empty() and is_instance_valid(workers[0]):
			TaskManager.select_farmer(workers[0])
			has_selected_farmers = true

	# ── Drone Remote Control (Like a Farmer with Hotbar!) ────────────────
	var sel_drone: FarmDrone = get_selected_drone()
	if (is_drone_targeting or active_tool == "drone_zone" or (sel_drone != null and drag_dist > DRAG_THRESHOLD)) and mb.button_index == MOUSE_BUTTON_LEFT:
		is_drone_targeting = false
		if BuildingManager.active_drones <= 0:
			LogManager.log_event("general", "⚠️ Build a Drone Landing Pad in the Shop (Machinery tab) first!", "🛸", Color(1.0, 0.4, 0.4))
			AudioManager.play_ui("error")
			return
		var zone_tiles: Array = []
		if drag_dist > DRAG_THRESHOLD:
			zone_tiles = _get_drag_rect_tiles(drag_start_pos, release_local)
		else:
			var tpos := FarmerMovement.pixel_to_grid(to_global(drag_start_pos), self)
			if _is_valid(tpos) and is_tile_unlocked(tpos):
				zone_tiles = [tpos]
		if not zone_tiles.is_empty():
			if drones.is_empty():
				_sync_drones()
			var target_drone: FarmDrone = sel_drone
			if target_drone == null and not drones.is_empty():
				target_drone = drones[0]
			if target_drone:
				var chosen_crop: String = target_drone.crop_type if not target_drone.crop_type.is_empty() else "palay"
				target_drone.deploy(zone_tiles, chosen_crop)
				var c_disp: String = str(Data.get_crop(chosen_crop).get("display_name", chosen_crop))
				show_floating_text(zone_tiles[0], "🎯 %s Field Assigned (%d Plots - %s)" % [target_drone.get_drone_name(), zone_tiles.size(), c_disp], Color(0.4, 0.9, 1.0))
				AudioManager.play_ui("click")
		selected_tiles.clear()
		if drag_overlay:
			drag_overlay.queue_redraw()
		return
	elif active_tool == "drone_recall" and mb.button_index == MOUSE_BUTTON_LEFT:
		var target_d: FarmDrone = get_selected_drone()
		if target_d:
			target_d.recall()
		else:
			recall_all_drones()
		selected_tiles.clear()
		if drag_overlay:
			drag_overlay.queue_redraw()
		return

	if drag_dist > DRAG_THRESHOLD:
		# ── Multi-tile marquee select ─────────────────────────────────
		var new_tiles := _get_drag_rect_tiles(drag_start_pos, release_local)
		if new_tiles.size() == 1:
			selected_tiles.clear()
			if drag_overlay:
				drag_overlay.queue_redraw()
			var single_pos: Vector2i = new_tiles[0]
			var t_single: FarmTile = tiles[single_pos.x][single_pos.y]
			var is_multi_s: bool = (t_single.is_multi_tile_root or t_single.multi_tile_root_pos != Vector2i(-1, -1))
			var root_s: Vector2i = single_pos if not is_multi_s else (single_pos if t_single.is_multi_tile_root else t_single.multi_tile_root_pos)
			select_tile(root_s)
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if active_tool == "inspect":
					show_floating_text(root_s, "🔍 Inspected", Color(0.4, 0.9, 1.0))
				else:
					selected_tiles.clear()
					if has_selected_farmers or active_tool == "cancel_task":
						_auto_apply_hotbar_action([root_s], active_tool)
		elif new_tiles.size() > 1:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if active_tool == "inspect":
					selected_tiles = new_tiles
					selection_inspected.emit(new_tiles, tiles)
					AudioManager.play_ui("tile_select")
					show_floating_text(new_tiles[0], "🔍 Inspected %d Plots" % new_tiles.size(), Color(0.4, 0.9, 1.0))
					if drag_overlay:
						drag_overlay.queue_redraw()
				else:
					selected_tiles.clear()
					if drag_overlay:
						drag_overlay.queue_redraw()
					if has_selected_farmers or active_tool == "cancel_task":
						_auto_apply_hotbar_action(new_tiles, active_tool)
	else:
		# ── Single tile click ─────────────────────────────────────────
		var tile_pos := FarmerMovement.pixel_to_grid(to_global(drag_start_pos), self)
		if not _is_valid(tile_pos):
			return

		var gx := tile_pos.x
		var gy := tile_pos.y
		var clicked_tile: FarmTile = tiles[gx][gy]
		var is_multi: bool = (clicked_tile.is_multi_tile_root or clicked_tile.multi_tile_root_pos != Vector2i(-1, -1))
		var root_pos: Vector2i = tile_pos if not is_multi else (tile_pos if clicked_tile.is_multi_tile_root else clicked_tile.multi_tile_root_pos)

		# Check if clicked directly on a flying drone in the world
		var m_global := get_global_mouse_position()
		for d in drones:
			if is_instance_valid(d) and d.global_position.distance_to(m_global) <= 36.0:
				select_drone(d)
				selected_tiles.clear()
				if drag_overlay:
					drag_overlay.queue_redraw()
				return

		# Check if clicked on a Drone Command Hangar or Landing Pad
		var b_clicked := BuildingManager.get_building_at_tile(root_pos)
		if b_clicked and (b_clicked.building_type == "drone_station" or b_clicked.building_type == "drone_pad"):
			for d in drones:
				if is_instance_valid(d) and d.hangar_ref == b_clicked:
					select_drone(d)
					break

		if mb.button_index == MOUSE_BUTTON_LEFT:
			selected_tiles.clear()
			if drag_overlay:
				drag_overlay.queue_redraw()
			select_tile(root_pos)
			if active_tool == "inspect":
				show_floating_text(root_pos, "🔍 Inspected", Color(0.4, 0.9, 1.0))
			else:
				if has_selected_farmers or active_tool == "cancel_task":
					_auto_apply_hotbar_action([root_pos], active_tool)
				selected_tiles.clear()

## Automatically applies the active hotbar tool (Plow, Water, Harvest, Clear, Spray, or Seed) when left-clicking or drag-selecting
func _auto_apply_hotbar_action(target_list: Array, tool_id: String) -> void:
	if tool_id.is_empty() or tool_id == "inspect":
		return

	match tool_id:
		"plow":
			var plow_targets: Array[Vector2i] = []
			for p in target_list:
				if is_tile_plowable(p):
					plow_targets.append(p)
			if plow_targets.size() == 1:
				_on_action_popup_selected("plow", plow_targets[0], {})
			elif plow_targets.size() > 1:
				_on_batch_action_selected("plow", plow_targets, {})

		"water":
			var water_targets: Array[Vector2i] = []
			for p in target_list:
				var t: FarmTile = tiles[p.x][p.y]
				var eff_p: Vector2i = p if not (t.is_multi_tile_root or t.multi_tile_root_pos != Vector2i(-1, -1)) else (p if t.is_multi_tile_root else t.multi_tile_root_pos)
				if not water_targets.has(eff_p) and is_valid_tool_target(eff_p, "water"):
					water_targets.append(eff_p)
			if water_targets.size() == 1:
				_on_action_popup_selected("water", water_targets[0], {"amount": 25.0})
			elif water_targets.size() > 1:
				_on_batch_action_selected("water", water_targets, {"amount": 25.0})

		"harvest":
			var harvest_targets: Array[Vector2i] = []
			var has_early: bool = false
			for p in target_list:
				var t: FarmTile = tiles[p.x][p.y]
				var eff_p: Vector2i = p if not (t.is_multi_tile_root or t.multi_tile_root_pos != Vector2i(-1, -1)) else (p if t.is_multi_tile_root else t.multi_tile_root_pos)
				if not harvest_targets.has(eff_p) and is_valid_tool_target(eff_p, "harvest"):
					harvest_targets.append(eff_p)
					var root_t: FarmTile = tiles[eff_p.x][eff_p.y]
					if root_t.growth_progress < 1.0 and root_t.state != FarmTile.TileState.HARVESTABLE:
						has_early = true
			if harvest_targets.is_empty():
				return
			if has_early and early_harvest_modal:
				early_harvest_modal.open_for_harvest(harvest_targets, self)
			else:
				_execute_harvest_targets(harvest_targets)

		"clear":
			var clear_targets: Array[Vector2i] = []
			for p in target_list:
				if is_valid_tool_target(p, "clear"):
					clear_targets.append(p)
			if clear_targets.size() == 1:
				_on_action_popup_selected("clear_obstacle", clear_targets[0], {"cost": 50})
			elif clear_targets.size() > 1:
				_on_batch_action_selected("clear_obstacle", clear_targets, {"cost": 50})

		"spray_chemical":
			var spray_targets: Array[Vector2i] = []
			for p in target_list:
				var t: FarmTile = tiles[p.x][p.y]
				var eff_p: Vector2i = p if not (t.is_multi_tile_root or t.multi_tile_root_pos != Vector2i(-1, -1)) else (p if t.is_multi_tile_root else t.multi_tile_root_pos)
				if not spray_targets.has(eff_p) and is_valid_tool_target(eff_p, "spray_chemical"):
					spray_targets.append(eff_p)
			if spray_targets.size() == 1:
				_on_action_popup_selected("spray_pest", spray_targets[0], {"method": "chemical", "cost": 30})
			elif spray_targets.size() > 1:
				_on_batch_action_selected("spray_pest", spray_targets, {"method": "chemical", "cost": 30})

		"spray_biological":
			var spray_targets: Array[Vector2i] = []
			for p in target_list:
				var t: FarmTile = tiles[p.x][p.y]
				var eff_p: Vector2i = p if not (t.is_multi_tile_root or t.multi_tile_root_pos != Vector2i(-1, -1)) else (p if t.is_multi_tile_root else t.multi_tile_root_pos)
				if not spray_targets.has(eff_p) and is_valid_tool_target(eff_p, "spray_biological"):
					spray_targets.append(eff_p)
			if spray_targets.size() == 1:
				_on_action_popup_selected("spray_pest", spray_targets[0], {"method": "biological", "cost": 45})
			elif spray_targets.size() > 1:
				_on_batch_action_selected("spray_pest", spray_targets, {"method": "biological", "cost": 45})

		"cancel_task":
			var cancel_count: int = 0
			for p in target_list:
				var t: FarmTile = tiles[p.x][p.y]
				var eff_p: Vector2i = p if not (t.is_multi_tile_root or t.multi_tile_root_pos != Vector2i(-1, -1)) else (p if t.is_multi_tile_root else t.multi_tile_root_pos)
				var c := TaskManager.cancel_task_at(eff_p)
				if c == 0 and eff_p != p:
					c = TaskManager.cancel_task_at(p)
				cancel_count += c
			if cancel_count > 0:
				var display_p: Vector2i = target_list[0] if not target_list.is_empty() else hovered_grid_pos
				show_floating_text(display_p, "🛑 %d Task(s) Cancelled" % cancel_count, Color(1.0, 0.4, 0.4))
				AudioManager.play_ui("click")
				LogManager.log_event("task", "Cancelled %d task(s) via Stop Tool" % cancel_count, "🛑", Color(1.0, 0.5, 0.5))
			else:
				var halted := TaskManager.cancel_active_or_selected_tasks()
				if halted > 0:
					var display_p: Vector2i = target_list[0] if not target_list.is_empty() else hovered_grid_pos
					show_floating_text(display_p, "🛑 Worker Halted", Color(1.0, 0.4, 0.4))
					AudioManager.play_ui("click")
					LogManager.log_event("task", "Halted %d worker(s) via Stop Tool" % halted, "🛑", Color(1.0, 0.5, 0.5))

		_:
			# Tool is a crop seed (e.g. palay, yellow_corn, sugarcane, pineapple, arabica_coffee, banana, coconut)
			var c_data: Dictionary = Data.get_crop(tool_id)
			var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
			var seed_cost: int = int(c_data.get("seed_cost", 25))

			if EconomyManager.cash < seed_cost:
				var target_tile: Vector2i = target_list[0] if not target_list.is_empty() else hovered_grid_pos
				if _is_valid(target_tile):
					show_floating_text(target_tile, "Not enough Money")
				else:
					var m_world: Vector2 = to_local(get_global_mouse_position())
					spawn_floating_text_at_world(m_world, "Not enough Money")
				AudioManager.play_ui("error")
				LogManager.log_event("economy", "Cannot plant %s: Not enough money! (₱%d needed, balance ₱%d)" % [c_data.get("display_name", tool_id), seed_cost, EconomyManager.cash], "⚠️", Color(1.0, 0.35, 0.35))
				return

			if fp == Vector2i(1, 1):
				var plant_targets: Array[Vector2i] = []
				for p in target_list:
					if is_tile_plowed_and_ready(p):
						plant_targets.append(p)
				if plant_targets.size() == 1:
					_on_action_popup_selected("plant", plant_targets[0], {"crop_type": tool_id})
				elif plant_targets.size() > 1:
					var max_afford: int = int(EconomyManager.cash / seed_cost)
					if max_afford <= 0:
						show_floating_text(plant_targets[0], "Not enough Money")
						AudioManager.play_ui("error")
						return
					elif max_afford < plant_targets.size():
						show_floating_text(plant_targets[max_afford], "Not enough Money")
						AudioManager.play_ui("error")
						plant_targets = plant_targets.slice(0, max_afford)
					_on_batch_action_selected("plant", plant_targets, {"crop_type": tool_id})
			else:
				# Multi-tile crop (e.g. 2×2 Coconut Palm, or 4×4)
				if target_list.size() == 1:
					var root_pos: Vector2i = target_list[0]
					var candidate_root: Vector2i = root_pos
					if not can_plant_crop(candidate_root, tool_id):
						for ox in range(fp.x):
							for oy in range(fp.y):
								var test_root: Vector2i = root_pos - Vector2i(ox, oy)
								if can_plant_crop(test_root, tool_id):
									candidate_root = test_root
									break
							if can_plant_crop(candidate_root, tool_id):
								break

					if can_plant_crop(candidate_root, tool_id):
						_on_action_popup_selected("plant", candidate_root, {"crop_type": tool_id})
					else:
						LogManager.log_event("crops", "Cannot plant %s: Requires a clear %d×%d plot of plowed land!" % [c_data.get("display_name", tool_id), fp.x, fp.y], "⚠️", Color(1.0, 0.4, 0.4))
				else:
					var plant_targets: Array[Vector2i] = []
					var covered: Dictionary = {}
					for p in target_list:
						if covered.has(p):
							continue
						if can_plant_crop(p, tool_id):
							plant_targets.append(p)
							for dx in range(fp.x):
								for dy in range(fp.y):
									covered[p + Vector2i(dx, dy)] = true
					if plant_targets.size() == 1:
						_on_action_popup_selected("plant", plant_targets[0], {"crop_type": tool_id})
					elif plant_targets.size() > 1:
						var max_afford: int = int(EconomyManager.cash / seed_cost)
						if max_afford <= 0:
							show_floating_text(plant_targets[0], "Not enough Money")
							AudioManager.play_ui("error")
							return
						elif max_afford < plant_targets.size():
							show_floating_text(plant_targets[max_afford], "Not enough Money")
							AudioManager.play_ui("error")
							plant_targets = plant_targets.slice(0, max_afford)
						_on_batch_action_selected("plant", plant_targets, {"crop_type": tool_id})
					elif plant_targets.is_empty():
						LogManager.log_event("crops", "Cannot plant %s: Requires a clear %d×%d plot of plowed land!" % [c_data.get("display_name", tool_id), fp.x, fp.y], "⚠️", Color(1.0, 0.4, 0.4))

func _on_early_harvest_confirmed(targets: Array) -> void:
	print("[FarmGrid] Early harvest confirmed for %d targets: %s" % [targets.size(), targets])
	_execute_harvest_targets(targets, true)

func _execute_harvest_targets(targets: Array, is_early_confirmed: bool = false) -> void:
	if targets.is_empty():
		return
	# Auto-select worker if none selected so task assignment actually succeeds
	if TaskManager.get_selected_farmers().is_empty():
		var workers := get_tree().get_nodes_in_group("farmers")
		if not workers.is_empty() and is_instance_valid(workers[0]):
			TaskManager.select_farmer(workers[0])

	if targets.size() == 1:
		_on_action_popup_selected("harvest", targets[0], {"early_confirmed": is_early_confirmed})
	elif targets.size() > 1:
		_on_batch_action_selected("harvest", targets, {"early_confirmed": is_early_confirmed})

## Automatically identifies and queues harvest tasks for all mature harvestable crops across unlocked land
func harvest_all_ready_crops() -> void:
	var ready_targets: Array[Vector2i] = []
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var pos := Vector2i(x, y)
			if not is_tile_unlocked(pos):
				continue
			var t: FarmTile = tiles[x][y]
			# Multi-tile crops: only add root plot
			if t.multi_tile_root_pos != Vector2i(-1, -1) and not t.is_multi_tile_root:
				continue
			if t.state == FarmTile.TileState.HARVESTABLE or (t.crop_type != "" and t.growth_progress >= 1.0):
				if not TaskManager.has_task_at(pos, "harvest"):
					ready_targets.append(pos)
	if ready_targets.is_empty():
		LogManager.log_event("crops", "🌾 No mature crops ready for harvest yet!", "ℹ️", Color(0.8, 0.8, 0.8))
		AudioManager.play_ui("click")
		return

	# Ensure workers are selected
	if TaskManager.get_selected_farmers().is_empty():
		var workers := get_tree().get_nodes_in_group("farmers")
		for w in workers:
			if is_instance_valid(w):
				TaskManager.select_farmer(w, true)

	_execute_harvest_targets(ready_targets, false)
	LogManager.log_event("crops", "🌾 Quick Harvest: Dispatched workers to %d mature crop plots!" % ready_targets.size(), "🌾", Color(0.4, 0.9, 0.4))
	AudioManager.play_farmer("harvest")

func _get_drag_rect_tiles(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var g_a := FarmerMovement.pixel_to_grid(to_global(a), self)
	var g_b := FarmerMovement.pixel_to_grid(to_global(b), self)

	var min_x: int = clampi(min(g_a.x, g_b.x), 0, GRID_SIZE.x - 1)
	var max_x: int = clampi(max(g_a.x, g_b.x), 0, GRID_SIZE.x - 1)
	var min_y: int = clampi(min(g_a.y, g_b.y), 0, GRID_SIZE.y - 1)
	var max_y: int = clampi(max(g_a.y, g_b.y), 0, GRID_SIZE.y - 1)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos := Vector2i(x, y)
			if is_tile_unlocked(pos):
				result.append(pos)
	return result

# ---------------------------------------------------------------------------
# Task popup callbacks
# ---------------------------------------------------------------------------
func _on_action_popup_selected(action_type: String, tile_pos: Vector2i, extra: Dictionary) -> void:
	if not is_tile_unlocked(tile_pos):
		return
	if TaskManager.has_task_at(tile_pos, action_type):
		return
	if action_type == "clear_obstacle":
		var cost: int = int(extra.get("cost", 50))
		if not EconomyManager.deduct_cash(cost):
			show_floating_text(tile_pos, "Not enough Money")
			AudioManager.play_ui("error")
			return
	elif action_type == "spray_pest":
		var cost: int = int(extra.get("cost", 30))
		if not EconomyManager.deduct_cash(cost):
			show_floating_text(tile_pos, "Not enough Money")
			AudioManager.play_ui("error")
			return
	elif action_type == "early_harvest":
		var t: FarmTile = tiles[tile_pos.x][tile_pos.y]
		var eff_pos: Vector2i = t.multi_tile_root_pos if t.multi_tile_root_pos != Vector2i(-1, -1) else tile_pos
		if early_harvest_modal:
			early_harvest_modal.open_for_harvest([eff_pos], self)
		else:
			_on_action_popup_selected("harvest", eff_pos, {"early_confirmed": true})
		return
	elif action_type == "harvest":
		var t: FarmTile = tiles[tile_pos.x][tile_pos.y]
		var eff_pos: Vector2i = t.multi_tile_root_pos if t.multi_tile_root_pos != Vector2i(-1, -1) else tile_pos
		var root_t: FarmTile = tiles[eff_pos.x][eff_pos.y]
		var is_early_confirmed: bool = extra.get("early_confirmed", false)
		if not is_early_confirmed and root_t.growth_progress < 1.0 and root_t.state != FarmTile.TileState.HARVESTABLE:
			if early_harvest_modal:
				early_harvest_modal.open_for_harvest([eff_pos], self)
				return
	elif action_type == "plant":
		var crop_name: String = extra.get("crop_type", "")
		if not BuildingManager.is_crop_unlocked(crop_name):
			show_floating_text(tile_pos, "Seed Locked (Agri-Shop)")
			AudioManager.play_ui("error")
			LogManager.log_event("license", "Cannot plant %s: Variety license not yet acquired in Agri-Shop!" % crop_name.capitalize(), "🔒", Color(1.0, 0.4, 0.4))
			return
		var c_data: Dictionary = Data.get_crop(crop_name)
		var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
		var seed_cost: int = int(c_data.get("seed_cost", 25))
		if EconomyManager.cash < seed_cost:
			show_floating_text(tile_pos, "Not enough Money")
			AudioManager.play_ui("error")
			LogManager.log_event("economy", "Cannot plant %s: Not enough money! (₱%d needed, balance ₱%d)" % [c_data.get("display_name", crop_name), seed_cost, EconomyManager.cash], "⚠️", Color(1.0, 0.35, 0.35))
			return
		if fp.x > 1 or fp.y > 1:
			if not can_plant_crop(tile_pos, crop_name):
				LogManager.log_event("crops", "Cannot plant %s: Requires a clear %d×%d plot of plowed land!" % [c_data.get("display_name", crop_name), fp.x, fp.y], "⚠️", Color(1.0, 0.4, 0.4))
				return
	var task: Dictionary = {"type": action_type, "position": tile_pos}
	task.merge(extra)
	TaskManager.assign_tasks([task])
	task_queued.emit(task)
	if drag_overlay:
		drag_overlay.queue_redraw()

func _on_batch_action_selected(action_type: String, target_tiles: Array, extra: Dictionary) -> void:
	if action_type == "early_harvest":
		if early_harvest_modal:
			early_harvest_modal.open_for_harvest(target_tiles, self)
		else:
			_on_batch_action_selected("harvest", target_tiles, {"early_confirmed": true})
		return
	elif action_type == "harvest":
		var is_early_confirmed: bool = extra.get("early_confirmed", false)
		if not is_early_confirmed:
			var has_early: bool = false
			for pos in target_tiles:
				if not _is_valid(pos):
					continue
				var t: FarmTile = tiles[pos.x][pos.y]
				var eff_pos: Vector2i = t.multi_tile_root_pos if t.multi_tile_root_pos != Vector2i(-1, -1) else pos
				var root_t: FarmTile = tiles[eff_pos.x][eff_pos.y]
				if root_t.growth_progress < 1.0 and root_t.state != FarmTile.TileState.HARVESTABLE:
					has_early = true
					break
			if has_early and early_harvest_modal:
				early_harvest_modal.open_for_harvest(target_tiles, self)
				return
	var tasks: Array = []
	var covered_tiles: Dictionary = {}
	var total_plant_cost: int = 0
	for pos in target_tiles:
		if not _is_valid(pos) or not is_tile_unlocked(pos) or TaskManager.has_task_at(pos, action_type):
			continue
		if action_type == "clear_obstacle":
			var cost: int = int(extra.get("cost", 50))
			if not EconomyManager.deduct_cash(cost):
				show_floating_text(pos, "Not enough Money")
				AudioManager.play_ui("error")
				break
		elif action_type == "spray_pest":
			var cost: int = int(extra.get("cost", 30))
			if not EconomyManager.deduct_cash(cost):
				show_floating_text(pos, "Not enough Money")
				AudioManager.play_ui("error")
				break
		elif action_type == "plant":
			var crop_name: String = extra.get("crop_type", "")
			if not BuildingManager.is_crop_unlocked(crop_name):
				show_floating_text(pos, "Seed Locked (Agri-Shop)")
				AudioManager.play_ui("error")
				LogManager.log_event("license", "Cannot plant %s: Variety license not yet acquired in Agri-Shop!" % crop_name.capitalize(), "🔒", Color(1.0, 0.4, 0.4))
				break
			var c_data: Dictionary = Data.get_crop(crop_name)
			var seed_cost: int = int(c_data.get("seed_cost", 25))
			var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
			if fp.x > 1 or fp.y > 1:
				if covered_tiles.has(pos):
					continue
				if not can_plant_crop(pos, crop_name):
					continue
				for dx in range(fp.x):
					for dy in range(fp.y):
						covered_tiles[pos + Vector2i(dx, dy)] = true

			total_plant_cost += seed_cost
			if EconomyManager.cash < total_plant_cost:
				show_floating_text(pos, "Not enough Money")
				AudioManager.play_ui("error")
				break
		var task: Dictionary = {"type": action_type, "position": pos}
		task.merge(extra)
		tasks.append(task)
	TaskManager.assign_tasks(tasks)
	for t in tasks:
		task_queued.emit(t)
	if drag_overlay:
		drag_overlay.queue_redraw()

# ---------------------------------------------------------------------------
# Farm actions  (public API — called by Farmer workers)
# ---------------------------------------------------------------------------
func plow_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.state == FarmTile.TileState.LOCKED:
		return # Blocked by obstacle, building, or locked land
	tile.reset()
	tile.state = FarmTile.TileState.PLOWED
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)
	if drag_overlay:
		drag_overlay.queue_redraw()
	LogManager.log_event("crops", "Plowed soil at (%d, %d)." % [pos.x, pos.y], "🚜", Color(0.72, 0.55, 0.35, 1.0))

## Checks if a single tile is valid plowed soil ready for planting
func is_tile_plowed_and_ready(pos: Vector2i, ignore_pending_tasks: bool = false) -> bool:
	if not _is_valid(pos) or not is_tile_unlocked(pos):
		return false
	var t: FarmTile = tiles[pos.x][pos.y]
	if t.state == FarmTile.TileState.OBSTACLE or t.state == FarmTile.TileState.BUILDING or t.state == FarmTile.TileState.LOCKED:
		return false
	if BuildingManager.is_tile_occupied_by_building(pos):
		return false
	if t.state != FarmTile.TileState.PLOWED:
		return false
	if not ignore_pending_tasks and TaskManager.has_task_at(pos, "plant"):
		return false
	return true

## Checks if a single tile can be plowed (empty uncultivated grass or flooded)
func is_tile_plowable(pos: Vector2i) -> bool:
	if not _is_valid(pos) or not is_tile_unlocked(pos):
		return false
	var t: FarmTile = tiles[pos.x][pos.y]
	if t.state == FarmTile.TileState.OBSTACLE or t.state == FarmTile.TileState.BUILDING or t.state == FarmTile.TileState.LOCKED:
		return false
	if BuildingManager.is_tile_occupied_by_building(pos):
		return false
	if TaskManager.has_task_at(pos, "plow"):
		return false
	return (t.state == FarmTile.TileState.EMPTY or t.state == FarmTile.TileState.FLOODED)

## Returns the footprint Vector2i for a tool or crop
func get_tool_footprint(tool_id: String) -> Vector2i:
	if tool_id in ["plow", "water", "harvest", "clear", "cancel_task", "spray_chemical", "spray_biological", "drone_zone", "drone_recall", "inspect"] or tool_id.is_empty():
		return Vector2i(1, 1)
	var crop_data: Dictionary = Data.get_crop(tool_id)
	return crop_data.get("footprint", Vector2i(1, 1))

## Checks if the given grid position is a valid target for the active hotbar tool/crop
func is_valid_tool_target(pos: Vector2i, tool_id: String) -> bool:
	if not _is_valid(pos) or not is_tile_unlocked(pos):
		return false
	var t: FarmTile = tiles[pos.x][pos.y]
	if t.state == FarmTile.TileState.LOCKED or BuildingManager.is_tile_occupied_by_building(pos):
		return false

	var check_pos: Vector2i = pos
	if t.multi_tile_root_pos != Vector2i(-1, -1):
		check_pos = t.multi_tile_root_pos
	var root_t: FarmTile = tiles[check_pos.x][check_pos.y]

	match tool_id:
		"inspect":
			return true
		"drone_zone", "drone_recall":
			return true
		"cancel_task":
			return TaskManager.has_task_at(pos) or TaskManager.has_task_at(check_pos)
		"plow":
			return is_tile_plowable(pos)
		"water":
			if TaskManager.has_task_at(check_pos, "water") or TaskManager.has_task_at(pos, "water"):
				return false
			return (root_t.state == FarmTile.TileState.PLANTED or root_t.state == FarmTile.TileState.GROWING or root_t.state == FarmTile.TileState.INFECTED)
		"harvest":
			if TaskManager.has_task_at(check_pos, "harvest") or TaskManager.has_task_at(pos, "harvest"):
				return false
			return (root_t.state == FarmTile.TileState.HARVESTABLE \
				or (root_t.state == FarmTile.TileState.FLOODED and root_t.crop_type != "") \
				or (root_t.crop_type != "" and root_t.state in [FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING, FarmTile.TileState.INFECTED]))
		"clear":
			if TaskManager.has_task_at(pos, "clear_obstacle"):
				return false
			return (t.state == FarmTile.TileState.OBSTACLE)
		"spray_chemical", "spray_biological":
			if TaskManager.has_task_at(check_pos, "spray_pest") or TaskManager.has_task_at(pos, "spray_pest"):
				return false
			return (root_t.state in [FarmTile.TileState.PLOWED, FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING, FarmTile.TileState.INFECTED, FarmTile.TileState.HARVESTABLE])
		_:
			return can_plant_crop(pos, tool_id)

## Checks if a 1×1 or multi-tile (2×2, 4×4) crop can be planted at the target position
func can_plant_crop(pos: Vector2i, crop_name: String, ignore_pending_tasks: bool = false) -> bool:
	if not _is_valid(pos):
		return false
	var crop_data: Dictionary = Data.get_crop(crop_name)
	var fp: Vector2i = crop_data.get("footprint", Vector2i(1, 1))
	for dx in range(fp.x):
		for dy in range(fp.y):
			var p := pos + Vector2i(dx, dy)
			if not is_tile_plowed_and_ready(p, ignore_pending_tasks):
				return false
	return true

func plant_crop(pos: Vector2i, crop_name: String) -> void:
	if not _is_valid(pos):
		return
	var crop_data: Dictionary = Data.get_crop(crop_name)
	var fp: Vector2i = crop_data.get("footprint", Vector2i(1, 1))
	var seed_cost: int = int(crop_data.get("seed_cost", 25))

	if fp.x > 1 or fp.y > 1:
		if not can_plant_crop(pos, crop_name, true):
			LogManager.log_event("crops", "Cannot plant %s: Requires a clear %d×%d plot of plowed land!" % [crop_data.get("display_name", crop_name), fp.x, fp.y], "⚠️", Color(1.0, 0.4, 0.4))
			return
		if not EconomyManager.deduct_cash(seed_cost):
			show_floating_text(pos, "Not enough Money")
			AudioManager.play_ui("error")
			LogManager.log_event("economy", "Cannot plant %s: Not enough money! (₱%d needed, balance ₱%d)" % [crop_data.get("display_name", crop_name), seed_cost, EconomyManager.cash], "⚠️", Color(1.0, 0.35, 0.35))
			print("[FarmGrid] Not enough cash to plant %s!" % crop_name)
			return

		var region_data: Dictionary = Data.get_region(Data.current_region)
		var base_moisture: float = float(region_data.get("soil_moisture", 60))

		for dx in range(fp.x):
			for dy in range(fp.y):
				var p := pos + Vector2i(dx, dy)
				var t: FarmTile = tiles[p.x][p.y]
				t.crop_type       = crop_name
				t.state           = FarmTile.TileState.PLANTED
				t.growth_progress = 0.0
				t.health          = 1.0
				t.quality         = FarmTile.QualityGrade.A
				t.soil_moisture   = base_moisture
				t.days_overwatered = 0
				t.pest_type       = ""
				t.yield_quantity  = int(crop_data.get("yield_quantity", 400))
				t.multi_tile_root_pos = pos
				t.is_multi_tile_root = (dx == 0 and dy == 0)
				PestManager.evaluate_spawn(p, crop_name, int(t.soil_moisture))
				renderer.update_tile(p, tiles)

		tile_inspected.emit(pos, tiles[pos.x][pos.y])
		if drag_overlay:
			drag_overlay.queue_redraw()
		LogManager.log_event("crops", "Planted %d×%d %s at (%d, %d)." % [fp.x, fp.y, crop_data.get("display_name", crop_name), pos.x, pos.y], crop_data.get("icon", "🌱"), Color(0.45, 0.85, 0.4, 1.0))
		return

	# Standard 1×1 crop
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state != FarmTile.TileState.PLOWED:
		return

	if not EconomyManager.deduct_cash(seed_cost):
		show_floating_text(pos, "Not enough Money")
		AudioManager.play_ui("error")
		LogManager.log_event("economy", "Cannot plant %s: Not enough money! (₱%d needed, balance ₱%d)" % [crop_data.get("display_name", crop_name), seed_cost, EconomyManager.cash], "⚠️", Color(1.0, 0.35, 0.35))
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
	tile.yield_quantity  = int(crop_data.get("yield_quantity", 100))
	tile.multi_tile_root_pos = Vector2i(-1, -1)
	tile.is_multi_tile_root = false

	PestManager.evaluate_spawn(pos, crop_name, int(tile.soil_moisture))
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)
	if drag_overlay:
		drag_overlay.queue_redraw()
	LogManager.log_event("crops", "Planted %s at (%d, %d)." % [crop_data.get("display_name", crop_name), pos.x, pos.y], "🌱", Color(0.45, 0.85, 0.4, 1.0))

func water_tile(pos: Vector2i, amount: float = 25.0) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.state == FarmTile.TileState.LOCKED:
		return

	var target_pos: Vector2i = tile.multi_tile_root_pos if tile.multi_tile_root_pos != Vector2i(-1, -1) else pos
	var root_t: FarmTile = tiles[target_pos.x][target_pos.y]
	root_t.soil_moisture = clampf(root_t.soil_moisture + amount, 0.0, 100.0)

	if root_t.is_multi_tile_root:
		_sync_multi_tile_children(target_pos)
		for dx in range(2):
			for dy in range(2):
				var p := target_pos + Vector2i(dx, dy)
				if _is_valid(p):
					renderer.update_tile(p, tiles)
	else:
		renderer.update_tile(pos, tiles)

	tile_inspected.emit(pos, tile)
	LogManager.log_event("crops", "Watered plot at (%d, %d) (+%.0f%% moisture)." % [pos.x, pos.y, amount], "💧", Color(0.4, 0.7, 0.95, 1.0))

func spray_pest(pos: Vector2i, method: String) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.FLOODED \
		or tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING \
		or tile.state == FarmTile.TileState.LOCKED:
		return

	var cost: int = 30 if method == "chemical" else 45
	if not EconomyManager.deduct_cash(cost):
		return

	var target_pos: Vector2i = tile.multi_tile_root_pos if tile.multi_tile_root_pos != Vector2i(-1, -1) else pos
	var root_t: FarmTile = tiles[target_pos.x][target_pos.y]

	match method:
		"chemical":
			root_t.pest_type = ""
			if root_t.quality == FarmTile.QualityGrade.A:
				root_t.quality = FarmTile.QualityGrade.B
			root_t.soil_fertility = maxf(root_t.soil_fertility - 0.10, 0.4)
			root_t.soil_moisture  = maxf(root_t.soil_moisture  - 10.0,  0.0)
		"biological":
			root_t.pest_type = ""
		_:
			root_t.pest_type = ""

	root_t.state = FarmTile.TileState.HARVESTABLE if root_t.growth_progress >= 1.0 else FarmTile.TileState.GROWING if root_t.crop_type != "" else FarmTile.TileState.EMPTY
	PestManager.treat_tile(target_pos, method)

	if root_t.is_multi_tile_root:
		_sync_multi_tile_children(target_pos)
		for dx in range(2):
			for dy in range(2):
				var p := target_pos + Vector2i(dx, dy)
				if _is_valid(p):
					renderer.update_tile(p, tiles)
	else:
		renderer.update_tile(pos, tiles)

	tile_inspected.emit(pos, tile)
	LogManager.log_event("hazards", "Sprayed %s treatment on plot (%d, %d)." % [method, pos.x, pos.y], "🧴", Color(0.9, 0.75, 0.3, 1.0))

func harvest_tile(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING \
		or tile.crop_type == "" or tile.state == FarmTile.TileState.EMPTY or tile.state == FarmTile.TileState.PLOWED \
		or tile.state == FarmTile.TileState.LOCKED:
		return

	# Handle 2x2 multi-tile root redirection
	var root_pos: Vector2i = tile.multi_tile_root_pos if tile.multi_tile_root_pos != Vector2i(-1, -1) else pos
	var root_tile: FarmTile = tiles[root_pos.x][root_pos.y]

	var crop_name_harvested: String = root_tile.crop_type
	if not BuildingManager.has_storage_for_crop(crop_name_harvested, 100):
		LogManager.log_event("crops", "Cannot harvest plot (%d, %d): No storage facility accepting %s has space (%d/%d used)! Adjust crop routing on your storage buildings or sell crops." % [pos.x, pos.y, crop_name_harvested.capitalize(), BuildingManager.used_storage, BuildingManager.total_storage_capacity], "⚠️", Color(1.0, 0.35, 0.35, 1.0))
		return
	var crop_data: Dictionary = Data.get_crop(crop_name_harvested)
	var is_2x2: bool = (crop_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2))
	var is_perennial: bool = crop_data.get("is_perennial", false)
	var regrowth_days: int = int(crop_data.get("regrowth_days", 0))

	var harvest_info: Dictionary = TileAgronomySystem.calculate_harvest(root_tile)
	var quantity: int = int(harvest_info.get("yield", 0))
	var grade_str: String = str(harvest_info.get("grade_string", "Grade C"))

	# Deposit into Farm Storage
	MarketManager.add_harvest_to_storage(crop_name_harvested, quantity, grade_str, 100.0)

	if is_2x2:
		# Multi-tile crop (e.g. 2×2 Coconut Palm)
		for dx in range(2):
			for dy in range(2):
				var p := root_pos + Vector2i(dx, dy)
				if _is_valid(p):
					var t: FarmTile = tiles[p.x][p.y]
					if is_perennial:
						var total_g_days: float = float(crop_data.get("growth_days", 50))
						var reg_prog: float = clampf(1.0 - (float(regrowth_days) / maxf(total_g_days, 1.0)), 0.3, 0.85)
						if root_tile.growth_progress >= reg_prog:
							t.growth_progress = reg_prog
						else:
							t.growth_progress = clampf(root_tile.growth_progress * 0.4, 0.1, reg_prog)
						t.state = FarmTile.TileState.GROWING
						t.quality = FarmTile.QualityGrade.A
						t.is_regrowing = true  # Show "no crop" regrowth sprite
					else:
						t.reset()
					renderer.update_tile(p, tiles)
		tile_inspected.emit(root_pos, root_tile)
		if is_perennial:
			LogManager.log_event("crops", "Harvested %d units of %s (%s). Palm remains standing and will regrow in %d days!" % [quantity, crop_data.get("display_name", crop_name_harvested), grade_str, regrowth_days], "🥥", Color(0.95, 0.85, 0.3, 1.0))
		else:
			LogManager.log_event("crops", "Harvested %d units of %s (%s) from 2×2 grove (%d, %d)." % [quantity, crop_data.get("display_name", crop_name_harvested), grade_str, root_pos.x, root_pos.y], "🌾", Color(0.95, 0.85, 0.3, 1.0))
	else:
		# 1×1 crop
		if is_perennial:
			var total_g_days: float = float(crop_data.get("growth_days", 40))
			var reg_prog: float = clampf(1.0 - (float(regrowth_days) / maxf(total_g_days, 1.0)), 0.3, 0.85)
			if tile.growth_progress >= reg_prog:
				tile.growth_progress = reg_prog
			else:
				tile.growth_progress = clampf(tile.growth_progress * 0.4, 0.1, reg_prog)
			tile.state = FarmTile.TileState.GROWING
			tile.quality = FarmTile.QualityGrade.A
			tile.is_regrowing = true  # Show "no crop" regrowth sprite
			renderer.update_tile(pos, tiles)
			tile_inspected.emit(pos, tile)
			LogManager.log_event("crops", "Harvested %d units of %s (%s). Plant remains standing and will regrow in %d days!" % [quantity, crop_data.get("display_name", crop_name_harvested), grade_str, regrowth_days], "🌿", Color(0.95, 0.85, 0.3, 1.0))
		else:
			tile.reset()
			renderer.update_tile(pos, tiles)
			tile_inspected.emit(pos, tile)
			LogManager.log_event("crops", "Harvested %d units of %s (%s) from plot (%d, %d)." % [quantity, crop_name_harvested.capitalize(), grade_str, pos.x, pos.y], "🌾", Color(0.95, 0.85, 0.3, 1.0))

func _sync_multi_tile_children(root_pos: Vector2i) -> void:
	if not _is_valid(root_pos):
		return
	var root_tile: FarmTile = tiles[root_pos.x][root_pos.y]
	for dx in range(2):
		for dy in range(2):
			if dx == 0 and dy == 0:
				continue
			var p := root_pos + Vector2i(dx, dy)
			if _is_valid(p):
				var child_t: FarmTile = tiles[p.x][p.y]
				child_t.state           = root_tile.state
				child_t.growth_progress = root_tile.growth_progress
				child_t.health          = root_tile.health
				child_t.quality         = root_tile.quality
				child_t.soil_moisture   = root_tile.soil_moisture
				child_t.pest_type       = root_tile.pest_type
				child_t.yield_quantity  = root_tile.yield_quantity
				child_t.is_regrowing    = root_tile.is_regrowing

func clear_obstacle(pos: Vector2i) -> void:
	if not _is_valid(pos):
		return
	var tile: FarmTile = tiles[pos.x][pos.y]
	if tile.state != FarmTile.TileState.OBSTACLE:
		return
	var is_rock: bool = (tile.obstacle_type == "rock")
	var obs_name: String = "granite boulder" if is_rock else "old tree stump"
	var obs_icon: String = "⛏️" if is_rock else "🪓"
	tile.reset()
	if is_tile_unlocked(pos):
		tile.state = FarmTile.TileState.EMPTY
	else:
		tile.state = FarmTile.TileState.LOCKED
	renderer.update_tile(pos, tiles)
	tile_inspected.emit(pos, tile)
	# Clash of Clans resource bonus for clearing obstacles (salvage ₱15)
	EconomyManager.add_cash(15)
	LogManager.log_event("buildings", "Cleared %s at (%d, %d) (+₱15 salvage)." % [obs_name, pos.x, pos.y], obs_icon, Color(0.7, 0.6, 0.45, 1.0))


# ---------------------------------------------------------------------------
# Time & climate callbacks  (delegate heavy simulation to TileAgronomySystem)
# ---------------------------------------------------------------------------
func _on_day_changed(_day: int) -> void:
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			# Multi-tile child plots mirror root simulation
			if tile.multi_tile_root_pos != Vector2i(-1, -1) and not tile.is_multi_tile_root:
				continue
			if tile.state == FarmTile.TileState.PLANTED or tile.state == FarmTile.TileState.GROWING:
				TileAgronomySystem.process_day(tile, Vector2i(x, y))
				if tile.is_multi_tile_root:
					_sync_multi_tile_children(Vector2i(x, y))
	renderer.update_all(tiles, GRID_SIZE)

func _on_hour_changed(_hour: int) -> void:
	var has_drip: bool = BuildingManager.has_tech("drip_irrigation")
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null:
				continue
			if tile.multi_tile_root_pos != Vector2i(-1, -1) and not tile.is_multi_tile_root:
				continue
			TileAgronomySystem.process_hour(tile, has_drip, Vector2i(x, y))
			if tile.is_multi_tile_root:
				_sync_multi_tile_children(Vector2i(x, y))
	renderer.update_all(tiles, GRID_SIZE)

func _on_pest_spawned(pest: String, pos: Vector2i) -> void:
	if _is_valid(pos):
		var tile: FarmTile = tiles[pos.x][pos.y]
		if tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null or tile.state == FarmTile.TileState.LOCKED:
			return
		tile.state    = FarmTile.TileState.INFECTED
		tile.pest_type = pest
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

func _on_weather_changed(_t: float, _h: float) -> void:
	# Immediate moisture response when climate switches:
	# Rain onset → soil instantly absorbs a starter burst (+20 to +35)
	# Drought onset → soil instantly loses moisture (-15 to -25)
	# Normal → gentle re-centre toward 50-65 range
	var wm = WeatherManager
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.state == FarmTile.TileState.LOCKED or tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null:
				continue
			match wm.current_climate:
				wm.Climate.LA_NINA:
					var rain_burst: float = randf_range(20.0, 35.0)
					tile.soil_moisture = minf(tile.soil_moisture + rain_burst, 100.0)
				wm.Climate.EL_NINO:
					var dry_shock: float = randf_range(15.0, 25.0)
					tile.soil_moisture = maxf(tile.soil_moisture - dry_shock, 0.0)
				wm.Climate.NORMAL:
					# Gentle re-centering — don't snap, just nudge toward a comfortable range
					if tile.soil_moisture > 75.0:
						tile.soil_moisture = maxf(tile.soil_moisture - 10.0, 60.0)
					elif tile.soil_moisture < 30.0:
						tile.soil_moisture = minf(tile.soil_moisture + 10.0, 45.0)
	renderer.update_all(tiles, GRID_SIZE)

func _on_disaster_warning(_hazard: String, _countdown: float = 5.0) -> void:
	pass

func _on_disaster_struck(hazard_type: String) -> void:
	match hazard_type:
		"flash_flood":
			_process_flash_flood_impact()
		"el_nino_drought":
			_process_drought_impact()
		"landslide":
			_process_landslide_impact()

func _process_flash_flood_impact() -> void:
	var total_crops: int = 0
	var survived_crops: int = 0
	var flooded_crops: int = 0

	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.crop_type == "" and tile.state != FarmTile.TileState.PLOWED:
				continue
			if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null or tile.state == FarmTile.TileState.FLOODED:
				continue

			total_crops += 1

			# Base survival chance: 60% (Fair chance to withstand flash flood)
			var survival_chance: float = 0.60

			# Crop species hardiness
			if tile.crop_type == "palay":
				survival_chance += 0.20 # Rice has 80% baseline flood survival
			elif tile.crop_type == "arabica_coffee":
				survival_chance -= 0.15 # Highland coffee is sensitive to waterlogging
			elif tile.crop_type == "coconut":
				survival_chance += 0.15 # Deep palm root system

			# Crop health modifier
			if tile.health >= 0.8:
				survival_chance += 0.15
			elif tile.health < 0.4:
				survival_chance -= 0.20

			# Infrastructure / tech bonus
			if BuildingManager.has_tech("drip_irrigation"):
				survival_chance += 0.15 # Drainage ditches prevent pooling

			survival_chance = clampf(survival_chance, 0.25, 0.95)

			if randf() < survival_chance:
				# CROP SURVIVED!
				survived_crops += 1
				tile.soil_moisture = 95.0
				tile.health = maxf(tile.health - 0.20, 0.25)
				if tile.quality == FarmTile.QualityGrade.A:
					tile.quality = FarmTile.QualityGrade.B
				elif tile.quality == FarmTile.QualityGrade.B:
					tile.quality = FarmTile.QualityGrade.C
			else:
				# CROP FLOODED / LOST
				flooded_crops += 1
				tile.state = FarmTile.TileState.FLOODED
				tile.soil_moisture = 100.0
				tile.health = 0.20
				tile.quality = FarmTile.QualityGrade.C
				tile.yield_quantity = int(tile.yield_quantity * 0.4)

	renderer.update_all(tiles, GRID_SIZE)

	if total_crops > 0:
		var pct: int = int((float(survived_crops) / float(total_crops)) * 100.0)
		LogManager.log_event("hazards", "🌊 Flash flood swept the farm! %d/%d crops survived (%d%% resilience), %d flooded." % [survived_crops, total_crops, pct, flooded_crops], "🌊", Color(0.35, 0.7, 1.0))

func _process_drought_impact() -> void:
	var total_crops: int = 0
	var survived_crops: int = 0
	var withered_crops: int = 0

	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var tile: FarmTile = tiles[x][y]
			if tile.crop_type == "":
				continue
			if tile.state == FarmTile.TileState.OBSTACLE or tile.state == FarmTile.TileState.BUILDING or tile.building_ref != null or tile.state == FarmTile.TileState.FLOODED:
				continue

			total_crops += 1
			var survival_chance: float = 0.65

			if tile.crop_type == "yellow_corn" or tile.crop_type == "coconut":
				survival_chance += 0.25 # Heat/drought hardy
			if BuildingManager.has_tech("drip_irrigation"):
				survival_chance += 0.20
			if tile.soil_moisture > 40.0:
				survival_chance += 0.15

			survival_chance = clampf(survival_chance, 0.25, 0.95)

			if randf() < survival_chance:
				survived_crops += 1
				tile.soil_moisture = maxf(tile.soil_moisture - 20.0, 5.0)
				tile.health = maxf(tile.health - 0.15, 0.30)
			else:
				withered_crops += 1
				tile.soil_moisture = 0.0
				tile.health = maxf(tile.health - 0.45, 0.10)
				tile.quality = FarmTile.QualityGrade.C

	renderer.update_all(tiles, GRID_SIZE)

	if total_crops > 0:
		var pct: int = int((float(survived_crops) / float(total_crops)) * 100.0)
		LogManager.log_event("hazards", "🔥 Severe heatwave swept the farm! %d/%d crops survived (%d%%), %d withered." % [survived_crops, total_crops, pct, withered_crops], "🔥", Color(1.0, 0.6, 0.2))

func _process_landslide_impact() -> void:
	var total_affected: int = 0
	var count: int = randi_range(2, 4)
	for i in range(count):
		var rx: int = randi() % GRID_SIZE.x
		var ry: int = randi() % GRID_SIZE.y
		var pos := Vector2i(rx, ry)
		if not is_tile_unlocked(pos):
			continue
		var tile: FarmTile = tiles[rx][ry]
		if tile.state != FarmTile.TileState.BUILDING and tile.building_ref == null and tile.state != FarmTile.TileState.OBSTACLE:
			total_affected += 1
			tile.reset()
			tile.state = FarmTile.TileState.OBSTACLE
	renderer.update_all(tiles, GRID_SIZE)
	LogManager.log_event("hazards", "🌪️ Landslide deposited %d mud/rock debris obstacles on the grid!" % total_affected, "🌪️", Color(0.8, 0.4, 0.3))

# ---------------------------------------------------------------------------
# Building Placement  (public API — called by ShopPanel)
# ---------------------------------------------------------------------------

## Begin placement mode: player drags ghost footprint to choose where to build.
func start_building_placement(b_type: String) -> void:
	var b_data: Dictionary = Data.get_building(b_type)
	if b_data.is_empty():
		push_warning("[FarmGrid] Unknown building type: %s" % b_type)
		return
	if BuildingManager.is_unique_building(b_type) and BuildingManager.owns_building(b_type):
		LogManager.log_event("general", "%s is already built — click it to upgrade instead." % str(b_data.get("display_name", b_type)), "🏗️", Color(1.0, 0.75, 0.3))
		return

	is_placing_building   = true
	placing_building_type = b_type
	placing_footprint     = b_data.get("grid_size", Vector2i(2, 2))
	placing_is_flipped    = false

	# Seed the hover position to grid centre so overlay appears immediately
	placing_hover_grid_pos = Vector2i(
		GRID_SIZE.x / 2 - placing_footprint.x / 2,
		GRID_SIZE.y / 2 - placing_footprint.y / 2
	)

	if placement_overlay:
		placement_overlay.queue_redraw()

## Cancel placement mode without building anything.
func cancel_building_placement() -> void:
	if is_placing_building:
		AudioManager.play_building("cancel")
	is_placing_building   = false
	placing_building_type = ""
	if placement_overlay:
		placement_overlay.queue_redraw()

## Returns true if the given footprint starting at start_pos is fully within bounds
## and every tile is free (not OBSTACLE, not BUILDING, not FLOODED).
func is_valid_building_placement(start_pos: Vector2i, fp: Vector2i) -> bool:
	if placing_building_type == "sprinkler":
		if not BuildingManager.has_irrigation() or not BuildingManager.can_place_sprinkler():
			return false
	elif Data.get_building(placing_building_type).get("requires_shore", false):
		if (start_pos.x + fp.x) != GRID_SIZE.x:
			return false
	elif Data.get_building(placing_building_type).get("shop_category", "") == "processing":
		if not BuildingManager.get_processing_prerequisites(placing_building_type).allowed:
			return false

	for dx in range(fp.x):
		for dy in range(fp.y):
			var check := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if not _is_valid(check):
				return false
			if check in [Vector2i(0, 4), Vector2i(12, 4), Vector2i(4, 12), Vector2i(12, 16)]:
				return false
			var tile: FarmTile = tiles[check.x][check.y]
			if tile.state == FarmTile.TileState.OBSTACLE \
				or tile.state == FarmTile.TileState.BUILDING \
				or tile.state == FarmTile.TileState.FLOODED \
				or tile.state == FarmTile.TileState.LOCKED \
				or tile.crop_type != "":
				return false
	return true

## Attempt to place the building at start_pos.  Returns true on success.
func place_building(start_pos: Vector2i, b_type: String) -> bool:
	var b_data: Dictionary = Data.get_building(b_type)
	if b_data.is_empty():
		return false

	if BuildingManager.is_unique_building(b_type) and BuildingManager.owns_building(b_type):
		cancel_building_placement()
		return false

	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
	placing_building_type = b_type
	placing_footprint     = fp

	if b_type == "sprinkler":
		if not BuildingManager.has_irrigation():
			show_floating_text(start_pos, "Requires Irrigation Tower!", Color(1.0, 0.35, 0.35))
			AudioManager.play_building("invalid")
			cancel_building_placement()
			return false
		if not BuildingManager.can_place_sprinkler():
			show_floating_text(start_pos, "Water pressure maxed!", Color(1.0, 0.35, 0.35))
			AudioManager.play_building("invalid")
			cancel_building_placement()
			return false
	elif b_data.get("requires_shore", false) and (start_pos.x + fp.x) != GRID_SIZE.x:
		show_floating_text(start_pos, "Must be placed along eastern coastline!", Color(0.4, 0.8, 1.0))
		AudioManager.play_building("invalid")
		return false
	elif b_data.get("shop_category", "") == "processing":
		var prereqs: Dictionary = BuildingManager.get_processing_prerequisites(b_type)
		if not prereqs.allowed:
			show_floating_text(start_pos, prereqs.requirement_text, Color(1.0, 0.35, 0.35))
			AudioManager.play_building("invalid")
			cancel_building_placement()
			return false

	if not is_valid_building_placement(start_pos, fp):
		AudioManager.play_building("invalid")
		if placement_overlay:
			placement_overlay.queue_redraw()
		return false

	# Deduct cost
	var cost: int = int(b_data.get("cost", 400))
	if not EconomyManager.deduct_cash(cost):
		return false

	# Mark tiles as BUILDING and reset crop / moisture data so tiles are stale/protected
	for dx in range(fp.x):
		for dy in range(fp.y):
			var tp := Vector2i(start_pos.x + dx, start_pos.y + dy)
			var t: FarmTile = tiles[tp.x][tp.y]
			t.crop_type = ""
			t.growth_progress = 0.0
			t.health = 1.0
			t.pest_type = ""
			t.hours_waterlogged = 0
			t.days_overwatered = 0
			t.days_without_water = 0
			t.soil_moisture = 55.0
			t.state        = FarmTile.TileState.BUILDING
			t.building_ref = null

	# Instantiate Building node
	var b_script: GDScript = load("res://src/buildings/Building.gd")
	var building := Node2D.new()
	building.set_script(b_script)
	building.name          = "Building_%s_%d_%d" % [b_type, start_pos.x, start_pos.y]
	building.building_type = b_type
	building.grid_pos      = start_pos
	building.footprint     = fp
	building.duration      = 0.0 if (Data.game_mode == "sandbox" or b_data.get("is_decoration", false)) else float(b_data.get("build_time", 20.0))
	building.is_flipped    = placing_is_flipped
	if Data.game_mode == "sandbox" or b_data.get("is_decoration", false):
		building.state     = Building.BuildingState.ACTIVE

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
	if building.building_type == "weather_station":
		if weather_app_modal and is_instance_valid(weather_app_modal):
			weather_app_modal.open_for_station(building)
			return
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
				var t: FarmTile = tiles[tp.x][tp.y]
				t.state         = FarmTile.TileState.EMPTY
				t.building_ref  = null
				t.crop_type     = ""
				t.pest_type     = ""
				t.hours_waterlogged = 0
				t.days_overwatered = 0
				t.soil_moisture = 60.0
				renderer.update_tile(tp, tiles)

	BuildingManager.unregister_building(building)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE.x and pos.y >= 0 and pos.y < GRID_SIZE.y

# ---------------------------------------------------------------------------
# Precision Drone Fleet Management
# ---------------------------------------------------------------------------
func _sync_drones() -> void:
	var target_count: int = BuildingManager.get_drone_capacity()
	var valid_drones: Array = []
	for d in drones:
		if is_instance_valid(d):
			valid_drones.append(d)
	drones = valid_drones

	while drones.size() < target_count:
		var d := FarmDrone.new()
		d.farm_grid = self
		add_child(d)
		drones.append(d)

	while drones.size() > target_count:
		var d = drones.pop_back()
		if is_instance_valid(d):
			d.queue_free()

	# Build home docking berths from active Drone Landing Pads and Hangar
	var pads: Array = BuildingManager.get_drone_pads()
	var station: Node = BuildingManager.get_drone_station()
	var berths: Array = []

	for p in pads:
		var p_lvl: int = clampi(p.level, 1, 3)
		if p_lvl == 1:
			berths.append({"node": p, "offset": Vector2(0.0, -14.0)})
		elif p_lvl == 2:
			berths.append({"node": p, "offset": Vector2(-12.0, -10.0)})
			berths.append({"node": p, "offset": Vector2(12.0, -10.0)})
		else:
			berths.append({"node": p, "offset": Vector2(0.0, -18.0)})
			berths.append({"node": p, "offset": Vector2(-14.0, -8.0)})
			berths.append({"node": p, "offset": Vector2(14.0, -8.0)})

	# Fallback to station for any remaining drones (e.g. starter drone before pads built)
	while berths.size() < drones.size() and station != null:
		var extra_idx: int = berths.size()
		var offset := Vector2(0.0, -14.0) if extra_idx == 0 else Vector2(-12.0 + (extra_idx * 8.0), -10.0)
		berths.append({"node": station, "offset": offset})

	for i in range(drones.size()):
		var d: FarmDrone = drones[i]
		if i < berths.size():
			d.hangar_ref = berths[i].node
			d.berth_offset = berths[i].offset
		elif station:
			d.hangar_ref = station
			d.berth_offset = Vector2(0.0, -14.0)
		d.drone_index = i + 1
		d.name = "FarmDrone_%d" % (i + 1)
		d.is_selected = (d.drone_index == selected_drone_index)

	if selected_drone_index > 0 and selected_drone_index > drones.size():
		selected_drone_index = drones.size()

func _on_drone_commissioned(_total: int) -> void:
	_sync_drones()

func get_selected_drone() -> FarmDrone:
	if selected_drone_index <= 0:
		return null
	for d in drones:
		if is_instance_valid(d) and d.drone_index == selected_drone_index:
			return d
	return null

func deselect_all_drones() -> void:
	selected_drone_index = 0
	for d in drones:
		if is_instance_valid(d):
			d.is_selected = false
			if is_instance_valid(d._zone_layer):
				d._zone_layer.queue_redraw()
	drone_selected.emit(0)

func select_drone_by_index(idx: int) -> void:
	selected_drone_index = idx
	for d in drones:
		if is_instance_valid(d):
			d.is_selected = (d.drone_index == selected_drone_index)
			if is_instance_valid(d._zone_layer):
				d._zone_layer.queue_redraw()
	drone_selected.emit(selected_drone_index)
	var sel_d := get_selected_drone()
	if sel_d:
		TaskManager.deselect_all_farmers()
		AudioManager.play_ui("click")
		var crop_disp: String = str(Data.get_crop(sel_d.crop_type).get("display_name", sel_d.crop_type))
		show_floating_text(FarmerMovement.pixel_to_grid(sel_d.global_position, self) if _is_valid(FarmerMovement.pixel_to_grid(sel_d.global_position, self)) else Vector2i(0, 0), "🛸 %s Selected (%s)" % [sel_d.get_drone_name(), crop_disp], Color(0.4, 0.9, 1.0))
		LogManager.log_event("general", "🛸 Selected %s (Lv.%d, Crop: %s)." % [sel_d.get_drone_name(), sel_d.get_level(), crop_disp], "🛸", Color(0.4, 0.85, 1.0))

func select_drone(d: FarmDrone) -> void:
	if is_instance_valid(d):
		select_drone_by_index(d.drone_index)

func recall_drone(idx: int) -> void:
	for d in drones:
		if is_instance_valid(d) and d.drone_index == idx:
			d.recall()
			break

func recall_all_drones() -> void:
	for d in drones:
		if is_instance_valid(d):
			d.recall()

func is_tile_targeted_by_other_drone(pos: Vector2i, asking_drone: FarmDrone) -> bool:
	for d in drones:
		if d == asking_drone or not is_instance_valid(d):
			continue
		if not d.job.is_empty() and d.job.get("pos", Vector2i(-1, -1)) == pos:
			return true
	return false

func start_drone_zone_designation(crop_name: String = "", drone_idx: int = 0) -> void:
	if drone_idx > 0:
		select_drone_by_index(drone_idx)
	var d := get_selected_drone()
	if d and not crop_name.is_empty() and Data.CROPS.has(crop_name):
		d.set_crop(crop_name)
	is_drone_targeting = true
	TaskManager.deselect_all_farmers()
	selected_tiles.clear()
	if drag_overlay:
		drag_overlay.queue_redraw()
	var d_name: String = d.get_drone_name() if d else "Drone"
	var c_name: String = d.crop_type.capitalize() if d else "Palay"
	LogManager.log_event("crops", "🎯 %s Targeting: Drag a box on your farm to set automation zone for %s." % [d_name, c_name], "🛸", Color(0.40, 0.88, 1.0))
	AudioManager.play_ui("click")

func cancel_drone_zone_designation() -> void:
	if is_drone_targeting:
		is_drone_targeting = false
		if drag_overlay:
			drag_overlay.queue_redraw()
		AudioManager.play_ui("click")

func get_all_unlocked_tiles() -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var p := Vector2i(x, y)
			if is_tile_unlocked(p):
				res.append(p)
	return res

func deploy_drone_whole_farm(crop: String = "") -> void:
	if drones.is_empty():
		return
	var target_drone: FarmDrone = get_selected_drone()
	if target_drone:
		target_drone.deploy_whole_farm(crop)

func _open_drone_command_deck() -> void:
	var deck = get_tree().root.find_child("DroneCommandDeck", true, false)
	if deck and deck.has_method("open"):
		deck.open()

func toggle_heatmap() -> void:
	if heatmap_overlay:
		heatmap_overlay.toggle()

func get_heatmap_overlay() -> FarmHeatmapOverlay:
	return heatmap_overlay
