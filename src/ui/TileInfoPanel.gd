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
var _tile_renderer: TileRenderer = null

func _get_renderer() -> TileRenderer:
	if _tile_renderer == null:
		_tile_renderer = TileRenderer.new()
	return _tile_renderer

func _discover_nodes() -> void:
	portrait_icon = find_child("PortraitIcon", true, false)
	portrait_texture = find_child("PortraitTexture", true, false) as TextureRect
	var plant_box = find_child("PlantBox", true, false)
	if plant_box and not portrait_texture:
		portrait_texture = plant_box.find_child("PortraitTexture", true, false) as TextureRect
		if not portrait_texture:
			portrait_texture = TextureRect.new()
			portrait_texture.name = "PortraitTexture"
			portrait_texture.custom_minimum_size = Vector2(60, 60)
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

	if crop_label:
		crop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crop_label.clip_text = true
		crop_label.custom_minimum_size = Vector2(130, 28)
	if state_label:
		state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		state_label.clip_text = true

func _set_portrait_texture(tex: Texture2D, fallback_icon: String = "") -> void:
	if tex != null and portrait_texture != null:
		portrait_texture.texture = tex
		portrait_texture.visible = true
		if portrait_icon:
			portrait_icon.visible = false
		return

	if portrait_texture:
		portrait_texture.texture = null
		portrait_texture.visible = false
	if portrait_icon:
		portrait_icon.visible = true
		if "text" in portrait_icon:
			portrait_icon.text = fallback_icon if not fallback_icon.is_empty() else "🌱"

func _set_portrait(icon_text: String, crop_key: String = "") -> void:
	var tex: Texture2D = null
	if not crop_key.is_empty():
		tex = _get_renderer().get_crop_sprite_texture(crop_key)
	_set_portrait_texture(tex, icon_text)

func _get_tile_texture(tile: FarmTile) -> Texture2D:
	if tile == null:
		return null

	var rnd := _get_renderer()

	# 1. Crops & Groves (perennial or annual)
	var effective_crop: String = tile.crop_type
	if effective_crop.is_empty() and tile.multi_tile_root_pos != Vector2i(-1, -1):
		var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
		if farm_grid and "tiles" in farm_grid:
			var rp: Vector2i = tile.multi_tile_root_pos
			if rp.x >= 0 and rp.x < farm_grid.tiles.size() and rp.y >= 0 and rp.y < farm_grid.tiles[0].size():
				effective_crop = farm_grid.tiles[rp.x][rp.y].crop_type

	if not effective_crop.is_empty():
		var c_data: Dictionary = Data.get_crop(effective_crop)
		if c_data.get("is_perennial", false) and tile.state == FarmTile.TileState.GROWING and tile.health > 0.4:
			var regr_days: float = float(c_data.get("regrowth_days", 0.0))
			var tot_days: float = float(c_data.get("growth_days", 1.0))
			var regrowth_start_pct: float = 1.0 - (regr_days / tot_days)
			if tile.growth_progress < regrowth_start_pct + 0.05:
				var regr_tex := rnd.get_regrowth_texture(effective_crop)
				if regr_tex != null:
					return regr_tex

		var stage: int = rnd.get_tile_crop_stage(tile)
		var stage_tex := rnd.get_crop_stage_texture(effective_crop, stage)
		if stage_tex != null:
			return stage_tex
		return rnd.get_crop_sprite_texture(effective_crop)

	# 2. Tile Grounds & Placed Buildings
	match tile.state:
		FarmTile.TileState.PLOWED:
			return preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-01.png")
		FarmTile.TileState.EMPTY:
			return preload("res://assets/sprites/ground/NGRASS/NGRASS-01.png")
		FarmTile.TileState.FLOODED:
			return preload("res://assets/sprites/ground/WGRASS/WGRASS-01.png")
		FarmTile.TileState.INFECTED:
			var pest_tex := rnd.get_pest_overlay_texture(tile.pest_type, tile.crop_type)
			if pest_tex != null:
				return pest_tex
			return preload("res://assets/sprites/ground/NGRASS/NGRASS-01.png")
		FarmTile.TileState.OBSTACLE:
			if tile.obstacle_type == "rock" or "boulder" in tile.obstacle_type:
				return rnd.get_rock_texture(selected_pos)
			else:
				return rnd.get_tree_obstacle_texture()
		FarmTile.TileState.LOCKED:
			if tile.obstacle_type == "rock" or "boulder" in tile.obstacle_type:
				return rnd.get_rock_texture(selected_pos)
			elif tile.obstacle_type != "":
				return rnd.get_tree_obstacle_texture()
			return preload("res://assets/sprites/ground/BARE SOIL/DROUGHT-SOIL-O1.png")
		FarmTile.TileState.BUILDING:
			var b_ref: Node = tile.building_ref
			if b_ref != null and is_instance_valid(b_ref):
				var prev: Dictionary = Building.get_placement_preview(b_ref.building_type, b_ref.is_flipped)
				if not prev.is_empty() and prev.has("texture") and prev["texture"] != null:
					return prev["texture"]
				match b_ref.building_type:
					"bahay_kubo": return preload("res://assets/sprites/buildings/KUBO.png")
					"solar_dryer": return preload("res://assets/sprites/buildings/DRYER.PNG")
					"cold_storage": return preload("res://assets/sprites/buildings/Cold_Storage.png")
					"drone_station": return preload("res://assets/sprites/buildings/Drone_Station.png")
					"water_station": return preload("res://assets/sprites/buildings/Water_Station.png")
					"weather_station": return preload("res://assets/sprites/buildings/Weather_Station.png")
					"grain_silo": return preload("res://assets/sprites/buildings/Silo/SILO-0.PNG")
					_: return null
			return null
		_:
			return null

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
		title_label.text = "📦 Selected: %d" % count
	var batch_tex: Texture2D = preload("res://assets/sprites/ground/BARE SOIL/BARE-SOIL-01.png")
	_set_portrait_texture(batch_tex, "🗺️")

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
		state_label.text = "Select Tool & Left-Click/Drag"

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
			pest_label.add_theme_color_override("font_color", Color(0.72, 0.10, 0.06))
		else:
			pest_label.text = "✅ 0 Infestations"
			pest_label.add_theme_color_override("font_color", Color(0.04, 0.38, 0.08))

