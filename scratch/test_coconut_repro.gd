extends Node

func _ready() -> void:
	print("==================================================")
	print("--- COMPREHENSIVE 2×2 COCONUT PLANTING TEST ---")
	print("==================================================")

	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var root_node = main_scene.instantiate()
	add_child(root_node)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = root_node.find_child("FarmGrid", true, false)
	var farmer = root_node.find_child("Farmer", true, false)
	EconomyManager.cash = 10000 # ensure ample funds
	TaskManager.select_farmer(farmer)

	# ----------------------------------------------------
	# SCENARIO 1: Single-click planting on root (2, 2)
	# ----------------------------------------------------
	print("\n[Test 1] Single click at root (2, 2)...")
	for dx in range(2):
		for dy in range(2):
			var p = Vector2i(2 + dx, 2 + dy)
			farm_grid.tiles[p.x][p.y].state = FarmTile.TileState.PLOWED
			farm_grid.renderer.update_tile(p, farm_grid.tiles)

	farm_grid._auto_apply_hotbar_action([Vector2i(2, 2)], "coconut")
	assert(not farmer.current_task.is_empty(), "Plant task should be assigned to farmer")
	assert(farmer.current_task.get("crop_type") == "coconut", "Crop should be coconut")

	# Execute task
	farmer.global_position = FarmerMovement.grid_to_pixel_center(Vector2i(2, 2), farm_grid)
	farmer._tick_moving(0.1)
	farmer.work_timer = 0.01
	farmer._tick_working(0.02)

	# Verify all 4 tiles
	for dx in range(2):
		for dy in range(2):
			var p = Vector2i(2 + dx, 2 + dy)
			var t = farm_grid.tiles[p.x][p.y]
			assert(t.state == FarmTile.TileState.PLANTED, "Tile %s must be PLANTED" % str(p))
			assert(t.crop_type == "coconut", "Tile %s crop_type must be coconut" % str(p))
			assert(t.multi_tile_root_pos == Vector2i(2, 2), "Tile %s root must be (2, 2)" % str(p))
			if dx == 0 and dy == 0:
				assert(t.is_multi_tile_root == true, "Root tile must have is_multi_tile_root=true")
			else:
				assert(t.is_multi_tile_root == false, "Child tile must have is_multi_tile_root=false")
	print("✔ Test 1 PASSED: 2x2 Coconut planted cleanly from root click!")

	# ----------------------------------------------------
	# SCENARIO 2: Single-click on non-root tile (7, 7) of a 2x2 area
	# ----------------------------------------------------
	print("\n[Test 2] Single click at non-root tile (7, 7) in 2x2 area (6, 6)..(7, 7)...")
	for dx in range(2):
		for dy in range(2):
			var p = Vector2i(6 + dx, 6 + dy)
			farm_grid.tiles[p.x][p.y].state = FarmTile.TileState.PLOWED
			farm_grid.renderer.update_tile(p, farm_grid.tiles)

	# Click on (7, 7) - the bottom-right tile!
	farm_grid._auto_apply_hotbar_action([Vector2i(7, 7)], "coconut")
	assert(farmer.current_task.get("position") == Vector2i(6, 6), "Candidate root should auto-detect root (6, 6)")

	# Execute task
	farmer.global_position = FarmerMovement.grid_to_pixel_center(Vector2i(6, 6), farm_grid)
	farmer._tick_moving(0.1)
	farmer.work_timer = 0.01
	farmer._tick_working(0.02)

	for dx in range(2):
		for dy in range(2):
			var p = Vector2i(6 + dx, 6 + dy)
			var t = farm_grid.tiles[p.x][p.y]
			assert(t.state == FarmTile.TileState.PLANTED, "Tile %s must be PLANTED" % str(p))
			assert(t.crop_type == "coconut", "Tile %s crop_type must be coconut" % str(p))
			assert(t.multi_tile_root_pos == Vector2i(6, 6), "Tile %s root must be (6, 6)" % str(p))
	print("✔ Test 2 PASSED: Candidate root auto-detected (6, 6) from click on (7, 7)!")

	# ----------------------------------------------------
	# SCENARIO 3: Drag-select over multiple 2x2 plots (4x4 = 4 groves)
	# ----------------------------------------------------
	print("\n[Test 3] Drag-select over 4x4 area (0, 0)..(3, 3) (minus (2,2) which is planted)...")
	# Let's use (0, 4)..(3, 7) as a fresh 4x4
	var drag_tiles: Array[Vector2i] = []
	for x in range(0, 4):
		for y in range(4, 8):
			var p = Vector2i(x, y)
			drag_tiles.append(p)
			farm_grid.tiles[p.x][p.y].state = FarmTile.TileState.PLOWED
			farm_grid.renderer.update_tile(p, farm_grid.tiles)

	farm_grid._auto_apply_hotbar_action(drag_tiles, "coconut")
	var queued_count = farmer.assigned_tasks.size() + (1 if not farmer.current_task.is_empty() else 0)
	print("Queued multi-tile tasks count: ", queued_count)
	assert(queued_count == 4, "4x4 area should yield exactly 4 distinct 2x2 coconut groves")
	print("✔ Test 3 PASSED: Drag-selecting 4x4 successfully queued 4 coconut groves!")

	# ----------------------------------------------------
	# SCENARIO 4: Incomplete 2x2 plot should reject planting
	# ----------------------------------------------------
	print("\n[Test 4] Attempt planting on incomplete 3-tile plowed area (8, 0)...")
	farm_grid.tiles[8][0].state = FarmTile.TileState.PLOWED
	farm_grid.tiles[9][0].state = FarmTile.TileState.PLOWED
	farm_grid.tiles[8][1].state = FarmTile.TileState.PLOWED
	farm_grid.tiles[9][1].state = FarmTile.TileState.EMPTY # Unplowed grass!

	var can_plant_incomplete = farm_grid.can_plant_crop(Vector2i(8, 0), "coconut")
	assert(can_plant_incomplete == false, "can_plant_crop must return false if any tile is not plowed")
	print("✔ Test 4 PASSED: Incomplete plot correctly rejected!")

	# ----------------------------------------------------
	# SCENARIO 5: Perennial Regrowth on Harvest
	# ----------------------------------------------------
	print("\n[Test 5] Coconut perennial harvest and regrowth...")
	var grove_root = Vector2i(2, 2)
	# Fast-forward grove to HARVESTABLE
	for dx in range(2):
		for dy in range(2):
			var p = grove_root + Vector2i(dx, dy)
			var t = farm_grid.tiles[p.x][p.y]
			t.state = FarmTile.TileState.HARVESTABLE
			t.growth_progress = 1.0

	var storage_before = MarketManager.get_stored_units_for_crop("coconut")
	farm_grid.harvest_tile(grove_root)
	var storage_after = MarketManager.get_stored_units_for_crop("coconut")
	print("Harvested coconuts added to storage: ", storage_after - storage_before)
	assert(storage_after - storage_before == 400, "2x2 coconut harvest must yield 400 units")

	# Check that palm remains standing in GROWING state
	for dx in range(2):
		for dy in range(2):
			var p = grove_root + Vector2i(dx, dy)
			var t = farm_grid.tiles[p.x][p.y]
			assert(t.state == FarmTile.TileState.GROWING, "Coconut must remain in GROWING state after harvest")
			assert(t.growth_progress >= 0.5, "Regrowth progress must be preserved")
			assert(t.crop_type == "coconut", "Crop type must remain coconut")
	print("✔ Test 5 PASSED: Coconut perennial regrowth verified!")

	print("\n==================================================")
	print("🎉 ALL COCONUT TESTS PASSED COMPLETELY! 🎉")
	print("==================================================")

	root_node.queue_free()
	get_tree().quit(0)
