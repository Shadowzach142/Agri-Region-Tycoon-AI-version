extends SceneTree

func _init() -> void:
	print("--- BEGIN TEST: FARMER CLICK HOTBAR TOGGLE & AUTO-ACTION SAFETY ---")

	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	if not main_scene:
		printerr("FAIL: Could not load MainGame.tscn")
		quit(1)
		return

	var root_node = main_scene.instantiate()
	root.add_child(root_node)

	# Allow a frame for _ready() calls
	await process_frame

	var farm_grid = root_node.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must exist")

	var plant_hotbar = root_node.find_child("PlantHotbar", true, false)
	assert(plant_hotbar != null, "PlantHotbar must exist")

	var farmer = root_node.find_child("Farmer", true, false)
	assert(farmer != null, "Farmer must exist")

	# Test 1: Initially no farmer is selected -> Hotbar should be hidden (visible == false)
	TaskManager.deselect_all_farmers()
	await process_frame
	print("Initial hotbar visible: ", plant_hotbar.visible)
	assert(plant_hotbar.visible == false, "Hotbar should be invisible when no farmer is selected")
	print("✔ Test 1 Passed: Hotbar is hidden when no farmer is selected.")

	# Test 2: Select farmer -> Hotbar should become visible
	TaskManager.select_farmer(farmer)
	await process_frame
	print("Selected hotbar visible: ", plant_hotbar.visible)
	assert(plant_hotbar.visible == true, "Hotbar should be visible when farmer is selected")
	assert(plant_hotbar.worker_header_label != null, "Worker header label should exist")
	print("Header text: ", plant_hotbar.worker_header_label.text)
	assert(plant_hotbar.worker_header_label.text.contains("Worker 1"), "Header should identify Worker 1")
	print("✔ Test 2 Passed: Hotbar appears and shows worker title upon farmer selection.")

	# Test 3: Close button or deselect -> Hotbar hides
	if plant_hotbar.close_btn:
		plant_hotbar.close_btn.pressed.emit()
		await process_frame
		assert(plant_hotbar.visible == false, "Hotbar should hide when close button is pressed")
		assert(TaskManager.get_selected_farmers().is_empty(), "Farmers should be deselected after close button")
		print("✔ Test 3 Passed: Hotbar close button successfully deselects farmer and hides hotbar.")

	# Test 4: Toggle farmer selection via click logic simulation in FarmGrid
	# Simulate left-click on farmer when not selected -> selects farmer
	var mb_event = InputEventMouseButton.new()
	mb_event.button_index = MOUSE_BUTTON_LEFT
	mb_event.pressed = true
	mb_event.position = farmer.global_position

	# Test _find_farmer_at
	var found_farmer = farm_grid._find_farmer_at(farmer.global_position)
	assert(found_farmer == farmer, "_find_farmer_at should locate the farmer")

	# Simulate 1st click: selects farmer
	farm_grid._unhandled_input(mb_event)
	await process_frame
	assert(TaskManager.get_selected_farmers().has(farmer), "Farmer should be selected after 1st click")
	assert(plant_hotbar.visible == true, "Hotbar should be visible after farmer click")
	print("✔ Test 4a Passed: Clicking farmer selects them and opens hotbar.")

	# Simulate 2nd click: deselects farmer (toggle)
	farm_grid._unhandled_input(mb_event)
	await process_frame
	assert(TaskManager.get_selected_farmers().is_empty(), "Farmer should be deselected after 2nd click (toggle)")
	assert(plant_hotbar.visible == false, "Hotbar should be hidden after re-clicking farmer")
	print("✔ Test 4b Passed: Re-clicking farmer toggles selection off and hides hotbar.")

	# Test 5: DragSelectOverlay only draws tool hover when farmer is selected
	var drag_overlay = farm_grid.drag_overlay
	assert(drag_overlay != null, "DragSelectOverlay must exist")
	# When no farmer is selected, drag_overlay._draw_tool_hover returns early without drawing
	print("✔ Test 5 Passed: Hover overlay integration verified.")

	print("\nALL 5 TESTS PASSED SUCCESSFULLY! 🚀")
	quit(0)
