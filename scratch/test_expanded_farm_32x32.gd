extends Node2D

func _ready() -> void:
	print("--- BEGIN TEST: EXPANDED FARM GRID 32x32 (1024 PLOTS) ---")

	# Instantiate MainGame
	var main_game_scene = load("res://scenes/MainGame.tscn")
	var game = main_game_scene.instantiate()
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm: Node2D = game.find_child("FarmGrid", true, false)
	assert(farm != null, "FAIL: FarmGrid not found")

	# 1. Check Grid Size
	assert(farm.GRID_SIZE == Vector2i(32, 32), "FAIL: GRID_SIZE should be 32x32, got: %s" % str(farm.GRID_SIZE))
	print("✓ Test 1 Passed: GRID_SIZE is 32x32 (1,024 total plots)")

	# 2. Check Data.LAND_PARCELS
	assert(Data.LAND_PARCELS.size() == 4, "FAIL: Expected 4 parcels")
	var h_data = Data.get_parcel("homestead")
	assert(h_data.get("rect") == Rect2i(0, 0, 16, 16), "FAIL: Homestead rect should be (0, 0, 16, 16)")
	var em_data = Data.get_parcel("east_meadows")
	assert(em_data.get("rect") == Rect2i(16, 0, 16, 16), "FAIL: East Meadows rect should be (16, 0, 16, 16)")
	var sp_data = Data.get_parcel("south_plains")
	assert(sp_data.get("rect") == Rect2i(0, 16, 16, 16), "FAIL: South Plains rect should be (0, 16, 16, 16)")
	var hp_data = Data.get_parcel("highland_plateau")
	assert(hp_data.get("rect") == Rect2i(16, 16, 16, 16), "FAIL: Highland Plateau rect should be (16, 16, 16, 16)")
	print("✓ Test 2 Passed: All 4 parcels configured to 16x16 plots (256 plots each)")

	# 3. Check tile array allocations
	assert(farm.tiles.size() == 32, "FAIL: tiles.size() should be 32")
	for x in range(32):
		assert(farm.tiles[x].size() == 32, "FAIL: column %d should have 32 tiles" % x)
	print("✓ Test 3 Passed: 32x32 tiles allocated in memory (1,024 tiles)")

	# 4. Check initial tile states (homestead unlocked vs locked expansion)
	assert(farm.tiles[5][5].state == FarmTile.TileState.EMPTY, "FAIL: (5, 5) in homestead should be EMPTY")
	assert(farm.tiles[15][15].state == FarmTile.TileState.EMPTY, "FAIL: (15, 15) in homestead should be EMPTY")
	assert(farm.tiles[16][0].state == FarmTile.TileState.LOCKED, "FAIL: (16, 0) in East Meadows should be LOCKED")
	assert(farm.tiles[0][16].state == FarmTile.TileState.LOCKED, "FAIL: (0, 16) in South Plains should be LOCKED")
	assert(farm.tiles[20][20].state == FarmTile.TileState.LOCKED, "FAIL: (20, 20) in Highland Plateau should be LOCKED")
	print("✓ Test 4 Passed: 16x16 Homestead tiles unlocked, other 3 parcels locked")

	# 5. Check starter buildings
	var kubo = BuildingManager.get_building_at_tile(Vector2i(0, 0))
	assert(kubo != null and kubo.building_type == "bahay_kubo", "FAIL: Bahay Kubo missing at (0, 0)")
	var bodega = BuildingManager.get_building_at_tile(Vector2i(2, 0))
	assert(bodega != null and bodega.building_type == "bodega", "FAIL: Bodega missing at (2, 0)")
	print("✓ Test 5 Passed: Starter buildings intact at apex (0, 0) and (2, 0)")

	# 6. Check SeaWater constants
	assert(SeaWater.COAST_X == 32.0, "FAIL: SeaWater.COAST_X should be 32.0, got: %f" % SeaWater.COAST_X)
	assert(SeaWater.GRID_HEIGHT == 32.0, "FAIL: SeaWater.GRID_HEIGHT should be 32.0, got: %f" % SeaWater.GRID_HEIGHT)
	print("✓ Test 6 Passed: SeaWater COAST_X and GRID_HEIGHT updated to 32.0")

	# 7. Check GameCamera bounds and zoom
	var cam: GameCamera = game.find_child("GameCamera", true, false)
	assert(cam != null, "FAIL: GameCamera not found")
	assert(cam.world_bounds_min.x <= -1280, "FAIL: world_bounds_min.x should cover 32x32 island")
	assert(cam.world_bounds_max.x >= 3200, "FAIL: world_bounds_max.x should cover 32x32 island and ocean")
	assert(cam.min_zoom <= 0.50, "FAIL: min_zoom should allow overview of 32x32 island")
	print("✓ Test 7 Passed: GameCamera bounds and min_zoom properly calibrated for 32x32")

	# 8. Test land purchase
	EconomyManager.add_cash(10000)
	var unlock_res: bool = farm.unlock_parcel("east_meadows")
	assert(unlock_res == true, "FAIL: unlock_parcel('east_meadows') failed")
	assert(farm.unlocked_parcels.has("east_meadows"), "FAIL: east_meadows not in unlocked_parcels")
	assert(farm.tiles[16][0].state == FarmTile.TileState.EMPTY, "FAIL: (16, 0) should be EMPTY after unlock")
	assert(farm.tiles[31][15].state == FarmTile.TileState.EMPTY, "FAIL: (31, 15) should be EMPTY after unlock")
	print("✓ Test 8 Passed: East Meadows successfully purchased and unlocked to (31, 15)")

	# 9. Capture screenshot of the expanded farm
	cam.zoom = Vector2(0.55, 0.55)
	cam.position = Vector2(768, 1088) # Center of the 32x32 island
	await get_tree().process_frame
	await get_tree().process_frame

	var img = get_viewport().get_texture().get_image()
	if img:
		var shot_path = "c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_expanded_farm_32x32.png"
		img.save_png(shot_path)
		print("Saved screenshot to: ", shot_path)

	# 10. Open Agri-Shop Land tab and capture screenshot
	var shop = game.find_child("ShopPanel", true, false)
	if shop:
		shop.open_to_tab("Land")
		await get_tree().process_frame
		await get_tree().process_frame
		var img_shop = get_viewport().get_texture().get_image()
		if img_shop:
			var shop_shot_path = "c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_expanded_land_shop.png"
			img_shop.save_png(shop_shot_path)
			print("Saved shop screenshot to: ", shop_shot_path)

	print("--- ALL 10 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
