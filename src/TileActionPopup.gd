# TileActionPopup.gd
# Context-sensitive popup menu for selecting farm tile actions.

extends PopupMenu

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
	WATER = 300,
	SPRAY_CHEMICAL = 401,
	SPRAY_BIOLOGICAL = 402,
	HARVEST = 500,
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

func _ready() -> void:
	id_pressed.connect(_on_id_pressed)

func open_for_tile(global_mouse_pos: Vector2, tile_pos: Vector2i, tile: FarmTile) -> void:
	is_batch_mode = false
	current_tile_pos = tile_pos
	current_tile = tile
	batch_tiles.clear()
	clear()
	set_item_count(0)
	
	match tile.state:
		FarmTile.TileState.EMPTY:
			add_item("⛏️ Plow Soil (Ready for seeds)", ActionId.PLOW)
		
		FarmTile.TileState.PLOWED:
			add_item("🌾 Plant Palay (Rice) - ₱25", ActionId.PLANT_PALAY)
			add_item("🌽 Plant Yellow Corn - ₱30", ActionId.PLANT_CORN)
			add_item("☕ Plant Arabica Coffee - ₱50", ActionId.PLANT_COFFEE)
			add_item("🍌 Plant Cavendish Banana - ₱35", ActionId.PLANT_BANANA)
			add_item("🥥 Plant Coconut Palm - ₱40", ActionId.PLANT_COCONUT)
			add_item("🧪 Spray Insecticide (Pre-Planting Soil - ₱30)", ActionId.SPRAY_CHEMICAL)
			
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
			add_item("💧 Water Soil (+25% Moisture)", ActionId.WATER)
			if tile.pest_type != "":
				add_item("🧪 Spray Insecticide (Chemical Cure - ₱30)", ActionId.SPRAY_CHEMICAL)
				add_item("🦆 Spray Insecticide (Biological IPM Cure - ₱45)", ActionId.SPRAY_BIOLOGICAL)
			else:
				add_item("🧪 Spray Insecticide (Chemical - ₱30)", ActionId.SPRAY_CHEMICAL)
				add_item("🦆 Spray Insecticide (Biological IPM - ₱45)", ActionId.SPRAY_BIOLOGICAL)
				
		FarmTile.TileState.INFECTED:
			add_item("🧪 Spray Insecticide (Chemical Cure - ₱30)", ActionId.SPRAY_CHEMICAL)
			add_item("🦆 Spray Insecticide (Biological IPM Cure - ₱45)", ActionId.SPRAY_BIOLOGICAL)
			add_item("💧 Water Soil", ActionId.WATER)

		FarmTile.TileState.HARVESTABLE:
			add_item("🧺 Harvest Crop (%s)" % tile.crop_type.capitalize(), ActionId.HARVEST)
			add_item("🧪 Spray Insecticide (Chemical - ₱30)", ActionId.SPRAY_CHEMICAL)
			add_item("🦆 Spray Insecticide (Biological IPM - ₱45)", ActionId.SPRAY_BIOLOGICAL)

		FarmTile.TileState.FLOODED:
			add_item("⛏️ Clear & Re-plow Rot Soil", ActionId.PLOW)

	if item_count > 0:
		position = Vector2i(int(global_mouse_pos.x), int(global_mouse_pos.y))
		reset_size()
		popup()

