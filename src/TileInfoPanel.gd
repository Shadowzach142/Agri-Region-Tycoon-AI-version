# TileInfoPanel.gd
# Sleek Bottom-Left Tile Inspector Card displaying thumbnail, coordinates, and vital gauges.

extends PanelContainer

@onready var portrait_icon: Label = $HBox/PortraitBox/PortraitIcon
@onready var title_label: Label = $HBox/PortraitBox/Meta/TitleLabel
@onready var crop_label: Label = $HBox/PortraitBox/Meta/CropLabel
@onready var state_label: Label = $HBox/PortraitBox/Meta/StateLabel

@onready var growth_bar: ProgressBar = $HBox/GaugesBox/GrowthBox/GrowthBar
@onready var growth_val: Label = $HBox/GaugesBox/GrowthBox/GrowthVal

@onready var health_bar: ProgressBar = $HBox/GaugesBox/HealthBox/HealthBar
@onready var health_val: Label = $HBox/GaugesBox/HealthBox/HealthVal

@onready var moisture_bar: ProgressBar = $HBox/GaugesBox/MoistureBox/MoistureBar
@onready var moisture_val: Label = $HBox/GaugesBox/MoistureBox/MoistureVal

@onready var quality_label: Label = $HBox/StatusBox/QualityLabel
@onready var pest_label: Label = $HBox/StatusBox/PestLabel

var selected_pos: Vector2i = Vector2i(-1, -1)
var selected_tile: FarmTile = null

func _ready() -> void:
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
	state_label.text = _tile_state_string(tile.state)

	if portrait_icon:
		match tile.state:
			FarmTile.TileState.EMPTY: portrait_icon.text = "🌱"
			FarmTile.TileState.PLOWED: portrait_icon.text = "⛏️"
			FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
				var c_data = Data.get_crop(tile.crop_type)
				portrait_icon.text = c_data.get("icon", "🌿")
			FarmTile.TileState.HARVESTABLE:
				var c_data = Data.get_crop(tile.crop_type)
				portrait_icon.text = c_data.get("icon", "🌾")
			FarmTile.TileState.FLOODED: portrait_icon.text = "🌊"
			FarmTile.TileState.INFECTED: portrait_icon.text = "🐛"
			_: portrait_icon.text = "🌱"

	if tile.crop_type != "":
		var c_data = Data.get_crop(tile.crop_type)
		crop_label.text = "%s %s" % [c_data.get("icon", "🌱"), c_data.get("display_name", tile.crop_type)]
	else:
		crop_label.text = "Uncultivated Soil"

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
		FarmTile.QualityGrade.A: return "Grade A (Organic)"
		FarmTile.QualityGrade.B: return "Grade B (Standard)"
		FarmTile.QualityGrade.C: return "Grade C (Damaged)"
		_: return "Standard"
