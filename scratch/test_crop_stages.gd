@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING CROP STAGES LOGIC ---")
	
	var renderer = TileRenderer.new()
	
	# Test all crops texture resolution
	var crops = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	for c in crops:
		var max_s = 6 if c == "banana" else 5
		for s in range(1, max_s + 1):
			var tex = renderer.get_crop_stage_texture(c, s)
			if not tex:
				print("FAIL: get_crop_stage_texture returned null for %s stage %d" % [c, s])
				quit(1)
				return
		
		# Test representative/mature icon (get_crop_sprite_texture)
		var mature_tex = renderer.get_crop_sprite_texture(c)
		if not mature_tex:
			print("FAIL: get_crop_sprite_texture returned null for %s" % c)
			quit(1)
			return
		print("OK: %s textures verified (mature: %s)" % [c, mature_tex.resource_path])

	# Test stage selection logic for Palay
	var tile_palay = FarmTile.new()
	tile_palay.crop_type = "palay"
	
	tile_palay.state = FarmTile.TileState.PLANTED
	tile_palay.growth_progress = 0.0
	assert(renderer.get_tile_crop_stage(tile_palay) == 1, "Palay planted should be stage 1")
	
	tile_palay.state = FarmTile.TileState.GROWING
	tile_palay.growth_progress = 0.5
	assert(renderer.get_tile_crop_stage(tile_palay) == 2, "Palay growing should be stage 2")
	
	tile_palay.state = FarmTile.TileState.HARVESTABLE
	tile_palay.growth_progress = 1.0
	assert(renderer.get_tile_crop_stage(tile_palay) == 3, "Palay harvestable should be stage 3")
	
	tile_palay.pest_type = "kuhol"
	tile_palay.health = 0.7
	assert(renderer.get_tile_crop_stage(tile_palay) == 4, "Palay with pest/withering should be stage 4")
	
	tile_palay.health = 0.1
	assert(renderer.get_tile_crop_stage(tile_palay) == 5, "Palay dead/dying should be stage 5")
	
	tile_palay.state = FarmTile.TileState.FLOODED
	assert(renderer.get_tile_crop_stage(tile_palay) == 5, "Palay flooded should be stage 5")

	# Test Banana (1-4 growth, 5-6 withering)
	var tile_banana = FarmTile.new()
	tile_banana.crop_type = "banana"
	
	tile_banana.state = FarmTile.TileState.PLANTED
	tile_banana.growth_progress = 0.0
	assert(renderer.get_tile_crop_stage(tile_banana) == 1, "Banana planted should be stage 1")
	
	tile_banana.state = FarmTile.TileState.GROWING
	tile_banana.growth_progress = 0.35
	assert(renderer.get_tile_crop_stage(tile_banana) == 2, "Banana young should be stage 2")
	
	tile_banana.growth_progress = 0.75
	assert(renderer.get_tile_crop_stage(tile_banana) == 3, "Banana maturing should be stage 3")
	
	tile_banana.state = FarmTile.TileState.HARVESTABLE
	tile_banana.growth_progress = 1.0
	assert(renderer.get_tile_crop_stage(tile_banana) == 4, "Banana ripe should be stage 4")
	
	tile_banana.pest_type = "fusarium_wilt"
	tile_banana.health = 0.6
	assert(renderer.get_tile_crop_stage(tile_banana) == 5, "Banana pest/withering should be stage 5")
	
	tile_banana.health = 0.1
	assert(renderer.get_tile_crop_stage(tile_banana) == 6, "Banana dead should be stage 6")
	
	tile_banana.state = FarmTile.TileState.FLOODED
	assert(renderer.get_tile_crop_stage(tile_banana) == 6, "Banana flooded should be stage 6")

	print("ALL CROP STAGE LOGIC TESTS PASSED SUCCESSFULLY!")
	quit(0)
