extends SceneTree

func _init() -> void:
	print("--- BEGIN OBSTACLES & PEST OVERLAYS VERIFICATION ---")

	var rnd := TileRenderer.new()

	# 1. Texture Loading Verification
	var stump_tex := rnd.get_tree_obstacle_texture()
	assert(stump_tex != null, "Tree stump texture must not be null!")
	print("PASS: Tree stump texture loaded -> %s (%dx%d)" % [stump_tex.resource_path, stump_tex.get_width(), stump_tex.get_height()])

	var rock_tex_set: Dictionary = {}
	for x in range(5):
		for y in range(5):
			var r_tex := rnd.get_rock_texture(Vector2i(x, y))
			assert(r_tex != null, "Rock texture must not be null at (%d, %d)" % [x, y])
			rock_tex_set[r_tex.resource_path] = true
	print("PASS: Rock textures distributed across grid -> %d unique boulder variants" % rock_tex_set.size())
	assert(rock_tex_set.size() == 3, "Expected 3 unique boulder variants!")

	var pests := ["kuhol", "armyworm", "rice_black_bug", "fusarium_wilt"]
	for p in pests:
		var p_tex := rnd.get_pest_overlay_texture(p)
		assert(p_tex != null, "Pest overlay texture for '%s' must not be null!" % p)
		print("PASS: Pest overlay '%s' loaded -> %s (%dx%d)" % [p, p_tex.resource_path, p_tex.get_width(), p_tex.get_height()])

	# 2. Rendering Node Structure Verification
	var root_node := Node2D.new()

	var fill := Polygon2D.new()
	var overlay := Node2D.new()
	var dot := ColorRect.new()
	var lbl := Label.new()
	var sprite := Sprite2D.new()
	root_node.add_child(fill)
	root_node.add_child(overlay)
	root_node.add_child(dot)
	root_node.add_child(lbl)
	root_node.add_child(sprite)

	var fills := [[fill]]
	var overlays := [[overlay]]
	var dots := [[dot]]
	var labels := [[lbl]]
	var sprites := [[sprite]]

	rnd.setup(fills, overlays, dots, labels, sprites)

	var tile := FarmTile.new()
	var grid := [[tile]]

	# Test A: Rock Obstacle
	tile.reset()
	tile.state = FarmTile.TileState.OBSTACLE
	tile.obstacle_type = "rock"
	rnd.update_tile(Vector2i(0, 0), grid)
	var rock_spr := overlay.find_child("RockObstacleSprite", true, false) as Sprite2D
	assert(rock_spr != null, "Overlay must contain RockObstacleSprite!")
	assert(rock_spr.scale == Vector2(2.0, 2.0), "RockObstacleSprite scale must be 2.0!")
	assert(rock_spr.position == Vector2(0.0, -6.0), "RockObstacleSprite position must be (0, -6)!")
	assert(rock_spr.modulate == Color.WHITE, "Unlocked rock obstacle must be Color.WHITE!")
	print("PASS: Rock obstacle rendered with proper Sprite2D, scale, position, and modulate.")

	# Test B: Tree Stump Obstacle
	tile.reset()
	tile.state = FarmTile.TileState.OBSTACLE
	tile.obstacle_type = "tree"
	rnd.update_tile(Vector2i(0, 0), grid)
	var stump_spr := overlay.find_child("TreeObstacleSprite", true, false) as Sprite2D
	assert(stump_spr != null, "Overlay must contain TreeObstacleSprite!")
	assert(stump_spr.scale == Vector2(2.0, 2.0), "TreeObstacleSprite scale must be 2.0!")
	assert(stump_spr.position == Vector2(0.0, -6.0), "TreeObstacleSprite position must be (0, -6)!")
	assert(stump_spr.modulate == Color.WHITE, "Unlocked stump obstacle must be Color.WHITE!")
	print("PASS: Tree stump obstacle rendered with proper Sprite2D, scale, position, and modulate.")

	# Test C: Locked Territory Obstacle Modulation
	tile.reset()
	tile.state = FarmTile.TileState.LOCKED
	tile.obstacle_type = "rock"
	rnd.update_tile(Vector2i(0, 0), grid)
	rock_spr = overlay.find_child("RockObstacleSprite", true, false) as Sprite2D
	assert(rock_spr != null, "Overlay must contain RockObstacleSprite for locked rock!")
	assert(rock_spr.modulate == Color(0.58, 0.66, 0.54, 1.0), "Locked rock obstacle must have wilderness modulate!")
	print("PASS: Locked obstacle has wilderness modulate.")

	# Test D: Infected Crop Overlay & Emoji Suppression
	tile.reset()
	tile.state = FarmTile.TileState.INFECTED
	tile.crop_type = "palay"
	tile.pest_type = "kuhol"
	tile.health = 0.5
	rnd.update_tile(Vector2i(0, 0), grid)
	var crop_spr := overlay.find_child("CropSprite", true, false) as Sprite2D
	assert(crop_spr != null, "Overlay must render CropSprite under INFECTED state!")
	var pest_spr := overlay.find_child("PestOverlaySprite", true, false) as Sprite2D
	assert(pest_spr != null, "Overlay must render PestOverlaySprite on INFECTED tile!")
	assert(pest_spr.texture == rnd.get_pest_overlay_texture("kuhol"), "PestOverlaySprite must use kuhol texture!")
	assert(pest_spr.z_index == 1, "PestOverlaySprite must have z_index = 1 to overlay crop!")
	assert(lbl.text == "", "Emoji '🐛' must be suppressed when custom pest overlay is present!")
	print("PASS: Infected crop renders standing crop + kuhol pest overlay sprite (z_index=1) without emoji.")

	# Test E: Multi-tile Child Plot Infestation Overlay
	tile.reset()
	tile.state = FarmTile.TileState.INFECTED
	tile.crop_type = "coconut"
	tile.multi_tile_root_pos = Vector2i(0, 0)
	tile.is_multi_tile_root = false
	tile.pest_type = "fusarium_wilt"
	rnd.update_tile(Vector2i(0, 0), grid)
	pest_spr = overlay.find_child("PestOverlaySprite", true, false) as Sprite2D
	assert(pest_spr != null, "Multi-tile child plot must render PestOverlaySprite when infested!")
	assert(pest_spr.texture == rnd.get_pest_overlay_texture("fusarium_wilt"), "PestOverlaySprite must use fusarium_wilt texture!")
	print("PASS: Multi-tile child plot renders pest overlay sprite across entire grove.")

	root_node.queue_free()
	print("--- ALL OBSTACLE AND OVERLAY VERIFICATIONS PASSED ---")
	quit(0)
