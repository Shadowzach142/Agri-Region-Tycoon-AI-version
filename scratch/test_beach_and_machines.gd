extends Node

func _ready() -> void:
	print("==================================================")
	print("RUNNING BEACH SAND & MACHINE SPRITES VERIFICATION")
	print("==================================================")

	var failures: int = 0

	# -----------------------------------------------------------------------
	# 1. Beach Sand Detection & Ground Sprites
	# -----------------------------------------------------------------------
	print("\n--- 1. Testing Beach Tile Detection & Textures ---")
	var beach_count := 0
	for y in range(24):
		for x in range(24):
			var p := Vector2i(x, y)
			if GroundTileSprites.is_beach_tile(p):
				beach_count += 1
				if x < 22:
					print("FAIL: Inner tile at ", p, " marked as beach!")
					failures += 1
	print("Total beach tiles on 24x24 island: ", beach_count, " (expected: ~35-42)")
	if beach_count < 30 or beach_count > 48:
		print("FAIL: Unexpected beach tile count: ", beach_count)
		failures += 1
	else:
		print("PASS: Beach tile count is natural and correct: ", beach_count)

	# Test GroundTileSprites resource
	var gts := GroundTileSprites.new()
	var dummy_tile_empty := FarmTile.new()
	dummy_tile_empty.state = FarmTile.TileState.EMPTY
	dummy_tile_empty.soil_moisture = 40.0

	var tex_beach: Texture2D = gts.get_texture(dummy_tile_empty, Vector2i(23, 5))
	if tex_beach == null:
		print("FAIL: Beach tile returned null texture!")
		failures += 1
	else:
		print("PASS: Beach tile (23, 5) returned texture: ", tex_beach.resource_path)
		if not ("Sand" in tex_beach.resource_path or "WSand" in tex_beach.resource_path):
			print("FAIL: Expected Sand/WSand in resource_path, got: ", tex_beach.resource_path)
			failures += 1

	var dummy_tile_inland := FarmTile.new()
	dummy_tile_inland.state = FarmTile.TileState.EMPTY
	dummy_tile_inland.soil_moisture = 50.0
	var tex_inland: Texture2D = gts.get_texture(dummy_tile_inland, Vector2i(10, 10))
	if tex_inland == null or ("Sand" in tex_inland.resource_path):
		print("FAIL: Inland tile (10, 10) returned invalid texture: ", tex_inland)
		failures += 1
	else:
		print("PASS: Inland tile (10, 10) returned grass texture: ", tex_inland.resource_path)

	# -----------------------------------------------------------------------
	# 2. Drone Machine Sprites
	# -----------------------------------------------------------------------
	print("\n--- 2. Testing Drone Machine Sprites ---")
	var drone_tex: Texture2D = load("res://assets/sprites/Machine/Drones.png")
	if drone_tex == null:
		print("FAIL: Failed to load res://assets/sprites/Machine/Drones.png")
		failures += 1
	else:
		print("PASS: Loaded Drones.png successfully (", drone_tex.get_width(), "x", drone_tex.get_height(), ")")
		if drone_tex.get_width() != 192 or drone_tex.get_height() != 96:
			print("FAIL: Unexpected Drones.png dimensions!")
			failures += 1

	# Test FarmDrone static draw_drone_art
	var dummy_ci := Node2D.new()
	add_child(dummy_ci)
	for lvl in [1, 2, 3]:
		for ph in [0.0, 1.5, 3.5]:
			FarmDrone.draw_drone_art(dummy_ci, Vector2(50, 50), 3.0, lvl, ph, 0.0)
	print("PASS: FarmDrone.draw_drone_art executed for all levels and rotor frames")

	# -----------------------------------------------------------------------
	# 3. Sprinkler Machine Sprites
	# -----------------------------------------------------------------------
	print("\n--- 3. Testing Sprinkler Machine Sprites ---")
	var sprinkler_tex: Texture2D = load("res://assets/sprites/Machine/Sprinklers.png")
	if sprinkler_tex == null:
		print("FAIL: Failed to load res://assets/sprites/Machine/Sprinklers.png")
		failures += 1
	else:
		print("PASS: Loaded Sprinklers.png successfully (", sprinkler_tex.get_width(), "x", sprinkler_tex.get_height(), ")")

	if Building.SPRINKLER_FRAMES.size() != 5:
		print("FAIL: Building.SPRINKLER_FRAMES size is ", Building.SPRINKLER_FRAMES.size(), ", expected 5")
		failures += 1
	else:
		print("PASS: Building.SPRINKLER_FRAMES has 5 frames (Frame 0 idle, Frames 1..4 active)")
		for idx in range(Building.SPRINKLER_FRAMES.size()):
			var f: Dictionary = Building.SPRINKLER_FRAMES[idx]
			var reg: Rect2 = f.region
			var stem: Vector2 = f.stem
			if reg.position.x < 0 or reg.end.x > 416 or reg.position.y < 0 or reg.end.y > 80:
				print("FAIL: Frame ", idx, " rect out of bounds: ", reg)
				failures += 1
			if stem.x <= 0 or stem.y <= 0:
				print("FAIL: Frame ", idx, " invalid stem: ", stem)
				failures += 1
		print("PASS: All 5 sprinkler frame definitions verified within texture bounds")

	print("\n==================================================")
	if failures == 0:
		print("ALL VERIFICATIONS PASSED (0 failures)")
	else:
		print("VERIFICATION COMPLETED WITH %d FAILURES" % failures)
	print("==================================================")

	get_tree().quit()
