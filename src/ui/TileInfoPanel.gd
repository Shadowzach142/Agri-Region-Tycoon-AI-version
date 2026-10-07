# TileInfoPanel.gd
# Dynamic Bottom-Left Tile Inspector Card displaying thumbnail, coordinates, and vital gauges.
# Automatically locates its UI elements anywhere in its subtree by name,
# allowing the player / designer to freely rearrange and style the clipboard layout.

extends PanelContainer

var portrait_icon: Node = null
var title_label: Label = null
var crop_label: Label = null
var state_label: Label = null

var growth_bar: ProgressBar = null
var growth_val: Label = null

var health_bar: ProgressBar = null
var health_val: Label = null

var moisture_bar: ProgressBar = null
var moisture_val: Label = null

var quality_label: Label = null
var pest_label: Label = null

var selected_pos: Vector2i = Vector2i(-1, -1)
var selected_tile: FarmTile = null
var is_batch_inspect: bool = false
var batch_selected_tiles: Array = []

func _ready() -> void:
	_discover_nodes()

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

var portrait_texture: TextureRect = null

func _discover_nodes() -> void:
	portrait_icon = find_child("PortraitIcon", true, false)
	var plant_box = find_child("PlantBox", true, false)
	if plant_box:
		portrait_texture = plant_box.find_child("PortraitTexture", true, false) as TextureRect
		if not portrait_texture:
			portrait_texture = TextureRect.new()
			portrait_texture.name = "PortraitTexture"
			portrait_texture.custom_minimum_size = Vector2(56, 56)
			portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait_texture.visible = false
			plant_box.add_child(portrait_texture)

	if not portrait_icon and not portrait_texture:
		portrait_icon = find_child("PortraitTexture", true, false)

	title_label   = find_child("TitleLabel", true, false) as Label
	crop_label    = find_child("CropLabel", true, false) as Label
	state_label   = find_child("StateLabel", true, false) as Label

	growth_bar    = find_child("GrowthBar", true, false) as ProgressBar
	growth_val    = find_child("GrowthVal", true, false) as Label

	health_bar    = find_child("HealthBar", true, false) as ProgressBar
	health_val    = find_child("HealthVal", true, false) as Label

	moisture_bar  = find_child("MoistureBar", true, false) as ProgressBar
	moisture_val  = find_child("MoistureVal", true, false) as Label

	quality_label = find_child("QualityLabel", true, false) as Label
	pest_label    = find_child("PestLabel", true, false) as Label

func _set_portrait(icon_text: String, crop_key: String = "") -> void:
	if not crop_key.is_empty():
		var tex: Texture2D = null
		if PlantHotbar.CROP_ICONS.has(crop_key):
			var p: String = PlantHotbar.CROP_ICONS[crop_key]
			if ResourceLoader.exists(p):
				tex = load(p) as Texture2D
		if tex != null and portrait_texture != null:
			portrait_texture.texture = tex
			portrait_texture.visible = true
			if portrait_icon:
				portrait_icon.visible = false
			return

	if portrait_texture:
		portrait_texture.visible = false
	if portrait_icon:
		portrait_icon.visible = true
		if "text" in portrait_icon:
			portrait_icon.text = icon_text

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

	var count: int = tiles_pos_list.size()
	if title_label:
		title_label.text = "📦 Selected: %d Tiles" % count
	_set_portrait("🗺️")

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

	if crop_label:
		crop_label.text = " | ".join(summary_parts) if summary_parts.size() > 0 else "All Empty"
	if state_label:
		state_label.text = "Right-Click for Batch Actions"

	var avg_moisture: float = sum_moisture / float(max(1, count))
	var avg_health: float = sum_health / float(max(1, count))
	var avg_growth: float = (sum_growth / float(crop_tiles_count)) if crop_tiles_count > 0 else 0.0

	if growth_bar:
		growth_bar.value = avg_growth * 100.0
	if growth_val:
		growth_val.text = "Avg: %.0f%%" % (avg_growth * 100.0)

	if health_bar:
		health_bar.value = avg_health * 100.0
	if health_val:
		health_val.text = "Avg: %.0f%%" % (avg_health * 100.0)

	if moisture_bar:
		moisture_bar.value = avg_moisture
	if moisture_val:
		moisture_val.text = "Avg: %.0f%%" % avg_moisture

	if quality_label:
		quality_label.text = "Crops: %d / %d Tiles" % [crop_tiles_count, count]

	if pest_label:
		if infected_count > 0:
			pest_label.text = "⚠️ %d Infestations!" % infected_count
			pest_label.modulate = Color(0.85, 0.20, 0.15)
		else:
			pest_label.text = "✅ 0 Infestations"
			pest_label.modulate = Color(0.12, 0.48, 0.18)

