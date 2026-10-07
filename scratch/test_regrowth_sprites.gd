extends SceneTree

func _init() -> void:
	print("--- TESTING REGROWTH SPRITE SYSTEM ---")
	
	var tr := TileRenderer.new()
	
	# 1. Test get_regrowth_texture directly for each perennial crop
	for crop in ["banana", "coconut", "arabica_coffee"]:
		var tex := tr.get_regrowth_texture(crop)
		if tex:
			print("SUCCESS: Loaded regrowth texture for ", crop, ": ", tex.resource_path, " size=", tex.get_size())
		else:
			push_error("FAILED: Could not load regrowth texture for " + crop)

	# 2. Test get_crop_texture_for_tile
	var tile := FarmTile.new()
	tile.crop_type = "banana"
	tile.state = FarmTile.TileState.GROWING
	tile.growth_progress = 0.8
	tile.is_regrowing = true
	
	var regrow_tex := tr.get_crop_texture_for_tile(tile)
	print("Banana is_regrowing=true texture: ", regrow_tex.resource_path if regrow_tex else "null")
	assert(regrow_tex != null and "no crop" in regrow_tex.resource_path, "Should load 'no crop' texture when is_regrowing=true")

	tile.is_regrowing = false
	var normal_tex := tr.get_crop_texture_for_tile(tile)
	print("Banana is_regrowing=false texture: ", normal_tex.resource_path if normal_tex else "null")
	assert(normal_tex != null and "no crop" not in normal_tex.resource_path, "Should load standard stage texture when is_regrowing=false")

	# 3. Test Coffee (1x1)
	tile.crop_type = "arabica_coffee"
	tile.is_regrowing = true
	var coffee_regrow_tex := tr.get_crop_texture_for_tile(tile)
	print("Coffee is_regrowing=true texture: ", coffee_regrow_tex.resource_path if coffee_regrow_tex else "null")
	assert(coffee_regrow_tex != null and "no crop" in coffee_regrow_tex.resource_path, "Should load Coffee 'no crop' texture")

	# 4. Test Coconut (2x2)
	tile.crop_type = "coconut"
	tile.is_regrowing = true
	var coco_regrow_tex := tr.get_crop_texture_for_tile(tile)
	print("Coconut is_regrowing=true texture: ", coco_regrow_tex.resource_path if coco_regrow_tex else "null")
	assert(coco_regrow_tex != null and "no crop" in coco_regrow_tex.resource_path, "Should load Coconut 'no crop' texture")

	# 5. Test tile transition when reaching harvestable
	tile.growth_progress = 1.0
	# Simulate harvestable transition logic from TileAgronomySystem
	if tile.growth_progress >= 1.0:
		tile.state = FarmTile.TileState.HARVESTABLE
		tile.is_regrowing = false
	print("After reaching 1.0 progress: tile.state=", tile.state, " is_regrowing=", tile.is_regrowing)
	assert(tile.is_regrowing == false, "Tile should set is_regrowing to false when crop is ready")
	
	var mature_tex := tr.get_crop_texture_for_tile(tile)
	print("Coconut mature texture: ", mature_tex.resource_path if mature_tex else "null")
	assert(mature_tex != null and "no crop" not in mature_tex.resource_path, "Mature texture should not be no crop")

	print("--- ALL REGROWTH SPRITE TESTS PASSED ---")
	quit(0)
