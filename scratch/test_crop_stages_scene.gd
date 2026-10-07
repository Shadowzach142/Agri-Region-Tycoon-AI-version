extends SceneTree

func _init() -> void:
	print("--- BEGIN TEST: IN-GAME CROP STAGE RENDERING ON FARMGRID ---")

	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	if not main_scene:
		printerr("FAIL: Could not load MainGame.tscn")
		quit(1)
		return

	var root_node = main_scene.instantiate()
	root.add_child(root_node)

	await process_frame
	await process_frame

	var farm_grid = root_node.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must exist")

	var plant_hotbar = root_node.find_child("PlantHotbar", true, false)
	assert(plant_hotbar != null, "PlantHotbar must exist")

	# Verify hotbar icons
	for crop_id in PlantHotbar.CROP_KEYS:
		var slot_btn = plant_hotbar.slot_buttons.get(crop_id)
		assert(slot_btn != null, "Slot button for %s must exist" % crop_id)
		var spr_rect = slot_btn.find_child("SpriteRect", true, false) as TextureRect
		assert(spr_rect != null, "SpriteRect for %s must exist" % crop_id)
		assert(spr_rect.texture != null, "Texture for %s slot must not be null" % crop_id)
		print("  ✔ Hotbar slot icon for %s: %s" % [crop_id, spr_rect.texture.resource_path.get_file()])

	# Test each crop's stages on the farm grid
	var crops = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	
	for i in range(crops.size()):
		var crop_id = crops[i]
		var pos = Vector2i(i, 0)
		var tile = farm_grid.tiles[pos.x][pos.y]
		var overlay = farm_grid.tile_overlays[pos.x][pos.y]
		var spr_name = "CropSprite2x2" if tile.is_multi_tile_root else "CropSprite"
		
		# 1. Planted (Stage 1)
		tile.state = FarmTile.TileState.PLANTED
		tile.crop_type = crop_id
		tile.growth_progress = 0.0
		tile.health = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		var stage = farm_grid.renderer.get_tile_crop_stage(tile)
		assert(stage == 1, "%s stage 1 failed: got %d" % [crop_id, stage])
		var spr = overlay.find_child(spr_name, false, false) as Sprite2D
		assert(spr != null and spr.texture != null, "Missing sprite for %s stage 1" % crop_id)
		print("  ✔ %s PLANTED (Stage 1): %s" % [crop_id, spr.texture.resource_path.get_file()])
		
		# 2. Growing (Stage 2)
		tile.state = FarmTile.TileState.GROWING
		tile.growth_progress = 0.45
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		assert(stage == 2, "%s stage 2 failed: got %d" % [crop_id, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s GROWING (Stage 2): %s" % [crop_id, spr.texture.resource_path.get_file()])
		
		# 3. Banana stage 3 (flowering/maturing)
		if crop_id == "banana":
			tile.growth_progress = 0.80
			farm_grid.renderer.update_tile(pos, farm_grid.tiles)
			stage = farm_grid.renderer.get_tile_crop_stage(tile)
			assert(stage == 3, "Banana stage 3 failed: got %d" % stage)
			spr = overlay.find_child(spr_name, false, false) as Sprite2D
			print("  ✔ banana MATURING (Stage 3): %s" % spr.texture.resource_path.get_file())
			
		# 4. Harvestable (Stage 3 for crops, Stage 4 for banana)
		tile.state = FarmTile.TileState.HARVESTABLE
		tile.growth_progress = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_mature = 4 if crop_id == "banana" else 3
		assert(stage == expected_mature, "%s mature failed: expected %d, got %d" % [crop_id, expected_mature, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s HARVESTABLE (Stage %d): %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# 5. Withering (pest infestation -> Stage 4 for crops, Stage 5 for banana)
		tile.pest_type = "kuhol"
		tile.health = 0.65
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_withering = 5 if crop_id == "banana" else 4
		assert(stage == expected_withering, "%s withering failed: expected %d, got %d" % [crop_id, expected_withering, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s WITHERING (Stage %d): %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# 6. Dead / Flooded (Stage 5 for crops, Stage 6 for banana)
		tile.state = FarmTile.TileState.FLOODED
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_dead = 6 if crop_id == "banana" else 5
		assert(stage == expected_dead, "%s dead failed: expected %d, got %d" % [crop_id, expected_dead, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s FLOODED/DEAD (Stage %d): %s" % [crop_id, stage, spr.texture.resource_path.get_file()])

	print("--- ALL IN-GAME CROP STAGE TESTS PASSED FLAWLESSLY! ---")
	root_node.queue_free()
	quit(0)
