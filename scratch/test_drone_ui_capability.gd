extends Node

# Test script for Drone UI Capability Indicators, Locks, and Pill Layout

func _ready() -> void:
	print("--- BEGIN TEST: DRONE UI CAPABILITY INDICATORS & LOCKS ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_game_scene: PackedScene = load("res://scenes/MainGame.tscn")
	if not main_game_scene:
		push_error("FAIL: Could not load MainGame.tscn")
		get_tree().quit(1)
		return

	var main_game = main_game_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = main_game.find_child("FarmGrid", true, false)
	var hud_layer = main_game.find_child("HUDLayer", true, false)
	var drone_deck = hud_layer.find_child("DroneCommandDeck", true, false)
	var qbar = hud_layer.find_child("DroneQuickBar", true, false)

	assert(drone_deck != null, "FAIL: DroneCommandDeck should exist")
	assert(qbar != null, "FAIL: DroneQuickBar should exist")

	# -------------------------------------------------------------
	# TEST 1: Level 1 Hangar & Drone (Ground Prep only)
	# -------------------------------------------------------------
	var b_script = load("res://src/buildings/Building.gd")
	var station_lv1 = Node2D.new()
	station_lv1.set_script(b_script)
	station_lv1.building_type = "drone_station"
	station_lv1.level = 1
	station_lv1.state = 1 # ACTIVE
	station_lv1.grid_pos = Vector2i(1, 1)
	BuildingManager.register_building(station_lv1)
	farm_grid._sync_drones()

	assert(BuildingManager.get_drone_level() == 1, "FAIL: Hangar level should be 1")
	var drone: FarmDrone = farm_grid.drone
	assert(drone != null, "FAIL: Drone instantiated")
	assert(drone.get_level() == 1, "FAIL: Drone level should be 1")

	# Check DroneQuickBar for Lv.1 (Compact Capsule Pill)
	qbar.show_for_drone()
	assert(qbar.visible == true, "FAIL: QuickBar visible")
	assert("Sowing (Lv.2)" in qbar._crop_btn.text, "FAIL: QuickBar crop button must warn sowing is locked at Lv.2")
	assert(qbar._crop_popup_panel.visible == false, "FAIL: QuickBar popup should be hidden at Lv.1")
	print("PASS: DroneQuickBar Lv.1 displays compact pill layout with locked sowing indicator.")

	# Check DroneCommandDeck for Lv.1
	drone_deck.open()
	assert(drone_deck.visible == true, "FAIL: DroneCommandDeck visible")
	assert("LEVEL 1" in drone_deck._ability_badge.text, "FAIL: CommandDeck ability card must state Level 1")
	assert("SOWING LOCKED" in drone_deck._crop_hdr.text, "FAIL: CommandDeck crop header must show SOWING LOCKED")
	
	# Verify Lv.1 directives are disabled/locked
	var plant_btn: Button = drone_deck._directive_buttons["auto_plant"]
	var harvest_btn: Button = drone_deck._directive_buttons["auto_harvest"]
	var plow_btn: Button = drone_deck._directive_buttons["auto_plow"]
	assert(plant_btn.disabled == true, "FAIL: auto_plant must be disabled at Lv.1")
	assert(harvest_btn.disabled == true, "FAIL: auto_harvest must be disabled at Lv.1")
	assert(plow_btn.disabled == false, "FAIL: auto_plow must be enabled at Lv.1")
	assert("Lv.2 Req" in plant_btn.text, "FAIL: auto_plant text must mention Lv.2 Req")
	assert("Lv.3 Req" in harvest_btn.text, "FAIL: auto_harvest text must mention Lv.3 Req")

	# Verify crop buttons are disabled with Lv.2 Req at Lv.1
	var palay_btn: Button = drone_deck._crop_buttons["palay"]
	assert(palay_btn.disabled == true, "FAIL: Palay button must be disabled at Lv.1")
	assert("Lv.2 Req" in palay_btn.text, "FAIL: Palay button text must indicate Lv.2 Req")
	print("PASS: DroneCommandDeck Lv.1 correctly locks sowing, directives, and displays capability cards.")

	# -------------------------------------------------------------
	# TEST 2: Level 2 Hangar & Drone (Seeder & Biocontrol unlocked)
	# -------------------------------------------------------------
	station_lv1.level = 2
	assert(BuildingManager.get_drone_level() == 2, "FAIL: Hangar level should be 2")
	drone_deck.refresh_all()
	qbar.refresh_all()

	# Check QuickBar at Lv.2
	assert("Palay" in qbar._crop_btn.text, "FAIL: QuickBar crop button shows Palay at Lv.2")
	qbar._on_crop_btn_pressed()
	assert(qbar._crop_popup_panel.visible == true, "FAIL: QuickBar crop popup opens on click at Lv.2")
	print("PASS: DroneQuickBar Lv.2 enables flyout crop selector and displays active seed.")

	# Check CommandDeck at Lv.2
	assert("LEVEL 2" in drone_deck._ability_badge.text, "FAIL: CommandDeck ability card must state Level 2")
	assert(drone_deck._directive_buttons["auto_plant"].disabled == false, "FAIL: auto_plant enabled at Lv.2")
	assert(drone_deck._directive_buttons["auto_spray"].disabled == false, "FAIL: auto_spray enabled at Lv.2")
	assert(drone_deck._directive_buttons["auto_harvest"].disabled == true, "FAIL: auto_harvest remains locked at Lv.2")
	assert(drone_deck._crop_buttons["palay"].disabled == false, "FAIL: Palay button enabled at Lv.2")
	print("PASS: DroneCommandDeck Lv.2 unlocks precision seeding and biocontrol while keeping harvest locked.")

	# -------------------------------------------------------------
	# TEST 3: Level 3 Hangar & Drone (Full Autonomous Loop)
	# -------------------------------------------------------------
	station_lv1.level = 3
	drone_deck.refresh_all()
	qbar.refresh_all()

	assert("Lv.3" in qbar._drone_cycle_btn.text, "FAIL: QuickBar shows Lv.3 on drone cycler")
	assert("LEVEL 3" in drone_deck._ability_badge.text, "FAIL: CommandDeck ability card must state Level 3")
	assert(drone_deck._directive_buttons["auto_harvest"].disabled == false, "FAIL: auto_harvest enabled at Lv.3")
	print("PASS: Central Hangar Lv.3 upgrades all drones fleet-wide to master harvest loop.")

	print("--- ALL DRONE UI CAPABILITY & LOCK TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
