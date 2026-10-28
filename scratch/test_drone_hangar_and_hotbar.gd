extends Node

func _ready() -> void:
	print("--- BEGIN TEST: DRONE HANGAR & HOTBAR VERIFICATION ---")

	# Test 1: Data Definitions
	var station_data := Data.get_building("drone_station")
	assert(not station_data.is_empty(), "FAIL: drone_station must exist in Data.BUILDINGS")
	assert(station_data.get("shop_category") == "machinery", "FAIL: drone_station shop_category must be machinery")
	assert(station_data.get("max_level") == 3, "FAIL: drone_station max_level must be 3")
	assert(station_data.get("unique") == true, "FAIL: drone_station unique must be true")
	print("✓ Test 1 Passed: drone_station defined in Data.BUILDINGS with category 'machinery' & max_level 3")

	var pad_data := Data.get_building("drone_pad")
	assert(not pad_data.is_empty(), "FAIL: drone_pad must exist in Data.BUILDINGS")
	assert(pad_data.get("shop_category") == "machinery", "FAIL: drone_pad shop_category must be machinery")
	assert(pad_data.get("drone_capacity") == 1, "FAIL: drone_pad drone_capacity must be 1")
	assert(pad_data.get("unique") == false, "FAIL: drone_pad must be repeatable (unique=false)")
	print("✓ Test 2 Passed: drone_pad defined in Data.BUILDINGS with capacity 1 & unique=false")

	# Test 2: BuildingManager Hangar vs Pad Separation
	BuildingManager.placed_buildings.clear()
	var prev_mode := Data.game_mode
	Data.game_mode = "campaign"

	assert(BuildingManager.get_drone_level() == 0, "FAIL: 0 buildings should mean drone level 0")
	assert(BuildingManager.get_drone_capacity() == 0, "FAIL: 0 buildings should mean drone capacity 0")
	assert(BuildingManager.has_drone_hangar() == false, "FAIL: should not have hangar")
	assert(BuildingManager.has_drone_pad() == false, "FAIL: should not have pad")
	print("✓ Test 3 Passed: 0 buildings = 0 level and 0 capacity")

	# Add Pad #1 (Lv.1)
	var pad1 = Node2D.new()
	pad1.set_script(load("res://src/buildings/Building.gd"))
	pad1.building_type = "drone_pad"
	pad1.level = 1
	pad1.state = 1 # ACTIVE
	BuildingManager.register_building(pad1)

	assert(BuildingManager.get_drone_capacity() == 1, "FAIL: 1 pad should give 1 capacity (got %d)" % BuildingManager.get_drone_capacity())
	assert(BuildingManager.get_drone_level() == 1, "FAIL: pad without hangar should give basic level 1")
	assert(BuildingManager.has_drone_hangar() == false, "FAIL: should not have hangar yet")
	assert(BuildingManager.has_drone_pad() == true, "FAIL: should have pad")
	print("✓ Test 4 Passed: 1 Landing Pad = 1 Drone capacity, Lv.1 baseline")

	# Add Pad #2 (Lv.1)
	var pad2 = Node2D.new()
	pad2.set_script(load("res://src/buildings/Building.gd"))
	pad2.building_type = "drone_pad"
	pad2.level = 1
	pad2.state = 1
	BuildingManager.register_building(pad2)

	assert(BuildingManager.get_drone_capacity() == 2, "FAIL: 2 pads should give 2 capacity (got %d)" % BuildingManager.get_drone_capacity())
	assert(BuildingManager.get_drone_level() == 1, "FAIL: 2 pads without hangar should still be level 1")
	print("✓ Test 5 Passed: 2 Landing Pads = 2 Drones capacity, Lv.1 baseline")

	# Add Drone Command Hangar (Lv.1)
	var hangar = Node2D.new()
	hangar.set_script(load("res://src/buildings/Building.gd"))
	hangar.building_type = "drone_station"
	hangar.level = 1
	hangar.state = 1
	BuildingManager.register_building(hangar)

	assert(BuildingManager.has_drone_hangar() == true, "FAIL: should now have hangar")
	assert(BuildingManager.get_drone_hangar() == hangar, "FAIL: get_drone_hangar should return hangar node")
	assert(BuildingManager.get_drone_level() == 1, "FAIL: Hangar Lv.1 should give drone level 1")
	assert(BuildingManager.get_drone_capacity() == 2, "FAIL: Hangar should not alter pad capacity (capacity remains 2)")
	print("✓ Test 6 Passed: Hangar Lv.1 sets fleet level to 1, pad capacity remains 2")

	# Upgrade Hangar to Lv.2
	hangar.level = 2
	assert(BuildingManager.get_drone_level() == 2, "FAIL: Hangar Lv.2 should level up fleet to Lv.2")
	print("✓ Test 7 Passed: Hangar Lv.2 levels up all drones fleet-wide to Lv.2")

	# Upgrade Hangar to Lv.3
	hangar.level = 3
	assert(BuildingManager.get_drone_level() == 3, "FAIL: Hangar Lv.3 should level up fleet to Lv.3")
	print("✓ Test 8 Passed: Hangar Lv.3 levels up all drones fleet-wide to Lv.3")

	# Test 3: PlantHotbar Silver/Grey Theme & Level Gating
	var hotbar = PlantHotbar.new()
	add_child(hotbar)

	# Verify textures loaded
	assert(hotbar.tex_drone_dark_box != null, "FAIL: tex_drone_dark_box should be loaded")
	assert(hotbar.tex_drone_light_box != null, "FAIL: tex_drone_light_box should be loaded")
	assert(hotbar.tex_dark_box != null, "FAIL: tex_dark_box should be loaded")
	assert(hotbar.tex_light_box != null, "FAIL: tex_light_box should be loaded")
	print("✓ Test 9 Passed: PlantHotbar loaded both wooden (farmer) and silver/grey (drone) box textures")

	# In Farmer Mode (no drone selected)
	assert(hotbar._is_drone_mode() == false, "FAIL: Should be in worker mode initially")
	assert(hotbar._get_slot_texture(false) == hotbar.tex_dark_box, "FAIL: Worker mode should use wood dark box")
	assert(hotbar._is_category_locked_for_unit("seeds") == false, "FAIL: Seeds should not be locked for human workers")
	print("✓ Test 10 Passed: Worker mode uses wood box texture and has seeds unlocked")

	# Test Fake FarmGrid + Drone Lv.1
	var dummy_grid = Node2D.new()
	dummy_grid.name = "FarmGrid"
	add_child(dummy_grid)
	dummy_grid.set_script(load("res://src/core/FarmGrid.gd"))

	# Create a drone at Lv.1
	hangar.level = 1
	var test_drone = FarmDrone.new()
	test_drone.drone_index = 1
	test_drone.farm_grid = dummy_grid
	dummy_grid.add_child(test_drone)
	dummy_grid.drones = [test_drone]
	dummy_grid.selected_drone_index = 1

	assert(hotbar._is_drone_mode() == true, "FAIL: Should now be in drone mode")
	assert(hotbar._get_slot_texture(false) == hotbar.tex_drone_dark_box, "FAIL: Drone mode should use silver drone dark box")
	assert(hotbar._get_slot_texture(true) == hotbar.tex_drone_light_box, "FAIL: Drone mode should use silver drone light box")
	print("✓ Test 11 Passed: Drone mode instantly switches hotbar slot textures to silver/grey metallic chassis")

	# Test Level 1 locking
	assert(test_drone.get_level() == 1, "FAIL: Drone should be level 1")
	assert(hotbar._is_category_locked_for_unit("seeds") == true, "FAIL: Seeds must be LOCKED for Drone at Level 1")
	assert(hotbar._is_category_locked_for_unit("treatments") == true, "FAIL: IPM must be LOCKED for Drone at Level 1")
	assert(hotbar._is_flyout_item_locked_for_drone("plant") == true, "FAIL: Plant directive must be locked at Lv.1")
	assert(hotbar._is_flyout_item_locked_for_drone("harvest") == true, "FAIL: Harvest directive must be locked at Lv.1")
	assert(hotbar._is_flyout_item_locked_for_drone("plow") == false, "FAIL: Plow directive must be UNLOCKED at Lv.1")
	assert(hotbar._is_flyout_item_locked_for_drone("water") == false, "FAIL: Water directive must be UNLOCKED at Lv.1")
	print("✓ Test 12 Passed: At Level 1, Seeds & IPM & Harvest are LOCKED; Plow & Water are UNLOCKED")

	# Test Level 2 locking
	hangar.level = 2
	assert(test_drone.get_level() == 2, "FAIL: Drone should now be level 2")
	assert(hotbar._is_category_locked_for_unit("seeds") == false, "FAIL: Seeds must UNLOCK at Level 2")
	assert(hotbar._is_category_locked_for_unit("treatments") == false, "FAIL: IPM must UNLOCK at Level 2")
	assert(hotbar._is_flyout_item_locked_for_drone("plant") == false, "FAIL: Plant directive must UNLOCK at Lv.2")
	assert(hotbar._is_flyout_item_locked_for_drone("harvest") == true, "FAIL: Harvest directive must still be locked at Lv.2")
	print("✓ Test 13 Passed: At Level 2, Seeds & IPM & Plant are UNLOCKED; Harvest remains locked")

	# Test Level 3 locking
	hangar.level = 3
	assert(test_drone.get_level() == 3, "FAIL: Drone should now be level 3")
	assert(hotbar._is_category_locked_for_unit("seeds") == false, "FAIL: Seeds must be unlocked at Level 3")
	assert(hotbar._is_flyout_item_locked_for_drone("harvest") == false, "FAIL: Harvest directive must UNLOCK at Lv.3")
	print("✓ Test 14 Passed: At Level 3, Master Harvest & all features are UNLOCKED")

	# Cleanup
	Data.game_mode = prev_mode
	BuildingManager.placed_buildings.clear()
	print("--- ALL 14 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
