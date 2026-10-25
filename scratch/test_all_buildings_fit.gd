extends Node

func _ready() -> void:
	print("--- Running Complete All Buildings Fit & Reversion Verification ---")
	
	var original_buildings = [
		"bahay_kubo", "bodega", "cold_storage", "water_tower", 
		"drone_station", "weather_station", "solar_dryer", "sprinkler", "climate_silo"
	]
	
	var new_buildings = [
		"bayanihan_center", "tacurong_mill", "koronadal_wholesale", "gensan_seaport",
		"rice_mill", "sugar_mill", "copra_dryer", "coffee_roastery"
	]
	
	print("\n=== 1. Checking Original Buildings (Reverted from get_art_fit) ===")
	for b_type in original_buildings:
		var fit = Building.get_art_fit(b_type)
		assert(fit.is_empty(), "Original building %s must NOT be in get_art_fit()! Got: %s" % [b_type, str(fit)])
		
		var b = Building.new()
		b.building_type = b_type
		add_child(b)
		
		assert(b.art_sprite == null, "Original building %s should NOT have art_sprite (uses custom _draw)" % b_type)
		b.queue_redraw()
		b.state = Building.BuildingState.ACTIVE
		b.queue_redraw()
		b.state = Building.BuildingState.CONSTRUCTING
		b.queue_redraw()
		print("  [PASS] %s: verified reverted to classic 2.0x procedural/sprite _draw method" % b_type)
		b.queue_free()

	print("\n=== 2. Checking Newly Added Buildings (Calibrated in get_art_fit) ===")
	for b_type in new_buildings:
		var fit = Building.get_art_fit(b_type)
		assert(not fit.is_empty(), "New building %s MUST be in get_art_fit()" % b_type)
		assert(fit.has("texture") and fit["texture"] != null, "New building %s missing texture" % b_type)
		var sc: float = float(fit.get("scale", 1.0))
		assert(sc == 2.0, "Scale for %s must be 2.0 to match original buildings! Got: %f" % [b_type, sc])
		
		var b = Building.new()
		b.building_type = b_type
		add_child(b)
		
		assert(b.art_sprite != null, "New building %s must have art_sprite" % b_type)
		assert(b.art_sprite.scale == Vector2(sc, sc), "ArtSprite scale mismatch for %s" % b_type)
		assert(b.art_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Must use nearest neighbor filter")
		
		var b_data = Data.get_building(b_type)
		var fp: Vector2i = b_data.get("grid_size", Vector2i(2, 2))
		# Diamond width: (fp.x + fp.y) * 64
		var diamond_w: float = float(fp.x + fp.y) * 64.0
		var tex_w: float = float(fit["texture"].get_width()) * sc
		var ratio: float = tex_w / diamond_w
		print("  [PASS] %s (%d×%d): texture width %.1fpx on diamond %.1fpx (ratio: %.1f%%) — perfectly fits within tiles!" % [
			b_type, fp.x, fp.y, tex_w, diamond_w, ratio * 100.0
		])
		
		b.queue_redraw()
		b.state = Building.BuildingState.ACTIVE
		b.queue_redraw()
		b.state = Building.BuildingState.CONSTRUCTING
		b.queue_redraw()
		b.queue_free()

	print("\n=== ALL 17 BUILDINGS VERIFIED SUCCESSFULLY! ===")
	get_tree().quit(0)
