extends Node2D

func _ready() -> void:
	print("\n==================================================")
	print("STARTING COMPREHENSIVE BUILDING SIZE & TILE GRID AUDIT")
	print("==================================================")

	# 1. Height & Grid Comparison against Bahay Kubo
	var kubo_data := Data.get_building("bahay_kubo")
	var kubo_fp: Vector2i = kubo_data.get("grid_size", Vector2i(2, 2))
	var kubo_tex: Texture2D = preload("res://assets/sprites/buildings/KUBO.png")
	var kubo_h: float = float(kubo_tex.get_height()) * 2.0 # 192px
	var kubo_apex: float = -156.0

	print("REFERENCE: Bahay Kubo | Footprint: %s | Height: %.1fpx | Apex: %.1fpx" % [
		kubo_fp, kubo_h, kubo_apex
	])

	var factories = [
		"rice_mill",
		"sugar_mill",
		"copra_dryer",
		"coffee_roastery",
		"tacurong_mill"
	]

	for f_id in factories:
		var b_data := Data.get_building(f_id)
		var fp: Vector2i = b_data.get("grid_size")
		var fit := Building.get_art_fit(f_id)
		assert(not fit.is_empty(), "Building %s must have art fit" % f_id)
		
		var sc: float = float(fit.get("scale", 1.0))
		var tex: Texture2D = fit["texture"]
		var h: float = float(tex.get_height()) * sc
		var w: float = float(tex.get_width()) * sc
		var coff: Vector2 = fit.get("center_offset", Vector2.ZERO)
		var apex_y: float = -coff.y * sc
		
		print("FACTORY: %-18s | Grid: %d×%d (%2d plots) | Size: %5.1f×%5.1fpx | Height vs Kubo: %+5.1fpx | Apex: %5.1f (vs %.1f)" % [
			f_id, fp.x, fp.y, fp.x * fp.y, w, h, h - kubo_h, apex_y, kubo_apex
		])

		# Enforce: Grid footprint must be strictly larger than Kubo (2x2 = 4 plots)
		assert(fp.x * fp.y > kubo_fp.x * kubo_fp.y, "Factory %s tile area (%d) must be greater than Kubo (4)" % [f_id, fp.x * fp.y])
		
		# Enforce: Visual height must be taller than Bahay Kubo (192px)
		assert(h > kubo_h, "Factory %s height (%.1f) must be taller than Bahay Kubo (%.1f)" % [f_id, h, kubo_h])
		
		# Enforce: Apex y reach must be higher than Bahay Kubo (-156px)
		assert(apex_y < kubo_apex, "Factory %s apex (%.1f) must reach higher than Bahay Kubo (%.1f)" % [f_id, apex_y, kubo_apex])

	print("✔ Check 1 Passed: All 5 factories are strictly larger in grid footprint and taller in sprite height than Bahay Kubo.")

	# 2. Test Placement on FarmGrid
	Data.game_mode = "sandbox"
	EconomyManager.cash = 999999
	var farm_grid_script = load("res://src/core/FarmGrid.gd")
	var farm_grid = Node2D.new()
	farm_grid.name = "FarmGrid"
	farm_grid.set_script(farm_grid_script)
	add_child(farm_grid)

	# Clean all tiles in homestead
	for x in range(12):
		for y in range(12):
			farm_grid.tiles[x][y].state = FarmTile.TileState.EMPTY

	# Place Rice Mill (3x3) at (4, 4)
	var placed_rm: bool = farm_grid.place_building(Vector2i(4, 4), "rice_mill")
	assert(placed_rm, "Rice mill should place cleanly at (4, 4)")
	
	# Verify all 9 tiles of 3x3 footprint are marked BUILDING
	for dx in range(3):
		for dy in range(3):
			var tile: FarmTile = farm_grid.tiles[4 + dx][4 + dy]
			assert(tile.state == FarmTile.TileState.BUILDING, "Tile (%d, %d) must be BUILDING" % [4 + dx, 4 + dy])
			assert(tile.building_ref != null, "Tile (%d, %d) must reference building" % [4 + dx, 4 + dy])

	# Place Sugar Central (4x4) at (7, 4)
	# Wait: (7, 4) with 4x4 occupies x: 7..10, y: 4..7 (within 12x12 homestead).
	var placed_sm: bool = farm_grid.place_building(Vector2i(7, 4), "sugar_mill")
	assert(placed_sm, "Sugar mill should place cleanly at (7, 4)")
	
	# Verify all 16 tiles of 4x4 footprint are marked BUILDING
	for dx in range(4):
		for dy in range(4):
			var tile: FarmTile = farm_grid.tiles[7 + dx][4 + dy]
			assert(tile.state == FarmTile.TileState.BUILDING, "Tile (%d, %d) must be BUILDING" % [7 + dx, 4 + dy])
			assert(tile.building_ref != null, "Tile (%d, %d) must reference building" % [7 + dx, 4 + dy])

	print("✔ Check 2 Passed: Grid footprints correctly occupy 3×3 (9 tiles) and 4×4 (16 tiles).")

	print("\n==================================================")
	print("ALL BUILDING SIZE & PROPORTION AUDITS PASSED!")
	print("==================================================")
	get_tree().quit(0)
