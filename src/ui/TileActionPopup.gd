# TileActionPopup.gd
# Context-sensitive popup menu for selecting farm tile actions.

class_name TileActionPopup
extends PopupMenu

const PlantHotbarScript = preload("res://src/ui/PlantHotbar.gd")

signal action_selected(action_type: String, tile_pos: Vector2i, extra_data: Dictionary)
signal batch_action_selected(action_type: String, target_tiles: Array, extra_data: Dictionary)

enum ActionId {
	TITLE_HEADER = 99,
	PLOW = 100,
	PLANT_PALAY = 201,
	PLANT_CORN = 202,
	PLANT_COFFEE = 203,
	PLANT_BANANA = 204,
	PLANT_COCONUT = 205,
	PLANT_PINEAPPLE = 206,
	PLANT_SUGARCANE = 207,
	PLANT_ACTIVE = 200,
	OPEN_PLANT_HOTBAR = 208,
	WATER = 300,
	SPRAY_CHEMICAL = 401,
	SPRAY_BIOLOGICAL = 402,
	HARVEST = 500,
	EARLY_HARVEST = 501,
	HARVEST_ALL = 502,
	CANCEL_TASKS = 600,
	CLEAR_OBSTACLE = 700,
	UNLOCK_LAND = 800,
	PARCEL_DIRECTIVES = 850,
}

var is_batch_mode: bool = false
var current_tile_pos: Vector2i = Vector2i(-1, -1)
var current_tile: FarmTile = null

# Cached batch targets
var batch_tiles: Array = []
var batch_empty_or_flooded: Array[Vector2i] = []
var batch_plowed: Array[Vector2i] = []
var batch_can_water: Array[Vector2i] = []
var batch_can_spray: Array[Vector2i] = []
var batch_harvestable: Array[Vector2i] = []
var batch_growing_crops: Array[Vector2i] = []
var batch_obstacles: Array[Vector2i] = []

func _ready() -> void:
	id_pressed.connect(_on_id_pressed)
	_apply_rustic_style()

func _apply_rustic_style() -> void:
	if ResourceLoader.exists("res://assets/sprites/hud/TopRight/BrownBox.tres"):
		add_theme_stylebox_override("panel", load("res://assets/sprites/hud/TopRight/BrownBox.tres"))
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.48, 0.32, 0.18, 0.85)
	hover_style.corner_radius_top_left = 3
	hover_style.corner_radius_top_right = 3
	hover_style.corner_radius_bottom_right = 3
	hover_style.corner_radius_bottom_left = 3
	add_theme_stylebox_override("hover", hover_style)
	add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45))
	add_theme_color_override("font_disabled_color", Color(0.88, 0.80, 0.65))
	add_theme_color_override("font_separator_color", Color(0.85, 0.70, 0.40))
	add_theme_font_size_override("font_size", 13)
	add_theme_constant_override("v_separation", 6)
	add_theme_constant_override("h_separation", 8)

func _add_worker_assignment_header() -> void:
	var selected_workers := TaskManager.get_selected_farmers()
	if selected_workers.size() == 1:
		add_item("🧑‍🌾 Assign to %s" % selected_workers[0].worker_name, ActionId.TITLE_HEADER)
		set_item_disabled(item_count - 1, true)
		add_separator()
	elif selected_workers.size() > 1:
		add_item("👥 Assign to %d Workers (Parallel)" % selected_workers.size(), ActionId.TITLE_HEADER)
		set_item_disabled(item_count - 1, true)
		add_separator()

func _add_cancel_tasks_option_if_applicable() -> void:
	var selected_workers := TaskManager.get_selected_farmers()
	var has_tasks: bool = false
	for w in selected_workers:
		if is_instance_valid(w) and (w.assigned_tasks.size() > 0 or not w.current_task.is_empty()):
			has_tasks = true
			break
	if has_tasks:
		add_separator()
		add_item("🛑 Cancel Worker's Assigned Tasks", ActionId.CANCEL_TASKS)

