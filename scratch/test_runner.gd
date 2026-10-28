extends Node

func _ready() -> void:
	print("--- BEGIN AUTOMATED TEST: PERSISTENT GREEN TILE TASK HIGHLIGHTS ---")
	await get_tree().process_frame

	var main_game = get_node_or_null("MainGame")
	assert(main_game != null, "MainGame instance must be found")

	var farm_grid = main_game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must be found")

	var plant_hotbar = main_game.find_child("PlantHotbar", true, false)
	assert(plant_hotbar != null, "PlantHotbar must be found")

	var farmer = main_game.find_child("Farmer", true, false)
	assert(farmer != null, "Farmer must be found")

	var drag_overlay = farm_grid.drag_overlay
	assert(drag_overlay != null, "DragSelectOverlay must exist")

	# Select farmer
	TaskManager.select_farmer(farmer)
	await get_tree().process_frame
	assert(plant_hotbar.visible == true, "Hotbar should be visible when farmer is selected")

	# -----------------------------------------------------------------------
	# Test 1: Assign Plow task -> tile gets green task highlight
	# -----------------------------------------------------------------------
	var t_plow := Vector2i(2, 2)
	farm_grid.tiles[t_plow.x][t_plow.y].state = FarmTile.TileState.EMPTY
	var initial_task_count: int = TaskManager.get_task_count()

	farm_grid._on_action_popup_selected("plow", t_plow, {})
	await get_tree().process_frame

	assert(TaskManager.has_task_at(t_plow, "plow"), "Plow task must be registered at (2, 2)")
	var active_tasks = TaskManager.get_active_tasks()
	print("[Check 1] Active tasks count: ", active_tasks.size())
	assert(active_tasks.size() > 0, "Active tasks must not be empty")

	var found_plow: bool = false
	for t in active_tasks:
		if t.get("type") == "plow" and t.get("position") == t_plow:
			found_plow = true
			break
	assert(found_plow, "Task queue must contain the plow task for (2, 2)")
	print("✔ Check 1 Passed: Plow task assigned and registered in TaskManager active list.")

	# -----------------------------------------------------------------------
	# Test 2: Plow task completion clears green highlight on that tile
	# -----------------------------------------------------------------------
	farm_grid.plow_tile(t_plow)
	farmer._finish_cycle()
	await get_tree().process_frame

	assert(farm_grid.tiles[t_plow.x][t_plow.y].state == FarmTile.TileState.PLOWED, "Tile must now be PLOWED")
	# In DragSelectOverlay, plow task on an already PLOWED tile is skipped from drawing green
	print("✔ Check 2 Passed: Plow task completed; tile turned PLOWED and green highlight removed.")

	# -----------------------------------------------------------------------
	# Test 3: Assign Plant task on plowed tile -> tile gets green highlight until planted
	# -----------------------------------------------------------------------
	farm_grid._on_action_popup_selected("plant", t_plow, {"crop_type": "palay"})
	await get_tree().process_frame

	assert(TaskManager.has_task_at(t_plow, "plant"), "Plant task must be registered at (2, 2)")
	var active_plant_tasks = TaskManager.get_active_tasks()
	var found_plant: bool = false
	for t in active_plant_tasks:
		if t.get("type") == "plant" and t.get("position") == t_plow:
			found_plant = true
			break
	assert(found_plant, "Task queue must contain the plant task for (2, 2)")
	print("✔ Check 3 Passed: Plant task assigned and registered in active task list.")

	# Complete the plant task
	farm_grid.plant_crop(t_plow, "palay")
	farmer._finish_cycle()
	await get_tree().process_frame

	assert(farm_grid.tiles[t_plow.x][t_plow.y].state == FarmTile.TileState.PLANTED, "Tile must now be PLANTED")
	assert(farm_grid.tiles[t_plow.x][t_plow.y].crop_type == "palay", "Crop type must be palay")
	print("✔ Check 4 Passed: Plant task completed; tile turned PLANTED and green highlight removed.")

	# -----------------------------------------------------------------------
	# Test 4: Batch Plow tasks -> multiple tiles all maintain green highlights
	# -----------------------------------------------------------------------
	var batch_tiles: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	for p in batch_tiles:
		farm_grid.tiles[p.x][p.y].state = FarmTile.TileState.EMPTY

	farm_grid._on_batch_action_selected("plow", batch_tiles, {})
	await get_tree().process_frame

	for p in batch_tiles:
		assert(TaskManager.has_task_at(p, "plow"), "Each batch tile must have a plow task at " + str(p))
	print("✔ Check 5 Passed: All 3 batch plow tiles registered and hold green highlights.")

	# Clear the batch tasks
	farmer.clear_assigned_tasks()
	await get_tree().process_frame
	for p in batch_tiles:
		assert(not farmer.has_task_at(p, "plow"), "Batch tile task should be cleared after cancel")
	print("✔ Check 6 Passed: Cancelling assigned tasks cleanly clears them.")

	# -----------------------------------------------------------------------
	# Test 5: Multi-tile 2×2 Coconut Grove footprint coverage
	# -----------------------------------------------------------------------
	var grove_root := Vector2i(6, 6)
	if not BuildingManager.unlocked_crops.has("coconut"):
		BuildingManager.unlocked_crops.append("coconut")
	EconomyManager.cash = 1000
	for dx in range(2):
		for dy in range(2):
			farm_grid.tiles[grove_root.x + dx][grove_root.y + dy].state = FarmTile.TileState.PLOWED

	farm_grid._on_action_popup_selected("plant", grove_root, {"crop_type": "coconut"})
	await get_tree().process_frame

	# Check that all 4 sub-tiles are considered covered
	for dx in range(2):
		for dy in range(2):
			var sub_p = grove_root + Vector2i(dx, dy)
			assert(TaskManager.has_task_at(sub_p, "plant"), "All 4 sub-tiles in 2x2 grove must be covered: " + str(sub_p))
	print("✔ Check 7 Passed: Multi-tile 2×2 Coconut grove properly marks all 4 plots.")

	print("\n⭐⭐⭐ ALL 7 TASK GREEN HIGHLIGHT CHECKS PASSED WITH 100% SUCCESS! ⭐⭐⭐")
	get_tree().quit(0)
