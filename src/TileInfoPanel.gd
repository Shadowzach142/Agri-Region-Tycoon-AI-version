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
var is_batch_inspect: bool = false
var batch_selected_tiles: Array = []

func _ready() -> void:
	# Connect to TimeManager to refresh stats continuously as the world updates
	TimeManager.hour_changed.connect(_on_time_tick)
	TimeManager.day_changed.connect(_on_time_tick)

	# Connect to FarmGrid inspection
	var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	if farm_grid:
		if farm_grid.has_signal("tile_inspected") and not farm_grid.tile_inspected.is_connected(inspect_tile):
			farm_grid.tile_inspected.connect(inspect_tile)
		if farm_grid.has_signal("selection_inspected") and not farm_grid.selection_inspected.is_connected(inspect_selection):
			farm_grid.selection_inspected.connect(inspect_selection)

	if selected_tile != null:
		inspect_tile(selected_pos, selected_tile)

func _on_time_tick(_arg: int = 0) -> void:
	if is_batch_inspect and batch_selected_tiles.size() > 0:
		var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
		if farm_grid and "tiles" in farm_grid:
			inspect_selection(batch_selected_tiles, farm_grid.tiles)
	elif selected_pos != Vector2i(-1, -1) and selected_tile != null:
		inspect_tile(selected_pos, selected_tile)

func inspect_selection(tiles_pos_list: Array, tiles_grid: Array) -> void:
	is_batch_inspect = true
	batch_selected_tiles = tiles_pos_list.duplicate()
	selected_pos = Vector2i(-1, -1)
	selected_tile = null

	if not is_node_ready() or title_label == null:
		return

	var count: int = tiles_pos_list.size()
	title_label.text = "📦 Selected: %d Tiles" % count
	if portrait_icon:
		portrait_icon.text = "🗺️"

	var empty_count: int = 0
	var plowed_count: int = 0
	var planted_count: int = 0
	var growing_count: int = 0
	var harvest_count: int = 0
	var flooded_count: int = 0
	var infected_count: int = 0

	var sum_moisture: float = 0.0
	var sum_health: float = 0.0
	var sum_growth: float = 0.0
	var crop_tiles_count: int = 0

	for pos in tiles_pos_list:
		if pos.x < 0 or pos.x >= tiles_grid.size() or pos.y < 0 or pos.y >= tiles_grid[0].size():
			continue
		var t: FarmTile = tiles_grid[pos.x][pos.y]
		sum_moisture += t.soil_moisture
		sum_health += t.health
		if t.crop_type != "":
			sum_growth += t.growth_progress
			crop_tiles_count += 1

		match t.state:
			FarmTile.TileState.EMPTY: empty_count += 1
			FarmTile.TileState.PLOWED: plowed_count += 1
			FarmTile.TileState.PLANTED: planted_count += 1
			FarmTile.TileState.GROWING: growing_count += 1
			FarmTile.TileState.HARVESTABLE: harvest_count += 1
			FarmTile.TileState.FLOODED: flooded_count += 1
			FarmTile.TileState.INFECTED: infected_count += 1

	var summary_parts: Array[String] = []
	if harvest_count > 0: summary_parts.append("%d Ready" % harvest_count)
	if (planted_count + growing_count) > 0: summary_parts.append("%d Growing" % (planted_count + growing_count))
	if plowed_count > 0: summary_parts.append("%d Plowed" % plowed_count)
	if empty_count > 0: summary_parts.append("%d Empty" % empty_count)
	if flooded_count > 0: summary_parts.append("%d Flooded" % flooded_count)

	crop_label.text = " | ".join(summary_parts) if summary_parts.size() > 0 else "All Empty"
	state_label.text = "Right-Click for Batch Actions"

	var avg_moisture: float = sum_moisture / float(max(1, count))
	var avg_health: float = sum_health / float(max(1, count))
	var avg_growth: float = (sum_growth / float(crop_tiles_count)) if crop_tiles_count > 0 else 0.0

	growth_bar.value = avg_growth * 100.0
	growth_val.text = "Avg: %.0f%%" % (avg_growth * 100.0)

	health_bar.value = avg_health * 100.0
	health_val.text = "Avg: %.0f%%" % (avg_health * 100.0)

	moisture_bar.value = avg_moisture
	moisture_val.text = "Avg: %.0f%%" % avg_moisture

	quality_label.text = "Crops: %d / %d Tiles" % [crop_tiles_count, count]

	if infected_count > 0:
		pest_label.text = "⚠️ %d Infestations!" % infected_count
		pest_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		pest_label.text = "✅ 0 Infestations"
		pest_label.modulate = Color(0.6, 0.9, 0.6)

func inspect_tile(pos: Vector2i, tile: FarmTile) -> void:
	is_batch_inspect = false
	batch_selected_tiles.clear()
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
			FarmTile.TileState.OBSTACLE: portrait_icon.text = "🌳"
			FarmTile.TileState.BUILDING: portrait_icon.text = "🏛️"
			_: portrait_icon.text = "🌱"

	if tile.state == FarmTile.TileState.OBSTACLE:
		crop_label.text = "🌲 Tree Obstacle (Blocks Building)"
	elif tile.state == FarmTile.TileState.BUILDING:
		# Show building name and click-to-inspect hint
		var b_ref: Node = tile.building_ref
		if b_ref != null and is_instance_valid(b_ref):
			var b_data := Data.get_building(b_ref.building_type)
			var b_name: String = b_data.get("display_name", b_ref.building_type)
			var stars := ""
			for _i in range(b_ref.level):
				stars += "⭐"
			crop_label.text = "%s %s Lv.%d" % [b_data.get("icon", "🏛️"), b_name, b_ref.level]
			state_label.text = "Click building to Inspect / Upgrade"
		else:
			crop_label.text = "🏛️ Farm Building"
	elif tile.crop_type != "":

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
		FarmTile.TileState.OBSTACLE: return "⛔ Tree Obstacle (COC)"
		FarmTile.TileState.BUILDING: return "🏛️ Farm Building (Occupied)"
		_: return "Unknown"

func _quality_string(grade_val: int) -> String:
	match grade_val:
		FarmTile.QualityGrade.A: return "Grade A (Organic)"
		FarmTile.QualityGrade.B: return "Grade B (Standard)"
		FarmTile.QualityGrade.C: return "Grade C (Damaged)"
		_: return "Standard"