func open_for_tile(global_mouse_pos: Vector2, tile_pos: Vector2i, tile: FarmTile) -> void:
	# Right-click context menu feature removed/disabled
	hide()
	return
	
	_add_worker_assignment_header()
	
	match tile.state:
		FarmTile.TileState.EMPTY:
			add_item("⛏️ Plow Soil (Ready for seeds)", ActionId.PLOW)
		
		FarmTile.TileState.PLOWED:
			var active_crop: String = PlantHotbarScript.get_selected_crop()
			var c_data: Dictionary = Data.get_crop(active_crop)
			var c_name: String = c_data.get("display_name", active_crop.capitalize())
			var c_icon: String = c_data.get("icon", "🌱")
			var c_cost: int = int(c_data.get("seed_cost", 25))
			var is_2x2: bool = (c_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2))
			var cost_str: String = " - ₱%d" % c_cost
			if EconomyManager.cash < c_cost:
				cost_str = " - ₱%d (Not enough Money)" % c_cost
			if is_2x2:
				add_item("%s Plant %s (2×2 Grove)%s" % [c_icon, c_name, cost_str], ActionId.PLANT_ACTIVE)
			else:
				add_item("%s Plant %s%s" % [c_icon, c_name, cost_str], ActionId.PLANT_ACTIVE)
			add_item("🌱 Choose Seed from Hotbar...", ActionId.OPEN_PLANT_HOTBAR)
			add_item("🧪 Spray Insecticide (Pre-Planting Soil - ₱30)", ActionId.SPRAY_CHEMICAL)
			
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
			add_item("💧 Water Soil (+25% Moisture)", ActionId.WATER)
			if tile.pest_type != "":
				add_item("🧪 Spray Insecticide (Chemical Cure - ₱30)", ActionId.SPRAY_CHEMICAL)
				add_item("🦆 Spray Insecticide (Biological IPM Cure - ₱45)", ActionId.SPRAY_BIOLOGICAL)
			else:
				add_item("🧪 Spray Insecticide (Chemical - ₱30)", ActionId.SPRAY_CHEMICAL)
				add_item("🦆 Spray Insecticide (Biological IPM - ₱45)", ActionId.SPRAY_BIOLOGICAL)
			var prog_pct: int = int(round(tile.growth_progress * 100.0))
			if tile.crop_type == "coconut" and prog_pct >= 75:
				add_item("🧺 Early Harvest (%d%% - Fresh Buko Coconuts)" % prog_pct, ActionId.EARLY_HARVEST)
			else:
				add_item("🧺 Early Harvest (%d%% Growth - Salvage Yield)" % prog_pct, ActionId.EARLY_HARVEST)
				
		FarmTile.TileState.INFECTED:
			add_item("🧪 Spray Insecticide (Chemical Cure - ₱30)", ActionId.SPRAY_CHEMICAL)
			add_item("🦆 Spray Insecticide (Biological IPM Cure - ₱45)", ActionId.SPRAY_BIOLOGICAL)
			add_item("💧 Water Soil", ActionId.WATER)
			var prog_pct: int = int(round(tile.growth_progress * 100.0))
			add_item("🧺 Early Harvest (%d%% Growth - Salvage Crop)" % prog_pct, ActionId.EARLY_HARVEST)

		FarmTile.TileState.HARVESTABLE:
			if BuildingManager.is_storage_full():
				add_item("⚠️ Harvest Crop (STORAGE FULL - %d/%d)" % [BuildingManager.used_storage, BuildingManager.total_storage_capacity], ActionId.HARVEST)
			else:
				add_item("🧺 Harvest Crop (%s - 100%% Ripe)" % tile.crop_type.capitalize(), ActionId.HARVEST)
			add_item("🧪 Spray Insecticide (Chemical - ₱30)", ActionId.SPRAY_CHEMICAL)
			add_item("🦆 Spray Insecticide (Biological IPM - ₱45)", ActionId.SPRAY_BIOLOGICAL)

		FarmTile.TileState.FLOODED:
			if tile.crop_type != "":
				add_item("🧺 Emergency Salvage Flooded Crop (%s)" % tile.crop_type.capitalize(), ActionId.HARVEST)
			add_item("⛏️ Clear & Re-plow Rot Soil", ActionId.PLOW)

		FarmTile.TileState.OBSTACLE:
			if tile.obstacle_type == "rock":
				add_item("🚫 Granite Boulder Obstacle", ActionId.TITLE_HEADER)
				set_item_disabled(item_count - 1, true)
				add_separator()
				add_item("⛏️ Quarry & Break Rock (₱40 - Worker required)", ActionId.CLEAR_OBSTACLE)
			else:
				add_item("🚫 Ancient Tree Obstacle", ActionId.TITLE_HEADER)
				set_item_disabled(item_count - 1, true)
				add_separator()
				add_item("🪓 Chop & Clear Tree (₱50 - Worker required)", ActionId.CLEAR_OBSTACLE)

		FarmTile.TileState.BUILDING:
			var b_ref: Node = tile.building_ref
			var b_name: String = "Farm Building"
			if b_ref and is_instance_valid(b_ref):
				var b_data := Data.get_building(b_ref.building_type)
				b_name = b_data.get("display_name", b_ref.building_type)
			add_item("🏛️ %s (Active)" % b_name, ActionId.TITLE_HEADER)
			set_item_disabled(item_count - 1, true)

		FarmTile.TileState.LOCKED:
			var parcel: Dictionary = Data.get_parcel_for_tile(tile_pos)
			var p_name: String = parcel.get("name", "Territory")
			var p_cost: int = parcel.get("cost", 1000)
			var r_sz: Vector2i = parcel.get("rect", Rect2i()).size
			add_item("📜 %s (%d×%d Land)" % [p_name, r_sz.x, r_sz.y], ActionId.TITLE_HEADER)
			set_item_disabled(item_count - 1, true)
			add_separator()
			add_item("🔓 Unlock %d×%d Land (₱%s)" % [r_sz.x, r_sz.y, Utils.format_number(p_cost)], ActionId.UNLOCK_LAND)

	_add_cancel_tasks_option_if_applicable()

	if item_count > 0:
		position = Vector2i(int(global_mouse_pos.x), int(global_mouse_pos.y))
		reset_size()
		popup()

