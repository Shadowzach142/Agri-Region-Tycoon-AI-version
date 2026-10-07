@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING IN-GAME CROP STAGE RENDERING ON FARMGRID ---")
	var root = Node2D.new()
	
	var farm_grid = load("res://src/core/FarmGrid.gd").new()
	root.add_child(farm_grid)
	
	var crops = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	
	for i in range(crops.size()):
		var crop_id = crops[i]
		var pos = Vector2i(i, 0)
		var tile = farm_grid.tiles[pos.x][pos.y]
		
		# 1. Plow and plant
		tile.state = FarmTile.TileState.PLANTED
		tile.crop_type = crop_id
		tile.growth_progress = 0.0
		tile.health = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		
		var stage = farm_grid.renderer.get_tile_crop_stage(tile)
		assert(stage == 1, "%s stage 1 failed: got %d" % [crop_id, stage])
		var overlay = farm_grid.tile_overlays[pos.x][pos.y]
		var spr_name = "CropSprite2x2" if tile.is_multi_tile_root else "CropSprite"
		var spr = overlay.find_child(spr_name, false, false) as Sprite2D
		assert(spr != null, "Crop sprite missing in overlay for %s planted" % crop_id)
		assert(spr.texture != null, "Crop sprite texture missing for %s planted" % crop_id)
		print("  ✔ %s PLANTED: stage %d -> %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# 2. Growing
		tile.state = FarmTile.TileState.GROWING
		tile.growth_progress = 0.5
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		assert(stage == 2, "%s stage 2 failed: got %d" % [crop_id, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		assert(spr != null and spr.texture != null)
		print("  ✔ %s GROWING: stage %d -> %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# For banana: test stage 3 (large flowering plant)
		if crop_id == "banana":
			tile.growth_progress = 0.8
			farm_grid.renderer.update_tile(pos, farm_grid.tiles)
			stage = farm_grid.renderer.get_tile_crop_stage(tile)
			assert(stage == 3, "Banana stage 3 failed: got %d" % stage)
			spr = overlay.find_child(spr_name, false, false) as Sprite2D
			print("  ✔ banana FLOWERING: stage 3 -> %s" % spr.texture.resource_path.get_file())
			
		# 3. Harvestable
		tile.state = FarmTile.TileState.HARVESTABLE
		tile.growth_progress = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_mature = 4 if crop_id == "banana" else 3
		assert(stage == expected_mature, "%s mature stage failed: expected %d, got %d" % [crop_id, expected_mature, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s HARVESTABLE: stage %d -> %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# 4. Withering (pest / stress)
		tile.pest_type = "kuhol"
		tile.health = 0.7
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_withering = 5 if crop_id == "banana" else 4
		assert(stage == expected_withering, "%s withering stage failed: expected %d, got %d" % [crop_id, expected_withering, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s WITHERING (pest): stage %d -> %s" % [crop_id, stage, spr.texture.resource_path.get_file()])
		
		# 5. Terminal decay (flooded)
		tile.state = FarmTile.TileState.FLOODED
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		stage = farm_grid.renderer.get_tile_crop_stage(tile)
		var expected_dead = 6 if crop_id == "banana" else 5
		assert(stage == expected_dead, "%s dead stage failed: expected %d, got %d" % [crop_id, expected_dead, stage])
		spr = overlay.find_child(spr_name, false, false) as Sprite2D
		print("  ✔ %s FLOODED (terminal): stage %d -> %s" % [crop_id, stage, spr.texture.resource_path.get_file()])

	print("--- ALL 7 CROPS FULL STAGE LIFECYCLE TESTS PASSED! ---")
	root.queue_free()
	quit(0)
