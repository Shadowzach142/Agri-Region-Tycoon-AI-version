extends Node

func _ready():
	print("--- BEGIN AUTOMATED TEST: CROP OVERLAY OCCLUSION & FARMER VISIBILITY ---")
	var main_scene = load("res://scenes/MainGame.tscn")
	var main_game = main_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame

	var farm_grid = main_game.find_child("FarmGrid", true, false)
	var farmer = main_game.find_child("Farmer", true, false)

	# 1. Verify Z-Index layer hierarchy
	print("[Check 1] Farmer Z-index: ", farmer.z_index)
	assert(farmer.z_index == 12, "Farmer z_index must be 12 (above crops Z=10)")
	
	var label = farmer.find_child("FarmerLabel", true, false) as Label
	if label:
		print("[Check 1b] FarmerLabel Z-index: ", label.z_index)
		assert(label.z_index == 15, "FarmerLabel z_index must be 15")
	
	var kubo = farm_grid.find_child("Building_kubo*", true, false)
	if kubo:
		print("[Check 1c] Bahay Kubo Z-index: ", kubo.z_index)
		assert(kubo.z_index == 14, "Building z_index must be 14 (above workers Z=12)")

	# 2. Plant mature crop at (5, 5) and south tiles (5, 6), (6, 5), (6, 6)
	var test_tiles = [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)]
	for pos in test_tiles:
		var t: FarmTile = farm_grid.tiles[pos.x][pos.y]
		t.state = FarmTile.TileState.HARVESTABLE
		t.crop_type = "palay"
		t.growth_progress = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)

	# Position farmer at tile (5, 5)
	farmer.position = FarmerMovement.grid_to_pixel_center(Vector2i(5, 5), farm_grid)

	# Run several process frames to let occlusion update & lerp alpha
	for i in range(10):
		await get_tree().process_frame

	print("[Check 2] Occluded tiles when farmer is at (5, 5): ", farm_grid._occluded_tiles.keys())
	assert(farm_grid._occluded_tiles.has(Vector2i(5, 5)), "Tile (5, 5) must be detected as occluding farmer")
	assert(farm_grid._occluded_tiles.has(Vector2i(5, 6)) or farm_grid._occluded_tiles.has(Vector2i(6, 6)), "South tile must be detected as occluding farmer")

	var ov_55 = farm_grid.tile_overlays[5][5]
	print("[Check 2b] Tile (5, 5) overlay alpha: ", ov_55.modulate.a)
	assert(ov_55.modulate.a < 0.60, "Overlay on tile (5, 5) must fade to translucent alpha (got %f)" % ov_55.modulate.a)

	# 3. Move farmer away to (1, 1) (distant tile)
	farmer.position = FarmerMovement.grid_to_pixel_center(Vector2i(1, 1), farm_grid)

	# Run process frames to allow restored tiles to lerp back to 1.0
	for i in range(25):
		await get_tree().process_frame

	print("[Check 3] Tile (5, 5) overlay alpha after farmer leaves: ", ov_55.modulate.a)
	assert(ov_55.modulate.a > 0.90, "Overlay on tile (5, 5) must restore back to opaque alpha (got %f)" % ov_55.modulate.a)
	assert(not farm_grid._occluded_tiles.has(Vector2i(5, 5)), "Tile (5, 5) must no longer be in _occluded_tiles")

	# 4. Test 2x2 multi-tile tree grove (Coconut at 7, 7)
	var coco_root := Vector2i(7, 7)
	for dx in range(2):
		for dy in range(2):
			var sub_p := coco_root + Vector2i(dx, dy)
			var sub_t: FarmTile = farm_grid.tiles[sub_p.x][sub_p.y]
			sub_t.state = FarmTile.TileState.HARVESTABLE
			sub_t.crop_type = "coconut"
			sub_t.growth_progress = 1.0
			sub_t.is_multi_tile_root = (dx == 0 and dy == 0)
			sub_t.multi_tile_root_pos = coco_root
			farm_grid.renderer.update_tile(sub_p, farm_grid.tiles)

	# Move farmer behind the coconut tree (at 7, 7)
	farmer.position = FarmerMovement.grid_to_pixel_center(coco_root, farm_grid)

	for i in range(10):
		await get_tree().process_frame

	print("[Check 4] Occlusion on 2x2 Coconut grove: ", farm_grid._occluded_tiles.has(coco_root))
	assert(farm_grid._occluded_tiles.has(coco_root), "2x2 Coconut grove root must be occluded")
	var coco_ov = farm_grid.tile_overlays[coco_root.x][coco_root.y]
	print("[Check 4b] Coconut grove overlay alpha: ", coco_ov.modulate.a)
	assert(coco_ov.modulate.a < 0.60, "Coconut canopy must fade to translucent alpha (got %f)" % coco_ov.modulate.a)

	print("========================================")
	print("ALL CROP OCCLUSION & FARMER TESTS PASSED!")
	print("========================================")
	get_tree().quit(0)