func open_for_batch(global_mouse_pos: Vector2, target_tiles: Array, tiles_grid: Array) -> void:
	is_batch_mode = true
	batch_tiles = target_tiles.duplicate()
	clear()
	set_item_count(0)

	batch_empty_or_flooded.clear()
	batch_plowed.clear()
	batch_can_water.clear()
	batch_can_spray.clear()
	batch_harvestable.clear()

	for pos in target_tiles:
		if pos.x < 0 or pos.x >= tiles_grid.size() or pos.y < 0 or pos.y >= tiles_grid[0].size():
			continue
		var tile: FarmTile = tiles_grid[pos.x][pos.y]
		match tile.state:
			FarmTile.TileState.EMPTY, FarmTile.TileState.FLOODED:
				batch_empty_or_flooded.append(pos)
			FarmTile.TileState.PLOWED:
				batch_plowed.append(pos)
				batch_can_spray.append(pos)
			FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
				batch_can_water.append(pos)
				batch_can_spray.append(pos)
			FarmTile.TileState.INFECTED:
				batch_can_water.append(pos)
				batch_can_spray.append(pos)
			FarmTile.TileState.HARVESTABLE:
				batch_harvestable.append(pos)
				batch_can_spray.append(pos)

	add_item("📦 Batch Action (%d Tiles Selected)" % target_tiles.size(), ActionId.TITLE_HEADER)
	set_item_disabled(0, true)

	if batch_empty_or_flooded.size() > 0:
		add_item("⛏️ Plow Soil (%d Tiles)" % batch_empty_or_flooded.size(), ActionId.PLOW)

	if batch_plowed.size() > 0:
		var n: int = batch_plowed.size()
		add_separator("🌱 Plant Crops (%d Plowed)" % n)
		add_item("🌾 Plant Palay (%d Tiles) - ₱%d" % [n, n * 25], ActionId.PLANT_PALAY)
		add_item("🌽 Plant Corn (%d Tiles) - ₱%d" % [n, n * 30], ActionId.PLANT_CORN)
		add_item("☕ Plant Coffee (%d Tiles) - ₱%d" % [n, n * 50], ActionId.PLANT_COFFEE)
		add_item("🍌 Plant Banana (%d Tiles) - ₱%d" % [n, n * 35], ActionId.PLANT_BANANA)
		add_item("🥥 Plant Coconut (%d Tiles) - ₱%d" % [n, n * 40], ActionId.PLANT_COCONUT)

	if batch_can_water.size() > 0:
		add_separator("💧 Maintenance")
		add_item("💧 Water Soil (%d Crops)" % batch_can_water.size(), ActionId.WATER)

	if batch_can_spray.size() > 0:
		var n_sp: int = batch_can_spray.size()
		add_item("🧪 Spray Insecticide (Chemical - ₱%d)" % [n_sp * 30], ActionId.SPRAY_CHEMICAL)
		add_item("🦆 Spray Insecticide (Bio IPM - ₱%d)" % [n_sp * 45], ActionId.SPRAY_BIOLOGICAL)

	if batch_harvestable.size() > 0:
		add_separator("🧺 Harvest")
		add_item("🧺 Harvest All Ready Crops (%d Tiles)" % batch_harvestable.size(), ActionId.HARVEST)

	if item_count <= 1:
		add_item("⛏️ Plow Soil (All %d Tiles)" % target_tiles.size(), ActionId.PLOW)

	position = Vector2i(int(global_mouse_pos.x), int(global_mouse_pos.y))
	reset_size()
	popup()

func _on_id_pressed(id: int) -> void:
	if id == ActionId.TITLE_HEADER:
		return

	var action_type: String = ""
	var extra: Dictionary = {}

	match id:
		ActionId.PLOW:
			action_type = "plow"
		ActionId.PLANT_PALAY:
			action_type = "plant"
			extra["crop_type"] = "palay"
		ActionId.PLANT_CORN:
			action_type = "plant"
			extra["crop_type"] = "yellow_corn"
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
		ActionId.HARVEST:
			action_type = "harvest"

	if action_type != "":
		if is_batch_mode:
			var target_list: Array[Vector2i] = []
			match id:
				ActionId.PLOW:
					target_list = batch_empty_or_flooded if batch_empty_or_flooded.size() > 0 else batch_tiles
				ActionId.PLANT_PALAY, ActionId.PLANT_CORN, ActionId.PLANT_COFFEE, ActionId.PLANT_BANANA, ActionId.PLANT_COCONUT:
					target_list = batch_plowed
				ActionId.WATER:
					target_list = batch_can_water
				ActionId.SPRAY_CHEMICAL, ActionId.SPRAY_BIOLOGICAL:
					target_list = batch_can_spray
				ActionId.HARVEST:
					target_list = batch_harvestable
				_:
					target_list = batch_tiles
			batch_action_selected.emit(action_type, target_list, extra)
		else:
			action_selected.emit(action_type, current_tile_pos, extra)