func inspect_tile(pos: Vector2i, tile: FarmTile) -> void:
	is_batch_inspect = false
	batch_selected_tiles.clear()
	selected_pos = pos
	selected_tile = tile

	if title_label:
		title_label.text = "Tile (%d, %d)" % [pos.x, pos.y]
	if state_label:
		if tile.state == FarmTile.TileState.OBSTACLE:
			state_label.text = "🪨 Boulder Obstacle" if tile.obstacle_type == "rock" else "🌳 Tree Obstacle"
		else:
			state_label.text = _tile_state_string(tile.state)

	match tile.state:
		FarmTile.TileState.EMPTY: _set_portrait("🌱")
		FarmTile.TileState.PLOWED: _set_portrait("⛏️")
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING:
			var c_type: String = tile.crop_type
			if c_type.is_empty() and tile.multi_tile_root_pos != Vector2i(-1, -1):
				var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
				if farm_grid and "tiles" in farm_grid:
					c_type = farm_grid.tiles[tile.multi_tile_root_pos.x][tile.multi_tile_root_pos.y].crop_type
			var c_data = Data.get_crop(c_type)
			_set_portrait(c_data.get("icon", "🌿"), c_type)
		FarmTile.TileState.HARVESTABLE:
			var c_type: String = tile.crop_type
			if c_type.is_empty() and tile.multi_tile_root_pos != Vector2i(-1, -1):
				var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
				if farm_grid and "tiles" in farm_grid:
					c_type = farm_grid.tiles[tile.multi_tile_root_pos.x][tile.multi_tile_root_pos.y].crop_type
			var c_data = Data.get_crop(c_type)
			_set_portrait(c_data.get("icon", "🌾"), c_type)
		FarmTile.TileState.FLOODED: _set_portrait("🌊")
		FarmTile.TileState.INFECTED: _set_portrait("🐛")
		FarmTile.TileState.OBSTACLE:
			if tile.obstacle_type == "rock":
				_set_portrait("🪨")
			else:
				_set_portrait("🌳")
		FarmTile.TileState.BUILDING: _set_portrait("🏛️")
		FarmTile.TileState.LOCKED: _set_portrait("🔒")
		_: _set_portrait("🌱")

	if crop_label:
		if tile.state == FarmTile.TileState.LOCKED:
			var p: Dictionary = Data.get_parcel_for_tile(pos)
			crop_label.text = "🔒 %s" % p.get("name", "Wild Territory")
			if state_label:
				var r_sz: Vector2i = p.get("rect", Rect2i()).size
				state_label.text = "%d×%d Land • ₱%s (Right-Click to Unlock)" % [r_sz.x, r_sz.y, Utils.format_number(p.get("cost", 1000))]
		elif tile.state == FarmTile.TileState.OBSTACLE:
			if tile.obstacle_type == "rock":
				crop_label.text = "🪨 Granite Boulder (Obstacle)"
			else:
				crop_label.text = "🌲 Tree Obstacle (Blocks Building)"
		elif tile.state == FarmTile.TileState.BUILDING:
			var b_ref: Node = tile.building_ref
			if b_ref != null and is_instance_valid(b_ref):
				var b_data := Data.get_building(b_ref.building_type)
				var b_name: String = b_data.get("display_name", b_ref.building_type)
				var stars := ""
				for _i in range(b_ref.level):
					stars += "⭐"
				crop_label.text = "%s %s Lv.%d" % [b_data.get("icon", "🏛️"), b_name, b_ref.level]
				if state_label:
					state_label.text = "Click building to Inspect / Upgrade"
			else:
				crop_label.text = "🏛️ Farm Building"
		elif tile.crop_type != "" or tile.multi_tile_root_pos != Vector2i(-1, -1):
			var effective_crop: String = tile.crop_type
			var root_pos: Vector2i = tile.multi_tile_root_pos
			if effective_crop.is_empty() and root_pos != Vector2i(-1, -1):
				var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
				if farm_grid and "tiles" in farm_grid:
					effective_crop = farm_grid.tiles[root_pos.x][root_pos.y].crop_type
			var c_data = Data.get_crop(effective_crop)
			var suffix: String = ""
			if c_data.get("footprint", Vector2i(1, 1)) == Vector2i(2, 2):
				suffix += " (2×2 Grove)"
			if c_data.get("is_perennial", false):
				suffix += " • Perennial"
			crop_label.text = "%s %s%s" % [c_data.get("icon", "🌱"), c_data.get("display_name", effective_crop), suffix]
		else:
			crop_label.text = "Uncultivated Soil"

	# Progress Bars
	if growth_bar:
		growth_bar.value = tile.growth_progress * 100.0
	if growth_val:
		growth_val.text = "%.0f%%" % (tile.growth_progress * 100.0)

	if health_bar:
		health_bar.value = tile.health * 100.0
	if health_val:
		health_val.text = "%.0f%%" % (tile.health * 100.0)

	if moisture_bar:
		moisture_bar.value = tile.soil_moisture
	if moisture_val:
		moisture_val.text = "%.0f%%" % tile.soil_moisture

	# Quality & Pest
	if quality_label:
		quality_label.text = "Quality: " + _quality_string(tile.quality)

	if pest_label:
		if tile.pest_type != "":
			var p_data = Data.get_pest(tile.pest_type)
			pest_label.text = "Infestation: 🐛 " + p_data.get("display_name", tile.pest_type)
			pest_label.modulate = Color(0.85, 0.20, 0.15)
		else:
			pest_label.text = "Pests: None (Healthy)"
			pest_label.modulate = Color(0.12, 0.48, 0.18)

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
		FarmTile.TileState.LOCKED: return "🔒 Wild Territory (Locked 10x10)"
		_: return "Unknown"

func _quality_string(grade_val: int) -> String:
	match grade_val:
		FarmTile.QualityGrade.A: return "Grade A"
		FarmTile.QualityGrade.B: return "Grade B"
		FarmTile.QualityGrade.C: return "Grade C"
		_: return "Grade A"
