extends SceneTree

func _init() -> void:
	print("--- TESTING GROUND TILE SPRITES ---")
	var gts := GroundTileSprites.new()
	print("normal_grass_variants: ", gts.normal_grass_variants.size())
	print("wet_grass_variants: ", gts.wet_grass_variants.size())
	print("bare_soil_variants: ", gts.bare_soil_variants.size())
	print("drought_soil_variants: ", gts.drought_soil_variants.size())
	print("walk_soil_variants: ", gts.walk_soil_variants.size())

	assert(gts.normal_grass_variants.size() == 5, "Normal grass should have 5 variants")
	assert(gts.wet_grass_variants.size() == 5, "Wet grass should have 5 variants")
	assert(gts.bare_soil_variants.size() == 5, "Bare soil should have 5 variants")
	assert(gts.drought_soil_variants.size() == 5, "Drought soil should have 5 variants")
	assert(gts.walk_soil_variants.size() == 5, "Walk soil should have 5 variants")

	print("--- ALL GROUND TILE SPRITES LOADED SUCCESSFULLY ---")
	quit(0)