func open_for_batch(global_mouse_pos: Vector2, target_tiles: Array, tiles_grid: Array) -> void:
	# Right-click context menu feature removed/disabled
	hide()
	return

	batch_tiles.clear()
	batch_empty_or_flooded.clear()
	batch_plowed.clear()
	batch_can_water.clear()
	batch_can_spray.clear()
	batch_harvestable.clear()
	batch_growing_crops.clear()
	batch_obstacles.clear()

	for pos in target_tiles:
		if pos.x < 0 or pos.x >= tiles_grid.size() or pos.y < 0 or pos.y >= tiles_grid[0].size():
			continue
		var tile: FarmTile = tiles_grid[pos.x][pos.y]
		if tile.state == FarmTile.TileState.LOCKED or tile.state == FarmTile.TileState.BUILDING:
			continue
		batch_tiles.append(pos)
		match tile.state:
			FarmTile.TileState.EMPTY:
				batch_empty_or_flooded.append(pos)
			FarmTile.TileState.FLOODED:
				batch_empty_or_flooded.append(pos)
				if tile.crop_type != "":
					batch_growing_crops.append(pos)
			FarmTile.TileState.OBSTACLE:
				batch_obstacles.append(pos)
			FarmTile.TileState.PLOWED:
				batch_plowed.append(pos)
				batch_can_spray.append(pos)
			FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING, FarmTile.TileState.INFECTED:
				batch_can_water.append(pos)
				batch_can_spray.append(pos)
				batch_growing_crops.append(pos)
			FarmTile.TileState.HARVESTABLE:
				batch_harvestable.append(pos)
				batch_can_spray.append(pos)

	if batch_tiles.is_empty():
		return

	_add_worker_assignment_header()

	add_item("📦 Batch Action (%d Tiles Selected)" % batch_tiles.size(), ActionId.TITLE_HEADER)
	set_item_disabled(item_count - 1, true)

	if batch_empty_or_flooded.size() > 0:
		add_item("⛏️ Plow Soil (%d Tiles)" % batch_empty_or_flooded.size(), ActionId.PLOW)

	if batch_plowed.size() > 0:
		var n: int = batch_plowed.size()
		var active_crop: String = PlantHotbarScript.get_selected_crop()
		var c_data: Dictionary = Data.get_crop(active_crop)
		var c_name: String = c_data.get("display_name", active_crop.capitalize())
		var c_icon: String = c_data.get("icon", "🌱")
		var c_cost: int = int(c_data.get("seed_cost", 25))
		var is_2x2: bool = (c_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2))
		add_separator("🌱 Plant Seed (%d Plowed)" % n)
		var total_cost: int = c_cost if is_2x2 else n * c_cost
		var cost_str: String = " - ₱%d/grove" % c_cost if is_2x2 else " - ₱%d" % total_cost
		if EconomyManager.cash < (c_cost if is_2x2 else total_cost):
			cost_str += " (Not enough Money)"
		if is_2x2:
			add_item("%s Plant %s (2×2 Groves)%s" % [c_icon, c_name, cost_str], ActionId.PLANT_ACTIVE)
		else:
			add_item("%s Plant %s (%d Tiles)%s" % [c_icon, c_name, n, cost_str], ActionId.PLANT_ACTIVE)
		add_item("🌱 Choose Seed from Hotbar...", ActionId.OPEN_PLANT_HOTBAR)

	if batch_can_water.size() > 0:
		add_separator("💧 Maintenance")
		add_item("💧 Water Soil (%d Crops)" % batch_can_water.size(), ActionId.WATER)

	if batch_can_spray.size() > 0:
		var n_sp: int = batch_can_spray.size()
		add_item("🧪 Spray Insecticide (Chemical - ₱%d)" % [n_sp * 30], ActionId.SPRAY_CHEMICAL)
		add_item("🦆 Spray Insecticide (Bio IPM - ₱%d)" % [n_sp * 45], ActionId.SPRAY_BIOLOGICAL)

	if batch_harvestable.size() > 0 or batch_growing_crops.size() > 0:
		add_separator("🧺 Harvest & Salvage")
		if batch_harvestable.size() > 0:
			add_item("🧺 Harvest All Ready Crops (%d Tiles)" % batch_harvestable.size(), ActionId.HARVEST)
		if batch_growing_crops.size() > 0:
			add_item("🧺 Early Harvest (%d Growing Crops - Salvage Yield)" % batch_growing_crops.size(), ActionId.EARLY_HARVEST)
		if batch_harvestable.size() > 0 and batch_growing_crops.size() > 0:
			add_item("🧺 Harvest ALL Crops (%d Ready + %d Early)" % [batch_harvestable.size(), batch_growing_crops.size()], ActionId.HARVEST_ALL)

	if batch_obstacles.size() > 0:
		add_separator("🌳 Obstacles")
		add_item("🪓 Clear %d Obstacles - ₱%d" % [batch_obstacles.size(), batch_obstacles.size() * 50], ActionId.CLEAR_OBSTACLE)

	if item_count <= 1 and batch_empty_or_flooded.size() > 0:
		add_item("⛏️ Plow Soil (All %d Tiles)" % batch_empty_or_flooded.size(), ActionId.PLOW)

	_add_cancel_tasks_option_if_applicable()

	position = Vector2i(int(global_mouse_pos.x), int(global_mouse_pos.y))
	reset_size()
	popup()

