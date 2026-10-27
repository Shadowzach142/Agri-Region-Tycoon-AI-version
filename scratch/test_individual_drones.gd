# test_individual_drones.gd
# Tests central Hangar fleet avionics upgrade and repeatable Drone Landing Pads (like Bahay Kubo)
extends Node

func _ready() -> void:
	print("--- BEGIN TEST: DRONE HANGAR FLEET UPGRADE & REPEATABLE LANDING PADS ---")

	# 1. Reset state
	BuildingManager.placed_buildings.clear()
	BuildingManager.active_drones = 0
	EconomyManager.cash = 10000

	# 2. Build Central Hangar (Lv.2) — One-time purchase upgrading all drones
	var hangar: Node2D = Node2D.new()
	hangar.set_script(load("res://src/buildings/Building.gd"))
	hangar.building_type = "drone_station"
	hangar.state = hangar.BuildingState.ACTIVE
	hangar.level = 2
	hangar.position = Vector2(100, 100)
	add_child(hangar)
	BuildingManager.register_building(hangar)

	assert(BuildingManager.has_drone_station() == true, "FAIL: Should have active drone station")
	assert(BuildingManager.get_drone_level() == 2, "FAIL: Central avionics level should be 2")

	# 3. Build Repeatable Drone Landing Pad #1 (Lv.2, stores 2 drones)
	var pad1: Node2D = Node2D.new()
	pad1.set_script(load("res://src/buildings/Building.gd"))
	pad1.building_type = "drone_pad"
	pad1.state = pad1.BuildingState.ACTIVE
	pad1.level = 2
	pad1.position = Vector2(300, 200)
	add_child(pad1)
	BuildingManager.register_building(pad1)

	assert(BuildingManager.get_drone_pad_count() == 1, "FAIL: Should have 1 drone pad")
	assert(BuildingManager.get_drone_capacity() == 2, "FAIL: Pad Lv.2 should grant 2 drone capacity")
	print("PASS: Drone Landing Pad Lv.2 stores 2 drones.")

	# 4. Build Repeatable Drone Landing Pad #2 (Lv.1, stores 1 drone)
	var pad2: Node2D = Node2D.new()
	pad2.set_script(load("res://src/buildings/Building.gd"))
	pad2.building_type = "drone_pad"
	pad2.state = pad2.BuildingState.ACTIVE
	pad2.level = 1
	pad2.position = Vector2(500, 200)
	add_child(pad2)
	BuildingManager.register_building(pad2)

	assert(BuildingManager.get_drone_pad_count() == 2, "FAIL: Should have 2 drone pads")
	assert(BuildingManager.get_drone_capacity() == 3, "FAIL: Pad1 (Lv.2) + Pad2 (Lv.1) should grant 3 drone capacity")
	print("PASS: Buying additional Drone Landing Pad expands fleet capacity (2 + 1 = 3 drones).")

	# 5. Instantiate FarmGrid & sync fleet
	var fg_script = load("res://src/core/FarmGrid.gd")
	var fg: Node2D = Node2D.new()
	fg.set_script(fg_script)
	add_child(fg)
	fg._sync_drones()

	assert(fg.drones.size() == 3, "FAIL: FarmGrid should have 3 FarmDrone instances")
	var d1: FarmDrone = fg.drones[0]
	var d2: FarmDrone = fg.drones[1]
	var d3: FarmDrone = fg.drones[2]

	assert(d1.drone_index == 1, "FAIL: d1 index should be 1")
	assert(d2.drone_index == 2, "FAIL: d2 index should be 2")
	assert(d3.drone_index == 3, "FAIL: d3 index should be 3")

	# Verify all drones inherit central Hangar avionics (Lv.2)
	assert(d1.get_level() == 2, "FAIL: d1 level should be 2 (from central Hangar)")
	assert(d2.get_level() == 2, "FAIL: d2 level should be 2 (from central Hangar)")
	assert(d3.get_level() == 2, "FAIL: d3 level should be 2 (from central Hangar)")
	print("PASS: Central Drone Hangar upgraded all 3 drones fleet-wide to Lv.2.")

	# 6. Test Fleet-wide Upgrade: upgrade Hangar to Lv.3
	hangar.level = 3
	assert(BuildingManager.get_drone_level() == 3, "FAIL: Central Hangar level should be 3")
	assert(d1.get_level() == 3, "FAIL: d1 should now be Lv.3")
	assert(d2.get_level() == 3, "FAIL: d2 should now be Lv.3")
	assert(d3.get_level() == 3, "FAIL: d3 should now be Lv.3")
	print("PASS: Upgrading Hangar to Lv.3 instantly upgraded all drones fleet-wide to Lv.3!")

	# 7. Individual Selection
	fg.select_drone_by_index(1)
	assert(fg.get_selected_drone() == d1, "FAIL: Selected drone should be d1")
	assert(d1.is_selected == true, "FAIL: d1 should be selected")
	assert(d2.is_selected == false, "FAIL: d2 should not be selected")

	fg.select_drone_by_index(2)
	assert(fg.get_selected_drone() == d2, "FAIL: Selected drone should be d2")
	assert(d1.is_selected == false, "FAIL: d1 should no longer be selected")
	assert(d2.is_selected == true, "FAIL: d2 should be selected")
	print("PASS: Individual drone selection works seamlessly.")

	# 8. Crop Assignment & Distinct Automation Zones
	d1.set_crop("palay")
	d2.set_crop("yellow_corn")

	var zone_a: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2)]
	var zone_b: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)]

	d1.deploy(zone_a, "palay")
	d2.deploy(zone_b, "yellow_corn")

	assert(d1.crop_type == "palay", "FAIL: d1 crop should be palay")
	assert(d2.crop_type == "yellow_corn", "FAIL: d2 crop should be yellow_corn")
	assert(d1.zone.size() == 4, "FAIL: d1 zone size should be 4")
	assert(d2.zone.size() == 4, "FAIL: d2 zone size should be 4")
	print("PASS: Drones deployed to distinct fields with distinct automation crops.")

	# 9. Compact Pill DroneQuickBar tests
	var qbar_script = preload("res://src/ui/DroneQuickBar.gd")
	var qbar = qbar_script.new()
	qbar.farm_grid = fg
	add_child(qbar)
	qbar.show_for_drone()
	assert(qbar.visible == true, "FAIL: QuickBar should be visible")
	qbar._on_cycle_drone_pressed()
	assert(fg.selected_drone_index == 3, "FAIL: QuickBar cycled drone to #3")
	print("PASS: DroneQuickBar cycles drones and displays live telemetry.")

	# 10. Recall specific drone
	d1.recall()
	assert(not d1.has_zone(), "FAIL: d1 zone should be cleared after recall")
	assert(d2.has_zone(), "FAIL: d2 zone should remain active")
	print("PASS: Individual drone recall functions independently.")

	print("--- ALL 10 DRONE FLEET & LANDING PAD TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
