extends Node

func _ready() -> void:
	print("========================================")
	print("Testing Right-Click Feature Removal")
	print("========================================")

	var main_game_scene = load("res://scenes/MainGame.tscn")
	assert(main_game_scene != null, "MainGame.tscn should load")

	var game = main_game_scene.instantiate()
	add_child(game)

	# Give a frame for _ready to execute
	await get_tree().process_frame

	var farm_grid = game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid should exist")

	var action_popup = game.find_child("TileActionPopup", true, false)
	assert(action_popup != null, "TileActionPopup node must exist for test/theme compatibility")

	# Test 1: Direct calls to TileActionPopup open methods are no-ops and keep it hidden
	print("Test 1: Testing TileActionPopup direct call suppression...")
	var test_tile: FarmTile = farm_grid.tiles[5][5]
	action_popup.open_for_tile(Vector2(200, 200), Vector2i(5, 5), test_tile)
	assert(action_popup.visible == false, "action_popup should remain hidden after open_for_tile")

	action_popup.open_for_batch(Vector2(200, 200), [Vector2i(5, 5), Vector2i(5, 6)], farm_grid.tiles)
	assert(action_popup.visible == false, "action_popup should remain hidden after open_for_batch")
	print("✔ TileActionPopup open_for_tile and open_for_batch cleanly suppressed")

	# Test 2: Right click mouse press on FarmGrid does NOT start box dragging
	print("Test 2: Testing right-click press on FarmGrid...")
	var farmers = get_tree().get_nodes_in_group("farmers")
	if not farmers.is_empty():
		TaskManager.select_farmer(farmers[0])
		assert(TaskManager.get_selected_farmers().size() > 0, "Farmer should be selected")

	# Simulate right-click press
	var r_press = InputEventMouseButton.new()
	r_press.button_index = MOUSE_BUTTON_RIGHT
	r_press.pressed = true
	r_press.position = Vector2(640, 200)
	farm_grid._unhandled_input(r_press)

	assert(farm_grid.is_box_dragging == false, "Right click should NEVER start box dragging")
	assert(action_popup.visible == false, "Right click should NEVER open action_popup")
	assert(TaskManager.get_selected_farmers().is_empty(), "Right click should cleanly deselect workers")
	assert(farm_grid.selected_tiles.is_empty(), "Right click should clear selected_tiles")
	print("✔ Right click press deselects workers and tiles without initiating drag or popup")

	# Test 3: Right click release does NOT open popup
	print("Test 3: Testing right-click release...")
	var r_release = InputEventMouseButton.new()
	r_release.button_index = MOUSE_BUTTON_RIGHT
	r_release.pressed = false
	r_release.position = Vector2(640, 200)
	farm_grid._unhandled_input(r_release)

	assert(action_popup.visible == false, "Right click release should NEVER open action_popup")
	print("✔ Right click release cleanly ignored without opening menu")

	# Test 4: Left-click still initiates drag and worker selection normally
	print("Test 4: Testing left-click functionality remains intact...")
	var l_press = InputEventMouseButton.new()
	l_press.button_index = MOUSE_BUTTON_LEFT
	l_press.pressed = true
	l_press.position = Vector2(640, 320)
	farm_grid._unhandled_input(l_press)

	assert(farm_grid.is_box_dragging == true, "Left click on valid farm grid should initiate drag tracking")

	var l_release = InputEventMouseButton.new()
	l_release.button_index = MOUSE_BUTTON_LEFT
	l_release.pressed = false
	l_release.position = Vector2(640, 320)
	farm_grid._finish_drag(l_release)

	assert(farm_grid.is_box_dragging == false, "Left release finishes drag")
	assert(action_popup.visible == false, "Left click does not open legacy action popup")
	print("✔ Left click farming and drag functionality fully intact")

	print("========================================")
	print("ALL RIGHT-CLICK REMOVAL TESTS PASSED 100%!")
	print("========================================")
	get_tree().quit(0)
