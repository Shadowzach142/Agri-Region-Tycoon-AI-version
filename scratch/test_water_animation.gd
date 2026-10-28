extends SceneTree

func _init() -> void:
	print("=================================================================")
	print("--- TEST SUITE: ANIMATED WATER SPRITES (SEA & FLOODED PLOTS) ---")
	print("=================================================================")
	
	# TEST 1: SeaWater component & textures
	var sea := SeaWater.new()
	assert(sea._water_light_textures.size() == 8, "Expected 8 light water frames, got %d" % sea._water_light_textures.size())
	assert(sea._water_dark_textures.size() == 8, "Expected 8 dark water frames, got %d" % sea._water_dark_textures.size())
	assert(sea._water_calm_textures.size() == 5, "Expected 5 calm water frames, got %d" % sea._water_calm_textures.size())
	print("✓ Test 1 Passed: SeaWater loaded all 21 water textures successfully.")

	# TEST 2: SeaWater geometry & constants
	sea._rebuild_geometry()
	assert(sea.COAST_X == 32.0, "SeaWater.COAST_X must be 32.0")
	assert(sea.GRID_HEIGHT == 32.0, "SeaWater.GRID_HEIGHT must be 32.0")
	assert(sea._ocean_polygon.size() == 4, "Ocean polygon must have 4 vertices")
	assert(sea._coast_line.size() == 33, "Coast line must have 33 vertices (0..32)")
	print("✓ Test 2 Passed: SeaWater geometry and regression constants verified.")

	# TEST 3: GroundTileSprites flood_water_variants
	var gts := GroundTileSprites.new()
	assert(gts.flood_water_variants.size() == 5, "Expected 5 flood water variants, got %d" % gts.flood_water_variants.size())
	print("✓ Test 3 Passed: GroundTileSprites loaded 5 flood water variants.")

	# TEST 4: GroundTileSprites get_texture for FLOODED tile
	var flooded_tile := FarmTile.new()
	flooded_tile.state = FarmTile.TileState.FLOODED
	var tex_flood: Texture2D = gts.get_texture(flooded_tile, Vector2i(5, 5))
	assert(tex_flood != null, "Flooded tile must receive a non-null water texture")
	assert("water" in tex_flood.resource_path.to_lower(), "Flooded texture must be from water sprites: " + tex_flood.resource_path)
	print("✓ Test 4 Passed: GroundTileSprites returns animated water sprite for FLOODED tile: %s" % tex_flood.resource_path)

	# TEST 5: Beach tile detection on 32x32 grid
	assert(GroundTileSprites.is_beach_tile(Vector2i(31, 10)) == true, "x=31 must be beach tile")
	assert(GroundTileSprites.is_beach_tile(Vector2i(30, 10)) == true, "x=30 must be beach tile")
	assert(GroundTileSprites.is_beach_tile(Vector2i(23, 10)) == false, "x=23 must NOT be beach tile on 32x32 grid")
	assert(GroundTileSprites.is_beach_tile(Vector2i(22, 10)) == false, "x=22 must NOT be beach tile on 32x32 grid")
	print("✓ Test 5 Passed: is_beach_tile correctly identifies eastern coastal beach tiles (x=31, 30) and rejects inland tiles (x=22, 23).")

	# TEST 6: TileRenderer flood tracking and process_animations
	var renderer := TileRenderer.new()
	renderer.ground_sprites = gts
	var fake_fills: Array = []
	var fake_overlays: Array = []
	var fake_dots: Array = []
	var fake_labels: Array = []
	var fake_sprites: Array = []
	
	fake_fills.resize(4); fake_overlays.resize(4); fake_dots.resize(4); fake_labels.resize(4); fake_sprites.resize(4)
	for x in range(4):
		fake_fills[x] = []; fake_overlays[x] = []; fake_dots[x] = []; fake_labels[x] = []; fake_sprites[x] = []
		for y in range(4):
			fake_fills[x].append(Polygon2D.new())
			fake_overlays[x].append(Node2D.new())
			fake_dots[x].append(ColorRect.new())
			fake_labels[x].append(Label.new())
			var sp := Sprite2D.new()
			sp.visible = true
			fake_sprites[x].append(sp)

	renderer.setup(fake_fills, fake_overlays, fake_dots, fake_labels, fake_sprites)

	var test_tiles: Array = []
	test_tiles.resize(4)
	for x in range(4):
		test_tiles[x] = []
		for y in range(4):
			var t := FarmTile.new()
			t.state = FarmTile.TileState.EMPTY
			test_tiles[x].append(t)

	# Mark tile (2, 2) as FLOODED
	test_tiles[2][2].state = FarmTile.TileState.FLOODED
	renderer.update_tile(Vector2i(2, 2), test_tiles)
	assert(renderer._flooded_tiles.has(Vector2i(2, 2)), "_flooded_tiles must register flooded tile (2, 2)")
	assert(renderer._flooded_tiles.size() == 1, "_flooded_tiles size must be 1")

	# Test animation tick
	var initial_frame = renderer._flood_anim_frame
	renderer.process_animations(0.50) # 0.50s > 0.45s threshold
	assert(renderer._flood_anim_frame != initial_frame, "Animation frame must advance after delta threshold")
	print("✓ Test 6 Passed: TileRenderer dynamically tracks and animates flooded tiles at gentle ~2.2 FPS.")

	# Mark tile (2, 2) plowed / recovered
	test_tiles[2][2].state = FarmTile.TileState.PLOWED
	renderer.update_tile(Vector2i(2, 2), test_tiles)
	assert(not renderer._flooded_tiles.has(Vector2i(2, 2)), "_flooded_tiles must unregister tile when unflooded")
	assert(renderer._flooded_tiles.is_empty(), "_flooded_tiles must be empty after recovery")
	print("✓ Test 7 Passed: TileRenderer unregisters tiles upon drainage/recovery.")

	sea.free()
	# renderer is RefCounted, auto-freed
	print("=================================================================")
	print("✓ ALL 7 WATER SPRITE & ANIMATION TESTS PASSED SUCCESSFULLY!")
	print("=================================================================")
	quit(0)
