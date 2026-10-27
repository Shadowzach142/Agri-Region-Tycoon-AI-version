extends Node

func _ready() -> void:
	print("--- Comprehensive Building vs Crop Depth Sorting & Dryer 3x3 Test ---")
	
	# Instantiate FarmGrid
	var farm_grid_script = load("res://src/core/FarmGrid.gd")
	var farm_grid = Node2D.new()
	farm_grid.set_script(farm_grid_script)
	add_child(farm_grid)
	
	# 1. Verify solar_dryer and copra_dryer footprints in Data.gd
	var solar_data = Data.get_building("solar_dryer")
	assert(solar_data.get("grid_size") == Vector2i(3, 3), "solar_dryer must be 3x3!")
	var copra_data = Data.get_building("copra_dryer")
	assert(copra_data.get("grid_size") == Vector2i(3, 3), "copra_dryer must be 3x3!")
	print("[PASS] solar_dryer and copra_dryer are both 3x3 in Data.gd")
	
	# 2. Test depth sorting with Bahay Kubo (2x2) at (4, 4)
	farm_grid._spawn_starter_building(Vector2i(4, 4), "bahay_kubo")
	var kubo = BuildingManager.get_building_at_tile(Vector2i(4, 4))
	assert(kubo != null)
	assert(kubo.z_index == 10, "Kubo z_index must be 10!")
	
	var kubo_behind = farm_grid.tile_roots[3][4]
	var kubo_front = farm_grid.tile_roots[6][4]
	assert(kubo_behind.position.y < kubo.position.y, "Tile behind must sort BEFORE Kubo in Y")
	assert(kubo_front.position.y > kubo.position.y, "Tile in front must sort AFTER Kubo in Y")
	assert(kubo_behind.z_index == 10 and kubo_front.z_index == 10, "Tile roots must have z_index 10")
	print("[PASS] Kubo (2x2): Behind Y (%.1f) < Kubo Y (%.1f) < Front Y (%.1f) [All Z=10]" % [
		kubo_behind.position.y, kubo.position.y, kubo_front.position.y
	])
	
	# 3. Test depth sorting with Solar Dryer (3x3) at (8, 4)
	farm_grid._spawn_starter_building(Vector2i(8, 4), "solar_dryer")
	var solar = BuildingManager.get_building_at_tile(Vector2i(8, 4))
	assert(solar != null)
	assert(solar.footprint == Vector2i(3, 3), "Solar dryer footprint must be 3x3")
	assert(solar.z_index == 10, "Solar dryer z_index must be 10")
	
	var solar_behind = farm_grid.tile_roots[7][4]
	var solar_front = farm_grid.tile_roots[11][4]
	assert(solar_behind.position.y < solar.position.y, "Tile behind must sort BEFORE solar dryer in Y")
	assert(solar_front.position.y > solar.position.y, "Tile in front must sort AFTER solar dryer in Y")
	print("[PASS] Solar Dryer (3x3): Behind Y (%.1f) < Solar Y (%.1f) < Front Y (%.1f) [All Z=10]" % [
		solar_behind.position.y, solar.position.y, solar_front.position.y
	])
	
	# 4. Test depth sorting with Copra Dryer (3x3) at (14, 4)
	farm_grid._spawn_starter_building(Vector2i(14, 4), "copra_dryer")
	var copra = BuildingManager.get_building_at_tile(Vector2i(14, 4))
	assert(copra != null)
	assert(copra.footprint == Vector2i(3, 3), "Copra dryer footprint must be 3x3")
	assert(copra.z_index == 10, "Copra dryer z_index must be 10")
	var copra_fit = Building.get_art_fit("copra_dryer")
	assert(copra_fit.get("scale") == 2.0, "Copra dryer sprite scale must be 2.0x (not enlarged)!")
	
	var copra_behind = farm_grid.tile_roots[13][4]
	var copra_front = farm_grid.tile_roots[17][4]
	assert(copra_behind.position.y < copra.position.y, "Tile behind must sort BEFORE copra dryer in Y")
	assert(copra_front.position.y > copra.position.y, "Tile in front must sort AFTER copra dryer in Y")
	print("[PASS] Copra Dryer (3x3, 2.0x scale): Behind Y (%.1f) < Copra Y (%.1f) < Front Y (%.1f) [All Z=10]" % [
		copra_behind.position.y, copra.position.y, copra_front.position.y
	])
	
	# 5. Plant crops on front tiles to ensure sprites render on Overlay
	var test_crops = [
		{"pos": Vector2i(6, 4), "crop": "palay"},
		{"pos": Vector2i(11, 4), "crop": "sugarcane"},
		{"pos": Vector2i(17, 4), "crop": "yellow_corn"}
	]
	for tc in test_crops:
		var p: Vector2i = tc["pos"]
		var c_name: String = tc["crop"]
		farm_grid.tiles[p.x][p.y].crop_type = c_name
		farm_grid.tiles[p.x][p.y].state = FarmTile.TileState.HARVESTABLE
		farm_grid.tiles[p.x][p.y].growth_progress = 1.0
		farm_grid.renderer.update_tile(p, farm_grid.tiles)
		assert(farm_grid.tile_overlays[p.x][p.y].get_child_count() > 0, "Crop overlay must have child sprite")
		print("  [PASS] Mature %s planted on front tile (%d, %d) with overlay sprite ready" % [c_name, p.x, p.y])
	
	print("\n=== ALL DEPTH SORTING & DRYER 3X3 TESTS PASSED PERFECTLY! ===")
	get_tree().quit(0)
