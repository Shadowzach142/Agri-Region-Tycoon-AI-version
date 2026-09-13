# TileActionPopup.gd
# Context-sensitive popup menu for selecting farm tile actions.

extends PopupMenu

signal action_selected(action_type: String, tile_pos: Vector2i, extra_data: Dictionary)

enum ActionId {
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

var current_tile_pos: Vector2i = Vector2i(-1, -1)
var current_tile: FarmTile = null

func _ready() -> void:
	id_pressed.connect(_on_id_pressed)

func open_for_tile(global_mouse_pos: Vector2, tile_pos: Vector2i, tile: FarmTile) -> void:
	current_tile_pos = tile_pos
	current_tile = tile
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
			
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
			add_item("💧 Water Soil (+25% Moisture)", ActionId.WATER)
			if tile.pest_type != "":
				add_item("🧪 Chemical Pesticide (Fast, ₱30)", ActionId.SPRAY_CHEMICAL)
				add_item("🦆 Biological IPM (Organic, ₱45)", ActionId.SPRAY_BIOLOGICAL)
				
		FarmTile.TileState.INFECTED:
			add_item("🧪 Chemical Pesticide (Instant, ₱30)", ActionId.SPRAY_CHEMICAL)
			add_item("🦆 Biological IPM (Protects Grade A, ₱45)", ActionId.SPRAY_BIOLOGICAL)
			add_item("💧 Water Soil", ActionId.WATER)

		FarmTile.TileState.HARVESTABLE:
			add_item("🧺 Harvest Crop (%s)" % tile.crop_type.capitalize(), ActionId.HARVEST)

		FarmTile.TileState.FLOODED:
			add_item("⛏️ Clear & Re-plow Rot Soil", ActionId.PLOW)

	if item_count > 0:
		position = Vector2i(int(global_mouse_pos.x), int(global_mouse_pos.y))
		reset_size()
		popup()

func _on_id_pressed(id: int) -> void:
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
		action_selected.emit(action_type, current_tile_pos, extra)