func inspect_tile(pos: Vector2i, tile: FarmTile) -> void:
	is_batch_inspect = false
	batch_selected_tiles.clear()
	selected_pos = pos
	selected_tile = tile

	if title_label:
		title_label.text = "Tile (%d, %d)" % [pos.x, pos.y]
	if state_label:
		if tile.state == FarmTile.TileState.OBSTACLE:
			state_label.text = "🪨 Boulder Obstacle" if tile.obstacle_type == "rock" else "🪵 Old Tree Stump"
		else:
			state_label.text = _tile_state_string(tile.state)

	var tile_tex := _get_tile_texture(tile)
	var fallback_icon := "🌱"
	match tile.state:
		FarmTile.TileState.EMPTY: fallback_icon = "🌱"
		FarmTile.TileState.PLOWED: fallback_icon = "⛏️"
		FarmTile.TileState.PLANTED, FarmTile.TileState.GROWING: fallback_icon = "🌿"
		FarmTile.TileState.HARVESTABLE: fallback_icon = "🌾"
		FarmTile.TileState.FLOODED: fallback_icon = "🌊"
		FarmTile.TileState.INFECTED: fallback_icon = "🐛"
		FarmTile.TileState.OBSTACLE: fallback_icon = "🪨" if tile.obstacle_type == "rock" else "🪵"
		FarmTile.TileState.BUILDING:
			if tile.building_ref != null and is_instance_valid(tile.building_ref) and Data.get_building(tile.building_ref.building_type).get("is_decoration", false):
				fallback_icon = "🌸"
			else:
				fallback_icon = "🏛️"
		FarmTile.TileState.LOCKED: fallback_icon = "🔒"

	_set_portrait_texture(tile_tex, fallback_icon)

	if crop_label:
		if tile.state == FarmTile.TileState.LOCKED:
			var p: Dictionary = Data.get_parcel_for_tile(pos)
			crop_label.text = p.get("name", "Wild Territory")
			if state_label:
				state_label.text = "₱%s to Unlock" % Utils.format_number(p.get("cost", 1000))
		elif tile.state == FarmTile.TileState.OBSTACLE:
			crop_label.text = "Boulder Obstacle" if tile.obstacle_type == "rock" else "Old Tree Stump"
		elif tile.state == FarmTile.TileState.BUILDING:
			var b_ref: Node = tile.building_ref
			if b_ref != null and is_instance_valid(b_ref):
				var b_data := Data.get_building(b_ref.building_type)
				var raw_name: String = b_data.get("display_name", b_ref.building_type)
				var b_name: String = raw_name.split("(")[0].strip_edges()
				if b_data.get("is_decoration", false):
					crop_label.text = b_name
					if state_label:
						var subcat: String = b_data.get("decor_subcategory", "flora")
						match subcat:
							"stalls": state_label.text = "🍢 Street Stall"
							"tambayan": state_label.text = "🌴 Tambayan"
							_: state_label.text = "🌸 Garden Flora"
				else:
					crop_label.text = "%s Lv.%d" % [b_name, b_ref.level]
					if state_label:
						state_label.text = "Building Active"
			else:
				crop_label.text = "Farm Building"
		elif tile.crop_type != "" or tile.multi_tile_root_pos != Vector2i(-1, -1):
			var effective_crop: String = tile.crop_type
			var root_pos: Vector2i = tile.multi_tile_root_pos
			if effective_crop.is_empty() and root_pos != Vector2i(-1, -1):
				var farm_grid = get_tree().root.find_child("FarmGrid", true, false)
				if farm_grid and "tiles" in farm_grid:
					effective_crop = farm_grid.tiles[root_pos.x][root_pos.y].crop_type
			var c_data = Data.get_crop(effective_crop)
			crop_label.text = c_data.get("display_name", effective_crop)
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
			pest_label.text = "Infestation: " + p_data.get("display_name", tile.pest_type)
			pest_label.add_theme_color_override("font_color", Color(0.72, 0.10, 0.06))
		else:
			pest_label.text = "Pests: None (Healthy)"
			pest_label.add_theme_color_override("font_color", Color(0.04, 0.38, 0.08))

func _tile_state_string(state_val: int) -> String:
	match state_val:
		FarmTile.TileState.EMPTY: return "Empty Grass"
		FarmTile.TileState.PLOWED: return "Plowed Soil"
		FarmTile.TileState.PLANTED: return "Newly Seeded"
		FarmTile.TileState.GROWING: return "Growing Crop"
		FarmTile.TileState.HARVESTABLE: return "Ready for Harvest!"
		FarmTile.TileState.FLOODED: return "Flooded Soil"
		FarmTile.TileState.INFECTED: return "Pest Infested"
		FarmTile.TileState.OBSTACLE: return "Obstacle"
		FarmTile.TileState.BUILDING: return "Occupied"
		FarmTile.TileState.LOCKED: return "Wild Land"
		_: return "Unknown"

func _quality_string(grade_val: int) -> String:
	match grade_val:
		FarmTile.QualityGrade.A: return "Grade A"
		FarmTile.QualityGrade.B: return "Grade B"
		FarmTile.QualityGrade.C: return "Grade C"
		_: return "Grade A"
