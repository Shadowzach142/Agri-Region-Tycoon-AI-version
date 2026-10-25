extends Node2D

func _ready() -> void:
	# Create isometric grid background showing tile diamonds
	var grid_node := Node2D.new()
	grid_node.name = "GridLines"
	add_child(grid_node)
	
	# We will render buildings across a clean showcase canvas (1280x720)
	# Arrange buildings in 2 neat rows:
	# Row 1 (y = 180): Original buildings (Bahay Kubo 2x2, Bodega 2x2, Cold Storage 3x3, Weather Station 3x3, Water Tower 2x2)
	# Row 2 (y = 480): Newly added buildings (Bayanihan 2x2, Rice Mill 2x2, Tacurong Mill 3x3, Sugar Mill 3x2, Koronadal Wholesale 4x4)
	
	var row1_items = [
		{"type": "bahay_kubo", "pos": Vector2(140, 200)},
		{"type": "bodega", "pos": Vector2(340, 200)},
		{"type": "cold_storage", "pos": Vector2(580, 200)},
		{"type": "weather_station", "pos": Vector2(860, 200)},
		{"type": "water_tower", "pos": Vector2(1120, 200)},
	]
	
	var row2_items = [
		{"type": "bayanihan_center", "pos": Vector2(140, 520)},
		{"type": "rice_mill", "pos": Vector2(340, 520)},
		{"type": "sugar_mill", "pos": Vector2(560, 520)},
		{"type": "tacurong_mill", "pos": Vector2(800, 520)},
		{"type": "koronadal_wholesale", "pos": Vector2(1090, 520)},
	]
	
	for item in row1_items:
		_spawn_showcase_building(item["type"], item["pos"], "Original (2.0x)")
		
	for item in row2_items:
		_spawn_showcase_building(item["type"], item["pos"], "Calibrated New")
		
	# Wait 2 frames and capture image
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img := get_viewport().get_texture().get_image()
	var out_path := "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/buildings_reversion_verification.png"
	img.save_png(out_path)
	print("Saved showcase screenshot to: ", out_path)
	get_tree().quit(0)

func _spawn_showcase_building(b_type: String, world_pos: Vector2, category: String) -> void:
	var b_data = Data.get_building(b_type)
	var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
	
	# Draw isometric diamond footprint outline behind building
	var diamond := Node2D.new()
	diamond.position = world_pos
	var hw: float = float(fp.x + fp.y) * 32.0
	var hh: float = float(fp.x + fp.y) * 16.0
	var top := Vector2(0, -hh)
	var right := Vector2(hw, 0)
	var bottom := Vector2(0, hh)
	var left := Vector2(-hw, 0)
	
	var poly_node := Polygon2D.new()
	poly_node.polygon = PackedVector2Array([top, right, bottom, left])
	poly_node.color = Color(0.22, 0.35, 0.18, 0.45)
	diamond.add_child(poly_node)
	
	var line_node := Line2D.new()
	line_node.points = PackedVector2Array([top, right, bottom, left, top])
	line_node.width = 1.5
	line_node.default_color = Color(0.4, 0.7, 0.3, 0.8)
	diamond.add_child(line_node)
	
	# Title label above diamond
	var lbl := Label.new()
	lbl.text = "%s (%s)\n%s [%d×%d]" % [b_data.get("display_name", b_type), category, b_type, fp.x, fp.y]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-120, -hh - 55)
	lbl.size = Vector2(240, 35)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	diamond.add_child(lbl)
	
	add_child(diamond)
	
	# Spawn building
	var b := Building.new()
	b.building_type = b_type
	b.position = world_pos
	b.state = Building.BuildingState.ACTIVE
	add_child(b)
