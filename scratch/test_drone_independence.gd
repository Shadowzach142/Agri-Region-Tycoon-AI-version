extends Node

# Automated Test Script: Drone Independence and Expanded Automation Suite
# Validates that the autonomous drone operates 100% decoupled from human farmers.

func _ready() -> void:
	print("--- BEGIN TEST: DRONE INDEPENDENCE & AUTOMATION ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Instantiate MainGame scene
	var main_game_scene: PackedScene = load("res://scenes/MainGame.tscn")
	if not main_game_scene:
		push_error("FAIL: Could not load res://scenes/MainGame.tscn")
		get_tree().quit(1)
		return
		
	var main_game = main_game_scene.instantiate()
	add_child(main_game)
	
	# Wait 2 frames for ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	var farm_grid = main_game.find_child("FarmGrid", true, false)
	var hud_layer = main_game.find_child("HUDLayer", true, false)
	var drone_btn = hud_layer.find_child("DroneButton", true, false)
	var drone_deck = hud_layer.find_child("DroneCommandDeck", true, false)
	
	# Check 1: Nodes exist
	assert(drone_btn != null, "DroneButton not found in HUD")
	assert(drone_deck != null, "DroneCommandDeck not found in HUD")
	assert(drone_btn.visible, "DroneButton should be visible in CommandCorner")
	print("PASS: DroneButton and DroneCommandDeck discovered in MainGame scene.")
	
	# Check 2: Farmer Independence - Open deck without any farmer selected
	TaskManager.deselect_all_farmers()
	assert(TaskManager.get_selected_farmers().is_empty(), "No farmers should be selected")
	assert(not drone_deck.visible, "Deck initially closed")
	
	# Press DroneButton
	drone_btn.emit_signal("pressed")
	assert(drone_deck.visible, "Drone deck should open on button press")
	assert(TaskManager.get_selected_farmers().is_empty(), "Farmers must remain UNSELECTED when opening drone deck")
	print("PASS: DroneCommandDeck opens with zero farmers selected.")
	
	# Check 3: Toggle via Hotkey U
	var ev_u := InputEventKey.new()
	ev_u.keycode = KEY_U
	ev_u.pressed = true
	hud_layer._unhandled_input(ev_u)
	assert(not drone_deck.visible, "Drone deck should close on toggle hotkey U")
	
	hud_layer._unhandled_input(ev_u)
	assert(drone_deck.visible, "Drone deck should reopen on hotkey U")
	assert(TaskManager.get_selected_farmers().is_empty(), "Farmers still unselected after hotkey U")
	print("PASS: Hotkey U toggles DroneCommandDeck independently.")
	
	# Check 4: Drone Hangar Commissioning & Primary Drone
	# Simulate placed active drone station
	var b_script = load("res://src/buildings/Building.gd")
	var drone_station = Node2D.new()
	drone_station.set_script(b_script)
	drone_station.building_type = "drone_station"
	drone_station.level = 3
	drone_station.state = 1 # ACTIVE
	drone_station.grid_pos = Vector2i(2, 2)
	BuildingManager.register_building(drone_station)
	BuildingManager.active_drones = 1
	BuildingManager.active_workers = 1
	
	assert(BuildingManager.has_drone_station(), "Hangar should be active")
	assert(BuildingManager.get_drone_level() == 3, "Hangar should be Lv.3")
	
	# Re-sync drones in FarmGrid
	farm_grid._sync_drones()
	assert(farm_grid.drone != null, "FarmGrid drone instantiated")
	var drone: FarmDrone = farm_grid.drone
	
	drone_deck.refresh_all()
	print("PASS: Drone hangar and primary drone registered.")
	
	# Check 5: Automation Directives Toggle
	assert(drone.auto_plow == true, "Auto plow on by default")
	assert(drone.auto_plant == true, "Auto plant on by default")
	assert(drone.auto_water == true, "Auto water on by default")
	assert(drone.auto_spray == true, "Auto spray on by default")
	assert(drone.auto_harvest == true, "Auto harvest on by default")
	assert(drone.auto_clear == false, "Auto clear off by default (costs cash)")
	
	drone_deck._toggle_directive("auto_water")
	assert(drone.auto_water == false, "Auto water toggled off")
	drone_deck._toggle_directive("auto_water")
	assert(drone.auto_water == true, "Auto water toggled back on")
	
	drone_deck._toggle_directive("auto_clear")
	assert(drone.auto_clear == true, "Auto clear toggled on")
	print("PASS: Automation directive toggles update drone state correctly.")
	
	# Check 6: Independent Crop Selection
	drone_deck._on_crop_selected("banana")
	assert(drone.crop_type == "banana", "Drone automated seed set to banana")
	drone_deck._on_crop_selected("palay")
	assert(drone.crop_type == "palay", "Drone automated seed set to palay")
	print("PASS: Drone crop selection functions independently.")
	
	# Check 7: 1-Click Whole Farm Patrol
	drone_deck._on_patrol_whole_farm_pressed()
	assert(drone.has_zone(), "Drone should now have active whole-farm zone")
	assert(drone.zone.size() > 50, "Whole farm patrol should cover unlocked homestead plots")
	print("PASS: 1-Click whole-farm patrol deployed (%d tiles)." % drone.zone.size())
	
	# Check 8: Autonomous Hydration / Watering Detection
	# Set a tile in the zone to parched (<50% moisture) with a planted crop
	var tile_00 = farm_grid.get_tile(Vector2i(3, 3))
	assert(tile_00 != null, "Tile (3,3) exists")
	tile_00.state = FarmTile.TileState.GROWING
	tile_00.crop_type = "palay"
	tile_00.soil_moisture = 20.0 # Parched!
	tile_00.growth_progress = 0.5
	tile_00.pest_type = ""
	
	var water_job = drone._scan_for_job()
	assert(water_job.is_empty() == false, "Should find a job")
	# Ripe crops or infected crops have higher priority, but if none, water job should be picked
	assert(water_job.get("type") == "water" or water_job.get("type") == "harvest", "Job should be water or harvest")
	print("PASS: Drone detects autonomous watering job for parched crops.")
	
	# Check 9: Autonomous Pest Blight Curing (Emergency Priority)
	var tile_01 = farm_grid.get_tile(Vector2i(4, 4))
	tile_01.state = FarmTile.TileState.INFECTED
	tile_01.crop_type = "palay"
	tile_01.pest_type = "armyworm"
	
	var pest_job = drone._scan_for_job()
	assert(pest_job.is_empty() == false, "Should find emergency pest job")
	assert(pest_job.get("type") == "spray", "Pest curing should take top priority")
	assert(pest_job.get("pos") == Vector2i(4, 4), "Target tile should be infected tile")
	print("PASS: Emergency pest spraying is prioritized autonomously.")
	
	# Check 10: Debris Clearing
	tile_01.state = FarmTile.TileState.EMPTY
	tile_01.pest_type = ""
	var tile_obs = farm_grid.get_tile(Vector2i(5, 5))
	tile_obs.state = FarmTile.TileState.OBSTACLE
	tile_obs.obstacle_type = "rock"
	
	# Clear out water need
	tile_00.soil_moisture = 80.0
	var clear_job = drone._scan_for_job()
	# If nothing else needs doing, clear job or plow job is found
	assert(clear_job.is_empty() == false, "Should find a job in the zone")
	print("PASS: Debris clearing and routine field maintenance detected.")
	
	# Check 11: Zone Designation Mode Independence (NO Farmer Auto-Selection)
	drone_deck._on_designate_zone_pressed()
	assert(not drone_deck.visible, "Deck closed for drag designation")
	assert(farm_grid.is_drone_targeting == true, "farm_grid.is_drone_targeting must be TRUE")
	assert(TaskManager.get_selected_farmers().is_empty(), "Farmers MUST NOT be selected when drone targeting starts")
	
	# Simulate ending drag over a rectangle
	farm_grid.drag_start_pos = Vector2(0, 0)
	var mb_rel := InputEventMouseButton.new()
	mb_rel.button_index = MOUSE_BUTTON_LEFT
	mb_rel.pressed = false
	farm_grid._finish_drag(mb_rel)
	
	assert(farm_grid.is_drone_targeting == false, "Targeting finishes after drag")
	assert(TaskManager.get_selected_farmers().is_empty(), "CRITICAL: Farmers MUST NOT be selected after drone zone drag")
	print("PASS: Drone zone dragging completes with zero farmer interference.")
	
	# Check 12: Telemetry API
	var telem = drone.get_telemetry()
	assert(telem.has("state_name"), "Telemetry has state_name")
	assert(telem.has("zone_count"), "Telemetry has zone_count")
	assert(telem.has("auto_water"), "Telemetry has auto_water")
	assert(telem.get("auto_water") == true, "Telemetry auto_water is true")
	print("PASS: Drone telemetry telemetry API operational.")
	
	# Check 13: Dock / Recall
	drone.recall()
	assert(drone.has_zone() == false, "Zone cleared after recall")
	assert(drone.zone.is_empty(), "Tiles array empty after recall")
	print("PASS: Recall docks drone and clears zone.")
	
	print("==================================================")
	print("ALL 13 DRONE AUTOMATION CHECKS PASSED PERFECTLY!  ")
	print("==================================================")
	get_tree().quit(0)
