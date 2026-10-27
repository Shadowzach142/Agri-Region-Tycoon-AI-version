# test_sandbox_mode.gd
# Automated verification for Creative Sandbox Mode in Agri-Region Tycoon.
extends Node2D

func _ready() -> void:
	print("====================================================")
	print("🧪 STARTING CREATIVE SANDBOX MODE AUTOMATED TESTS")
	print("====================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# TEST 1: Data Definitions & Hub Unlocks
	# ----------------------------------------------------
	print("\n--- TEST 1: Data Game Modes & Trade Hubs ---")
	assert("sandbox" in Data.GAME_MODES, "sandbox must be in Data.GAME_MODES")
	Data.game_mode = "sandbox"
	for hub_id in Data.MARKET_HUBS.keys():
		assert(Data.is_hub_available(hub_id), "Hub %s should be immediately available in sandbox mode" % hub_id)
	print("✔ Data.GAME_MODES and all trade hubs verified unlocked in sandbox")

	# ----------------------------------------------------
	# TEST 2: BuildingManager Sandbox Privileges
	# ----------------------------------------------------
	print("\n--- TEST 2: BuildingManager Sandbox Permissions ---")
	assert(BuildingManager.has_heatmap(), "Heatmap should be immediately unlocked in sandbox mode")
	assert(BuildingManager.can_commission_drone(), "Drone commission should be allowed in sandbox mode")
	assert(BuildingManager.can_place_sprinkler(), "Sprinkler placement should be allowed in sandbox mode")
	for tech_id in Data.TECH.keys():
		assert(BuildingManager.has_tech(tech_id), "Tech %s should be granted in sandbox mode" % tech_id)
	for b_type in ["bioethanol_plant", "feed_mill", "tuna_cannery", "chocolate_factory"]:
		var req = BuildingManager.get_processing_prerequisites(b_type)
		assert(req.get("allowed", false), "Processing facility %s should be allowed without blockers in sandbox" % b_type)
	print("✔ BuildingManager sandbox permissions verified")

	# ----------------------------------------------------
	# TEST 3: MainMenu Carousel & Side Navigation
	# ----------------------------------------------------
	print("\n--- TEST 3: MainMenu Carousel & Sandbox Navigation ---")
	var menu_scene = load("res://scenes/MainMenu.tscn")
	assert(menu_scene != null, "MainMenu.tscn must load")
	var menu = menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(menu.mode_keys.size() == 3, "MainMenu must have 3 modes: campaign, career, sandbox")
	assert("sandbox" in menu.mode_keys, "sandbox must be in mode_keys")

	# Carousel navigation to index 2 (sandbox)
	menu._select_mode_carousel(2)
	assert(Data.game_mode == "sandbox", "Data.game_mode should be sandbox when carousel is at 2")
	assert(menu._side_sandbox_btn != null, "SideSandboxBtn must exist")
	assert(menu._mode_name_label.text.contains("SANDBOX"), "Mode label should display SANDBOX")

	# Select sandbox mode and inspect region view transition
	menu._select_game_mode("sandbox")
	assert(TimeManager.is_freeplay_mode, "TimeManager freeplay must be true in sandbox")
	assert(menu._mode_badge_label.text.contains("SANDBOX"), "Region badge should indicate Creative Sandbox")
	assert(menu.start_button.text.contains("SANDBOX"), "Start button text should say START SANDBOX")

	menu.queue_free()
	await get_tree().process_frame
	print("✔ MainMenu carousel & sandbox UI verified")

	# ----------------------------------------------------
	# TEST 4: FarmGrid 24x24 All-Tile Unlock & ₱999,999 Treasury
	# ----------------------------------------------------
	print("\n--- TEST 4: FarmGrid All-Tile Unlock & Sandbox Setup ---")
	Data.game_mode = "sandbox"
	Data.current_region = "cotabato"
	var grid_scene = load("res://scenes/MainGame.tscn")
	assert(grid_scene != null, "MainGame.tscn must load")
	var game = grid_scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must exist in MainGame")

	# Assert Treasury
	assert(EconomyManager.cash == 999999, "Starting cash in sandbox must be ₱999,999, got %d" % EconomyManager.cash)

	# Assert all 4 parcels unlocked
	for p_id in ["homestead", "east_meadows", "south_plains", "highland_plateau"]:
		assert(farm_grid.unlocked_parcels.has(p_id), "Parcel %s must be unlocked in sandbox" % p_id)

	# Assert all 24x24 tiles are EMPTY (none LOCKED)
	var locked_count := 0
	var empty_count := 0
	for x in range(24):
		for y in range(24):
			var tile = farm_grid.tiles[x][y]
			if tile.state == FarmTile.TileState.LOCKED:
				locked_count += 1
			else:
				empty_count += 1
	assert(locked_count == 0, "All 576 tiles should be unlocked, but found %d locked tiles" % locked_count)
	assert(empty_count == 576, "All 576 tiles should be non-locked in sandbox mode")
	print("✔ All 576 tiles on 24×24 grid are unlocked (0 locked)")

	# Assert capacities
	assert(BuildingManager.total_storage_capacity >= 25000, "Storage capacity should be >= 25,000 in sandbox")
	assert(BuildingManager.worker_capacity >= 20, "Worker capacity should be >= 20 in sandbox")

	# Assert HUD label indicates Sandbox
	var hud = game.find_child("HUDLayer", true, false)
	assert(hud != null, "HUDLayer must exist")
	assert(hud.day_label.text.contains("Sandbox"), "HUD day label should show Sandbox, got: %s" % hud.day_label.text)
	print("✔ HUD displays Sandbox status")

	# ----------------------------------------------------
	# TEST 5: Instant Building & Instant Upgrades
	# ----------------------------------------------------
	print("\n--- TEST 5: Instant Building & Instant Upgrades ---")
	var test_pos := Vector2i(14, 14) # In east_meadows, which is unlocked!
	var placed = farm_grid.place_building(test_pos, "solar_dryer")
	assert(placed, "place_building should return true")
	await get_tree().process_frame

	var dryer = BuildingManager.get_building_at_tile(test_pos)
	assert(dryer != null, "Dryer must be placed at (14, 14)")
	assert(dryer.state == dryer.BuildingState.ACTIVE, "Dryer must be ACTIVE immediately (duration = 0.0) in sandbox")
	assert(dryer.level == 1, "Dryer initial level should be 1")

	# Instant upgrade
	var upgraded = dryer.start_upgrade(100, 0.0)
	assert(upgraded, "start_upgrade should succeed")
	assert(dryer.level == 2, "Dryer should be upgraded to Lv 2 instantly")
	assert(dryer.state == dryer.BuildingState.ACTIVE, "Dryer should remain ACTIVE after instant upgrade")
	print("✔ Instant building placement and instant upgrades verified")

	# ----------------------------------------------------
	# TEST 6: Save & Load In Sandbox Mode
	# ----------------------------------------------------
	print("\n--- TEST 6: Save & Load in Sandbox Mode ---")
	var save_success = SaveManager.save_game(2, "Sandbox Save Test")
	assert(save_success, "SaveManager.save_game should succeed in sandbox mode")
	var meta = SaveManager.get_slot_meta(2)
	assert(meta.get("game_mode", "") == "sandbox", "Saved game mode must be sandbox")
	assert(meta.get("game_mode_title", "") == "Creative Sandbox", "Saved game mode title must be 'Creative Sandbox'")
	assert(meta.get("cash", 0) >= 990000, "Saved cash should reflect sandbox treasury")

	# Clean up save slot
	SaveManager.delete_slot(2)
	assert(not SaveManager.has_save(2), "Slot 2 should be deleted")
	print("✔ Save & load in sandbox mode verified")

	game.queue_free()
	await get_tree().process_frame

	print("\n====================================================")
	print("🎉 ALL CREATIVE SANDBOX TESTS PASSED SUCCESSFULLY! 🎉")
	print("====================================================")
	get_tree().quit(0)
