# TileInfoPanel.gd
# Side HUD panel showing detailed inspect statistics for the selected farm tile.

extends PanelContainer

@onready var title_label: Label = $VBox/TitleLabel
@onready var state_label: Label = $VBox/StateLabel
@onready var crop_label: Label = $VBox/CropLabel
@onready var quality_label: Label = $VBox/QualityLabel
@onready var pest_label: Label = $VBox/PestLabel

@onready var growth_bar: ProgressBar = $VBox/GrowthBox/GrowthBar
@onready var growth_val: Label = $VBox/GrowthBox/GrowthVal

@onready var health_bar: ProgressBar = $VBox/HealthBox/HealthBar
@onready var health_val: Label = $VBox/HealthBox/HealthVal

@onready var moisture_bar: ProgressBar = $VBox/MoistureBox/MoistureBar
@onready var moisture_val: Label = $VBox/MoistureBox/MoistureVal

@onready var btn_plow: Button = $VBox/Actions/BtnPlow
@onready var btn_plant: MenuButton = $VBox/Actions/BtnPlant
@onready var btn_water: Button = $VBox/Actions/BtnWater
@onready var btn_spray: Button = $VBox/Actions/BtnSpray
@onready var btn_harvest: Button = $VBox/Actions/BtnHarvest

var selected_pos: Vector2i = Vector2i(-1, -1)
var selected_tile: FarmTile = null

func _ready() -> void:
	btn_plow.pressed.connect(_on_plow_pressed)
	btn_water.pressed.connect(_on_water_pressed)
	btn_spray.pressed.connect(_on_spray_pressed)
	btn_harvest.pressed.connect(_on_harvest_pressed)

	# Setup plant popup submenu
	var plant_popup: PopupMenu = btn_plant.get_popup()
	plant_popup.clear()
	plant_popup.add_item("🌾 Palay (Rice) - ₱25", 1)
	plant_popup.add_item("🌽 Yellow Corn - ₱30", 2)
	plant_popup.add_item("☕ Arabica Coffee - ₱50", 3)
	plant_popup.add_item("🍌 Banana - ₱35", 4)
	plant_popup.add_item("🥥 Coconut - ₱40", 5)
	plant_popup.id_pressed.connect(_on_plant_crop_selected)

	# Connect to TimeManager to refresh stats continuously as the world updates
	TimeManager.hour_changed.connect(_on_time_tick)
	TimeManager.day_changed.connect(_on_time_tick)

	# Connect to FarmGrid inspection
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid and farm_grid.has_signal("tile_inspected"):
		if not farm_grid.tile_inspected.is_connected(inspect_tile):
			farm_grid.tile_inspected.connect(inspect_tile)

	if selected_tile != null:
		inspect_tile(selected_pos, selected_tile)

func _on_time_tick(_arg: int = 0) -> void:
	if selected_pos != Vector2i(-1, -1) and selected_tile != null:
		inspect_tile(selected_pos, selected_tile)

func inspect_tile(pos: Vector2i, tile: FarmTile) -> void:
	selected_pos = pos
	selected_tile = tile

	if not is_node_ready() or title_label == null:
		return

	title_label.text = "📍 Tile (%d, %d)" % [pos.x, pos.y]
	state_label.text = "Status: " + _tile_state_string(tile.state)

	if tile.crop_type != "":
		var c_data = Data.get_crop(tile.crop_type)
		crop_label.text = "Crop: %s %s" % [c_data.get("icon", "🌱"), c_data.get("display_name", tile.crop_type)]
	else:
		crop_label.text = "Crop: (None)"

	# Progress Bars
	growth_bar.value = tile.growth_progress * 100.0
	growth_val.text = "%.0f%%" % (tile.growth_progress * 100.0)

	health_bar.value = tile.health * 100.0
	health_val.text = "%.0f%%" % (tile.health * 100.0)

	moisture_bar.value = tile.soil_moisture
	moisture_val.text = "%.0f%%" % tile.soil_moisture

	# Quality & Pest
	quality_label.text = "Quality: " + _quality_string(tile.quality)

	if tile.pest_type != "":
		var p_data = Data.get_pest(tile.pest_type)
		pest_label.text = "Infestation: 🐛 " + p_data.get("display_name", tile.pest_type)
		pest_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		pest_label.text = "Pests: None (Healthy)"
		pest_label.modulate = Color(0.6, 0.9, 0.6)

	_update_action_button_states()

func _update_action_button_states() -> void:
	if selected_tile == null:
		return
	btn_plow.disabled = (selected_tile.state != FarmTile.TileState.EMPTY and selected_tile.state != FarmTile.TileState.FLOODED)
	btn_plant.disabled = (selected_tile.state != FarmTile.TileState.PLOWED)
	btn_water.disabled = (selected_tile.state != FarmTile.TileState.PLANTED and selected_tile.state != FarmTile.TileState.GROWING and selected_tile.state != FarmTile.TileState.INFECTED)
	btn_spray.disabled = (selected_tile.pest_type == "")
	btn_harvest.disabled = (selected_tile.state != FarmTile.TileState.HARVESTABLE)

func _on_plow_pressed() -> void:
	if selected_pos != Vector2i(-1, -1):
		TaskManager.add_task({"type": "plow", "position": selected_pos})

func _on_plant_crop_selected(id: int) -> void:
	var crop_name: String = "palay"
	match id:
		1: crop_name = "palay"
		2: crop_name = "yellow_corn"
		3: crop_name = "arabica_coffee"
		4: crop_name = "banana"
		5: crop_name = "coconut"
	if selected_pos != Vector2i(-1, -1):
		TaskManager.add_task({"type": "plant", "crop_type": crop_name, "position": selected_pos})

func _on_water_pressed() -> void:
	if selected_pos != Vector2i(-1, -1):
		TaskManager.add_task({"type": "water", "amount": 25.0, "position": selected_pos})

func _on_spray_pressed() -> void:
	if selected_pos != Vector2i(-1, -1):
		TaskManager.add_task({"type": "spray_pest", "method": "chemical", "position": selected_pos})

func _on_harvest_pressed() -> void:
	if selected_pos != Vector2i(-1, -1):
		TaskManager.add_task({"type": "harvest", "position": selected_pos})

func _tile_state_string(state_val: int) -> String:
	match state_val:
		FarmTile.TileState.EMPTY: return "Empty Grass"
		FarmTile.TileState.PLOWED: return "Plowed Soil"
		FarmTile.TileState.PLANTED: return "Newly Seeded"
		FarmTile.TileState.GROWING: return "Growing Crop"
		FarmTile.TileState.HARVESTABLE: return "Ready for Harvest!"
		FarmTile.TileState.FLOODED: return "Flooded / Crop Rot"
		FarmTile.TileState.INFECTED: return "Pest Infested"
		_: return "Unknown"

func _quality_string(grade_val: int) -> String:
	match grade_val:
		FarmTile.QualityGrade.A: return "Grade A (Organic / Premium)"
		FarmTile.QualityGrade.B: return "Grade B (Standard Market)"
		FarmTile.QualityGrade.C: return "Grade C (Damaged / Salvage)"
		_: return "Standard"
