# scratch/test_tiered_hotbar.gd
extends Node

func _ready() -> void:
	print("--- BEGIN AUTOMATED TEST: TIERED CATEGORY HOTBAR & VERTICAL FLYOUT ---")
	await get_tree().process_frame

	var main_game = get_node_or_null("MainGame")
	assert(main_game != null, "MainGame instance must be found")

	var farm_grid = main_game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must be found")

	var plant_hotbar: PlantHotbar = main_game.find_child("PlantHotbar", true, false) as PlantHotbar
	assert(plant_hotbar != null, "PlantHotbar must be found")

	var farmer = main_game.find_child("Farmer", true, false)
	assert(farmer != null, "Farmer must be found")

	# Test 1: Selection toggle
	TaskManager.deselect_all_farmers()
	await get_tree().process_frame
	assert(plant_hotbar.visible == false, "Hotbar must be hidden when no worker selected")
	print("✔ Test 1 Passed: Hotbar hidden when no farmer selected.")

	TaskManager.select_farmer(farmer)
	await get_tree().process_frame
	assert(plant_hotbar.visible == true, "Hotbar must be visible when farmer selected")
	print("✔ Test 2 Passed: Hotbar visible when farmer selected.")

	# Test 2: Category slots exist
	assert(plant_hotbar.category_slots.has("seeds"), "Seeds category slot exists")
	assert(plant_hotbar.category_slots.has("tools"), "Tools category slot exists")
	assert(plant_hotbar.category_slots.has("treatments"), "Treatments category slot exists")
	print("✔ Test 3 Passed: All 3 category slots exist in primary docked bar.")

	# Test 3: Open Seeds flyout drawer
	plant_hotbar._on_category_slot_pressed("seeds")
	await get_tree().process_frame
	assert(plant_hotbar.flyout_drawer.visible == true, "Flyout drawer must be open")
	assert(plant_hotbar.open_flyout_category == "seeds", "Open flyout must be seeds")
	assert(plant_hotbar.flyout_items_vbox.get_child_count() == 7, "Seeds drawer must contain all 7 crops")
	print("✔ Test 4 Passed: Seeds flyout drawer opens vertically with 7 crops.")

	# Test 4: Select Banana from flyout
	plant_hotbar._on_flyout_item_selected("seeds", "banana")
	await get_tree().process_frame
	assert(plant_hotbar.selected_tool == "banana", "Selected tool must be banana")
	assert(PlantHotbar.get_selected_tool() == "banana", "Static get_selected_tool must be banana")
	assert(plant_hotbar.selected_category_items["seeds"] == "banana", "Seeds category item must be banana")
	assert(plant_hotbar.flyout_drawer.visible == false, "Flyout drawer must close after selection")
	print("✔ Test 5 Passed: Selected Banana from drawer -> primary Seeds slot updated to Banana and drawer closed.")

	# Test 5: Open Tools flyout drawer
	plant_hotbar._on_category_slot_pressed("tools")
	await get_tree().process_frame
	assert(plant_hotbar.flyout_drawer.visible == true, "Tools drawer must be open")
	assert(plant_hotbar.open_flyout_category == "tools", "Open flyout must be tools")
	assert(plant_hotbar.flyout_items_vbox.get_child_count() == 4, "Tools drawer must contain 4 tools")
	print("✔ Test 6 Passed: Tools flyout drawer opens vertically with 4 tools (Plow, Water, Harvest, Clear).")

	# Test 6: Select Watering Can from flyout
	plant_hotbar._on_flyout_item_selected("tools", "water")
	await get_tree().process_frame
	assert(plant_hotbar.selected_tool == "water", "Selected tool must be water")
	assert(plant_hotbar.selected_category_items["tools"] == "water", "Tools category item must be water")
	print("✔ Test 7 Passed: Selected Watering Can -> primary Tools slot updated to Water.")

	# Test 7: Verify auto-action dispatch with Water
	var t_planted := Vector2i(3, 3)
	farm_grid.tiles[t_planted.x][t_planted.y].state = FarmTile.TileState.PLANTED
	farm_grid.tiles[t_planted.x][t_planted.y].crop_type = "palay"

	farm_grid._auto_apply_hotbar_action([t_planted], "water")
	await get_tree().process_frame
	assert(TaskManager.has_task_at(t_planted, "water"), "Water task must be queued at (3, 3)")
	print("✔ Test 8 Passed: Click/drag auto-applies Water tool to planted tile.")

	# Test 8: Select Treatment from flyout
	plant_hotbar._on_category_slot_pressed("treatments")
	await get_tree().process_frame
	assert(plant_hotbar.flyout_drawer.visible == true, "Treatments drawer must be open")
	assert(plant_hotbar.flyout_items_vbox.get_child_count() == 2, "Treatments drawer must contain 2 items")
	plant_hotbar._on_flyout_item_selected("treatments", "spray_chemical")
	await get_tree().process_frame
	assert(plant_hotbar.selected_tool == "spray_chemical", "Selected tool must be spray_chemical")
	print("✔ Test 9 Passed: Selected Chemical Spray -> primary IPM slot updated to Chemical.")

	# Re-open Seeds drawer and capture screenshot for visual inspection
	plant_hotbar._on_category_slot_pressed("seeds")
	await get_tree().process_frame
	await get_tree().process_frame

	var tex = get_viewport().get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			img.save_png("res://scratch/hotbar_screenshot.png")
			print("✔ Saved screenshot to scratch/hotbar_screenshot.png")

	print("--- ALL 9 TIERED HOTBAR TESTS PASSED 100% SUCCESSFULLY! ---")
	get_tree().quit(0)