func _on_id_pressed(id: int) -> void:
	if id == ActionId.TITLE_HEADER:
		return

	if id == ActionId.CANCEL_TASKS:
		for w in TaskManager.get_selected_farmers():
			if is_instance_valid(w):
				w.clear_assigned_tasks()
		return

	if id == ActionId.UNLOCK_LAND:
		var parcel: Dictionary = Data.get_parcel_for_tile(current_tile_pos)
		var grid = get_node_or_null("../FarmGrid")
		if grid and grid.has_method("open_land_expansion_modal"):
			grid.open_land_expansion_modal(parcel.get("id", ""))
		return

	if id == ActionId.OPEN_PLANT_HOTBAR:
		if TaskManager.get_selected_farmers().is_empty():
			var workers := get_tree().get_nodes_in_group("farmers")
			if not workers.is_empty() and is_instance_valid(workers[0]):
				TaskManager.select_farmer(workers[0])
		var hotbar = get_tree().root.find_child("PlantHotbar", true, false)
		if hotbar:
			hotbar.visible = true
			if hotbar.has_method("open_tray"):
				hotbar.open_tray()

	var action_type: String = ""
	var extra: Dictionary = {}

	match id:
		ActionId.CLEAR_OBSTACLE:
			action_type = "clear_obstacle"
			extra["cost"] = 50
		ActionId.PLOW:
			action_type = "plow"
		ActionId.PLANT_ACTIVE:
			action_type = "plant"
			extra["crop_type"] = PlantHotbarScript.get_selected_crop()
		ActionId.PLANT_PALAY:
			action_type = "plant"
			extra["crop_type"] = "palay"
		ActionId.PLANT_CORN:
			action_type = "plant"
			extra["crop_type"] = "yellow_corn"
		ActionId.PLANT_SUGARCANE:
			action_type = "plant"
			extra["crop_type"] = "sugarcane"
		ActionId.PLANT_PINEAPPLE:
			action_type = "plant"
			extra["crop_type"] = "pineapple"
		ActionId.PLANT_COFFEE:
			action_type = "plant"
			extra["crop_type"] = "arabica_coffee"
		ActionId.PLANT_BANANA:
			action_type = "plant"
			extra["crop_type"] = "banana"
		ActionId.PLANT_COCONUT:
			action_type = "plant"
			extra["crop_type"] = "coconut"
		ActionId.WATER:
			action_type = "water"
			extra["amount"] = 25.0
		ActionId.SPRAY_CHEMICAL:
			action_type = "spray_pest"
			extra["method"] = "chemical"
		ActionId.SPRAY_BIOLOGICAL:
			action_type = "spray_pest"
			extra["method"] = "biological"
		ActionId.EARLY_HARVEST:
			action_type = "early_harvest"
		ActionId.HARVEST, ActionId.HARVEST_ALL:
			action_type = "harvest"

	if action_type != "":
		if is_batch_mode:
			var target_list: Array[Vector2i] = []
			match id:
				ActionId.CLEAR_OBSTACLE:
					target_list = batch_obstacles
				ActionId.PLOW:
					target_list = batch_empty_or_flooded if batch_empty_or_flooded.size() > 0 else batch_tiles
				ActionId.PLANT_ACTIVE, ActionId.PLANT_PALAY, ActionId.PLANT_CORN, ActionId.PLANT_SUGARCANE, ActionId.PLANT_PINEAPPLE, ActionId.PLANT_COFFEE, ActionId.PLANT_BANANA, ActionId.PLANT_COCONUT:
					target_list = batch_plowed
				ActionId.WATER:
					target_list = batch_can_water
				ActionId.SPRAY_CHEMICAL, ActionId.SPRAY_BIOLOGICAL:
					target_list = batch_can_spray
				ActionId.HARVEST:
					target_list = batch_harvestable
				ActionId.EARLY_HARVEST:
					target_list = batch_growing_crops
				ActionId.HARVEST_ALL:
					target_list = batch_harvestable + batch_growing_crops
				_:
					target_list = batch_tiles
			batch_action_selected.emit(action_type, target_list, extra)
		else:
			action_selected.emit(action_type, current_tile_pos, extra)
