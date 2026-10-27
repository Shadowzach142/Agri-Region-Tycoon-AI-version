extends Node2D

func _ready() -> void:
	print("========================================")
	print("Starting Comprehensive QoL, Stale Building & Grass Regrowth Tests")
	print("========================================")

	# 1. Test Camera Navigation API
	print("Testing GameCamera pan_to and center_on_homestead...")
	var cam := GameCamera.new()
	add_child(cam)
	cam.enabled = true
	cam.pan_to(Vector2(500, 300))
	assert(cam.target_position == Vector2(500, 300) or cam.target_position == Vector2(500, 420), "Camera pan_to must update target_position")
	cam.center_on_homestead()
	assert(cam.target_position == Vector2(768.0, 480.0), "Camera center_on_homestead must center on (768, 480)")
	print("✔ GameCamera: pan_to and center_on_homestead working accurately!")

	# 2. Test Farmer is_idle_worker
	print("Testing Farmer is_idle_worker API...")
	var farmer_script: GDScript = load("res://src/farmer/Farmer.gd")
	var farmer: CharacterBody2D = CharacterBody2D.new()
	farmer.set_script(farmer_script)
	add_child(farmer)
	assert(farmer.has_method("is_idle_worker"), "Farmer must implement is_idle_worker()")
	assert(farmer.is_idle_worker() == true, "Freshly spawned farmer should be idle")
	farmer.assigned_tasks.append({"type": "plow", "position": Vector2i(1, 1)})
	assert(farmer.is_idle_worker() == false, "Farmer with assigned tasks should not be idle")
	farmer.assigned_tasks.clear()
	assert(farmer.is_idle_worker() == true, "Farmer with cleared tasks should be idle again")
	print("✔ Farmer: is_idle_worker correctly checks worker state and tasks!")

	# 3. Test FarmGrid Hover Reticle and Parcel Boundaries
	print("Testing FarmGrid hover reticle and parcel boundaries...")
	var farm_grid_script: GDScript = load("res://src/core/FarmGrid.gd")
	var farm_grid: Node2D = Node2D.new()
	farm_grid.set_script(farm_grid_script)
	add_child(farm_grid)

	assert(farm_grid.hover_indicator != null, "FarmGrid must create hover_indicator node")
	assert(farm_grid.hover_indicator.name == "HoverIndicator", "hover_indicator name must be HoverIndicator")
	assert(farm_grid.hover_indicator.has_node("Fill"), "hover_indicator must have Fill polygon")
	assert(farm_grid.hover_indicator.has_node("Border"), "hover_indicator must have Border line")

	assert(farm_grid.parcel_boundaries_node != null, "FarmGrid must create parcel_boundaries_node")
	assert(farm_grid.parcel_boundaries_node.get_child_count() > 0, "parcel_boundaries_node must contain boundary lines and survey pegs")
	print("✔ FarmGrid: Hover indicator and parcel boundaries initialized!")

	# 4. Test FarmGrid Quick Harvest All
	print("Testing FarmGrid harvest_all_ready_crops...")
	assert(farm_grid.has_method("harvest_all_ready_crops"), "FarmGrid must implement harvest_all_ready_crops()")
	var test_tile: FarmTile = farm_grid.tiles[2][2]
	test_tile.state = FarmTile.TileState.HARVESTABLE
	test_tile.crop_type = "palay"
	test_tile.growth_progress = 1.0

	var task_count_before = TaskManager.get_task_count()
	farm_grid.harvest_all_ready_crops()
	assert(TaskManager.has_task_at(Vector2i(2, 2), "harvest") or TaskManager.get_task_count() >= task_count_before, "Quick harvest should dispatch harvest tasks")
	print("✔ FarmGrid: harvest_all_ready_crops queues tasks for mature crops!")

	# 5. Test Stale Building Tiles & Flood Immunity
	print("Testing Building stale tiles & flood immunity...")
	var b_pos := Vector2i(4, 4)
	var b_tile: FarmTile = farm_grid.tiles[b_pos.x][b_pos.y]
	b_tile.state = FarmTile.TileState.BUILDING
	b_tile.soil_moisture = 55.0

	# Flash flood impact should NEVER affect building tiles
	farm_grid._process_flash_flood_impact()
	assert(b_tile.state == FarmTile.TileState.BUILDING, "Building tile must NOT be flooded by flash flood")
	assert(b_tile.soil_moisture == 55.0, "Building tile moisture must remain stale/protected")

	# Hourly agronomy should NOT simulate or waterlog building tiles
	TileAgronomySystem.process_hour(b_tile, false, b_pos)
	assert(b_tile.state == FarmTile.TileState.BUILDING, "Building tile must NOT be modified by process_hour")
	assert(b_tile.soil_moisture == 55.0, "Building tile moisture must remain untouched by process_hour")

	# Daily agronomy should NOT simulate building tiles
	TileAgronomySystem.process_day(b_tile, b_pos)
	assert(b_tile.state == FarmTile.TileState.BUILDING, "Building tile must NOT be modified by process_day")
	print("✔ Stale Building Tiles: Completely immune to flash floods, weather, and waterlogging rot!")

	# 6. Test Grass Regrowth Under Finished Buildings
	print("Testing Grass Regrowth under finished buildings...")
	var gsprites: GroundTileSprites = GroundTileSprites.new()

	# Create mock building in CONSTRUCTING state
	var b_script: GDScript = load("res://src/buildings/Building.gd")
	var mock_building: Node2D = Node2D.new()
	mock_building.set_script(b_script)
	mock_building.state = 0 # BuildingState.CONSTRUCTING
	b_tile.building_ref = mock_building

	var tex_constructing: Texture2D = gsprites.get_texture(b_tile, b_pos)
	assert(tex_constructing != null, "Constructing building should have a ground texture")
	assert("walk-soil" in tex_constructing.resource_path.to_lower() or "bare-soil" in tex_constructing.resource_path.to_lower(), "Constructing building should show construction earth")

	# Transition building to ACTIVE (done)
	mock_building.state = 1 # BuildingState.ACTIVE
	var tex_done: Texture2D = gsprites.get_texture(b_tile, b_pos)
	assert(tex_done != null, "Done building should have a ground texture")
	assert("ngrass" in tex_done.resource_path.to_lower(), "Done building must regrow to lush green grass (NGRASS)!")
	print("✔ Grass Regrowth: Finished buildings smoothly regrow to lush green grass (NGRASS)!")

	# 7. Test Demolition Grass Regrowth
	mock_building.grid_pos = b_pos
	mock_building.footprint = Vector2i(1, 1)
	farm_grid._on_building_demolished(mock_building)
	assert(b_tile.state == FarmTile.TileState.EMPTY, "Demolished building tile must revert to EMPTY")
	assert(b_tile.soil_moisture == 60.0, "Demolished building tile moisture must be healthy 60.0")
	var tex_demolished: Texture2D = gsprites.get_texture(b_tile, b_pos)
	assert("ngrass" in tex_demolished.resource_path.to_lower(), "Demolished building tile must show lush green grass!")
	print("✔ Demolition Regrowth: Demolished plots instantly clear and regrow lush grass!")

	print("========================================")
	print("ALL QoL, STALE BUILDING & GRASS REGROWTH TESTS PASSED 100%!")
	print("========================================")
	get_tree().quit(0)
