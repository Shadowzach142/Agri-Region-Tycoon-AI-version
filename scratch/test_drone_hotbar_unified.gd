# test_drone_hotbar_unified.gd
# Tests farmer-like drone control directly on PlantHotbar and strict highlight isolation.
extends Node

func _ready() -> void:
	print("--- BEGIN TEST: FARMER-LIKE DRONE HOTBAR & HIGHLIGHT ISOLATION ---")

	# 1. Reset state
	BuildingManager.placed_buildings.clear()
	BuildingManager.active_drones = 0
	BuildingManager.active_workers = 1
	BuildingManager.worker_capacity = 1
	EconomyManager.cash = 10000

	# 2. Standalone Repeatable Drone Landing Pad #1 (Lv.2) — no Hangar needed!
	var pad1: Node2D = Node2D.new()
	pad1.set_script(load("res://src/buildings/Building.gd"))
	pad1.building_type = "drone_pad"
	pad1.state = pad1.BuildingState.ACTIVE
	pad1.level = 2
	pad1.position = Vector2(200, 200)
	add_child(pad1)
	BuildingManager.register_building(pad1)

	assert(BuildingManager.get_drone_pad_count() == 1, "FAIL: Should have 1 drone pad")
	assert(BuildingManager.get_drone_capacity() == 2, "FAIL: Pad Lv.2 should grant 2 drone capacity")
	assert(BuildingManager.get_drone_level() == 2, "FAIL: Fleet level should be Lv.2 from pad")
	print("PASS [1/8]: Standalone Drone Landing Pad Lv.2 provides 2 drone capacity and Lv.2 avionics without any Hangar.")

	# 3. Add Repeatable Drone Landing Pad #2 (Lv.1)
	var pad2: Node2D = Node2D.new()
	pad2.set_script(load("res://src/buildings/Building.gd"))
	pad2.building_type = "drone_pad"
	pad2.state = pad2.BuildingState.ACTIVE
	pad2.level = 1
	pad2.position = Vector2(400, 200)
	add_child(pad2)
	BuildingManager.register_building(pad2)

	assert(BuildingManager.get_drone_pad_count() == 2, "FAIL: Should have 2 drone pads")
	assert(BuildingManager.get_drone_capacity() == 3, "FAIL: Total capacity should be 3 (2 + 1)")
	print("PASS [2/8]: Repeatable Drone Landing Pads stack capacity (total: 3 drones).")

	# 4. Create FarmGrid & sync drone fleet
	var fg_script = load("res://src/core/FarmGrid.gd")
	var fg: Node2D = Node2D.new()
	fg.name = "FarmGrid"
	fg.set_script(fg_script)
	add_child(fg)
	fg._sync_drones()

	assert(fg.drones.size() == 3, "FAIL: FarmGrid should have spawned 3 drones")
	var d1: FarmDrone = fg.drones[0]
	var d2: FarmDrone = fg.drones[1]
	var d3: FarmDrone = fg.drones[2]
	print("PASS [3/8]: FarmGrid spawned 3 autonomous drones mapped to pad berths.")

	# 5. Create Worker character
	var farmer_script = load("res://src/farmer/Farmer.gd")
	var worker: CharacterBody2D = CharacterBody2D.new()
	worker.set_script(farmer_script)
	worker.name = "Farmer_1"
	add_child(worker)
	TaskManager.select_farmer(worker)

	# 6. Create PlantHotbar
	var hotbar_script = load("res://src/ui/PlantHotbar.gd")
	var hotbar: Control = hotbar_script.new()
	add_child(hotbar)

	# Hotbar initially in Farmer mode
	assert(hotbar._is_drone_mode() == false, "FAIL: Hotbar should be in Farmer mode")
	assert(hotbar._unit_pill_btn.text.begins_with("👨‍🌾"), "FAIL: Unit pill should show Farmer icon")
	print("PASS [4/8]: PlantHotbar starts in Farmer mode with human worker selected.")

	# 7. Select Drone 1 via Unit Switcher or FarmGrid
	fg.select_drone_by_index(1)
	assert(hotbar._is_drone_mode() == true, "FAIL: Hotbar should now be in Drone mode")
	assert(hotbar._unit_pill_btn.text.begins_with("🛸"), "FAIL: Unit pill should show Drone icon")
	assert(d1.is_selected == true, "FAIL: Drone 1 should be selected")
	assert(d2.is_selected == false, "FAIL: Drone 2 should NOT be selected")
	assert(d3.is_selected == false, "FAIL: Drone 3 should NOT be selected")
	assert(TaskManager.get_selected_farmers().is_empty() == true, "FAIL: Farmers should be deselected when drone is selected")
	print("PASS [5/8]: Selecting Drone 1 deselects human farmers and switches Hotbar to Drone mode.")

	# 8. Test Hotbar Controls for Drone 1: Crop and Mode
	d1.set_crop("palay")
	hotbar._on_flyout_item_selected("seeds", "yellow_corn")
	assert(d1.crop_type == "yellow_corn", "FAIL: Hotbar seed selection should set Drone 1 crop to yellow_corn")
	assert(d2.crop_type != "yellow_corn", "FAIL: Drone 2 crop should remain unchanged")

	hotbar._on_flyout_item_selected("tools", "auto_loop")
	assert(d1.auto_plow == true and d1.auto_plant == true and d1.auto_harvest == true, "FAIL: Auto-Loop should enable auto_plow, auto_plant, auto_harvest")
	print("PASS [6/8]: Hotbar slots directly control the selected drone's assigned crop and automation mode.")

	# 9. Test Unit Cycling between Drones
	hotbar._on_cycle_unit_next()
	assert(fg.selected_drone_index == 2, "FAIL: Next button should cycle to Drone 2")
	assert(d2.is_selected == true, "FAIL: Drone 2 is selected")
	assert(d1.is_selected == false, "FAIL: Drone 1 is no longer selected")

	hotbar._on_cycle_unit_next()
	assert(fg.selected_drone_index == 3, "FAIL: Next button should cycle to Drone 3")
	assert(d3.is_selected == true, "FAIL: Drone 3 is selected")
	assert(d2.is_selected == false, "FAIL: Drone 2 is no longer selected")
	print("PASS [7/8]: Unit Switcher seamlessly cycles individual drones.")

	# 10. Switch unit type to Workers and back
	hotbar._on_switch_unit_type()
	assert(hotbar._is_drone_mode() == false, "FAIL: Switched to Worker mode")
	assert(fg.selected_drone_index == 0, "FAIL: All drones should be unselected")
	assert(d1.is_selected == false and d2.is_selected == false and d3.is_selected == false, "FAIL: All drones unselected")
	assert(TaskManager.get_selected_farmers().size() == 1, "FAIL: Worker is re-selected")

	# Switch back to drones
	hotbar._on_switch_unit_type()
	assert(hotbar._is_drone_mode() == true, "FAIL: Switched back to Drone mode")
	assert(fg.selected_drone_index == 1, "FAIL: Drone 1 selected")
	assert(TaskManager.get_selected_farmers().is_empty() == true, "FAIL: Farmers deselected")
	print("PASS [8/8]: Unit Switcher cleanly toggles between human workers and autonomous drone fleet with ZERO highlight overlap.")

	print("--- ALL 8 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
