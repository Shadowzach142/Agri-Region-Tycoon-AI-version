extends Node

func _ready() -> void:
	print("--- RENDERING FARMER VARIANTS IN-GAME SHOWCASE ---")
	var main_scene = load("res://scenes/MainGame.tscn")
	var main_game = main_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame

	var farm_grid = main_game.find_child("FarmGrid", true, false)
	var starter_farmer = main_game.find_child("Farmer", true, false)
	var camera = main_game.find_child("GameCamera", true, false)
	var FarmerScript: GDScript = load("res://src/farmer/Farmer.gd")

	# Position camera centered over the showcase area
	camera.position = FarmerMovement.grid_to_pixel_center(Vector2i(5, 5), farm_grid) + Vector2(-90, -80)
	camera.zoom = Vector2(2.4, 2.4) # generous zoom for clear character inspection

	# Prepare a clean diagonal line of 8 tiles
	var showcase_tiles = []
	for i in range(8):
		showcase_tiles.append(Vector2i(2 + i, 5))

	for i in range(showcase_tiles.size()):
		var pos = showcase_tiles[i]
		var t = farm_grid.tiles[pos.x][pos.y]
		t.state = FarmTile.TileState.EMPTY
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)

	# Position starter farmer at (2, 5) with variant 0
	starter_farmer.position = FarmerMovement.grid_to_pixel_center(Vector2i(2, 5), farm_grid)
	starter_farmer.variant_id = 0
	starter_farmer._play_anim("idle", 0.0)

	var anim_list = ["idle", "walk", "till", "harvest", "idle", "walk", "till", "harvest"]

	# Spawn remaining 7 farmers
	for i in range(1, 8):
		var pos = showcase_tiles[i]
		var f = CharacterBody2D.new()
		f.set_script(FarmerScript)
		f.name = "Farmer_%d" % (i + 1)
		f.z_index = 12
		f.position = FarmerMovement.grid_to_pixel_center(pos, farm_grid)

		var sprite = Sprite2D.new()
		sprite.name = "FarmerSprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(2.0, 2.0)
		sprite.position = Vector2(0.0, -20.0)
		f.add_child(sprite)

		var label = Label.new()
		label.name = "FarmerLabel"
		label.offset_left = -50.0
		label.offset_top = -64.0
		label.offset_right = 50.0
		label.offset_bottom = -46.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.add_child(label)

		main_game.add_child(f)
		f.variant_id = i
		var anim = anim_list[i]
		f._play_anim(anim, 0.0)

	# Wait several frames for all rendering, lights, and textures to settle
	for frame in range(10):
		await get_tree().process_frame

	# Capture viewport
	var img = get_viewport().get_texture().get_image()
	var save_path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/farmer_variants_ingame_showcase.png"
	img.save_png(save_path)
	print("Captured in-game farmer variants showcase to: ", save_path)
	get_tree().quit(0)
