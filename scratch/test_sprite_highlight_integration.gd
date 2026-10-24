extends Node2D

func _ready() -> void:
	print("--- Testing Sprite Highlight Integration ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var farm_grid = maingame.find_child("FarmGrid", true, false)
	var overlay_node = farm_grid.find_child("DragSelectOverlay", true, false) as DragSelectOverlay
	assert(overlay_node != null, "DragSelectOverlay exists")

	# Select farmer
	var farmer = maingame.find_child("Farmer", true, false)
	TaskManager.select_farmer(farmer)

	# Plant 2x2 of rice at (5, 5), (5, 6), (6, 5), (6, 6)
	var tiles_2x2 = [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)]
	for p in tiles_2x2:
		var t: FarmTile = farm_grid.tiles[p.x][p.y]
		t.state = FarmTile.TileState.GROWING
		t.crop_type = "palay"
		t.growth_progress = 0.5
		farm_grid.renderer.update_tile(p, farm_grid.tiles)

	# Set active tool to harvest or water
	var plant_hotbar = maingame.find_child("PlantHotbar", true, false)
	if plant_hotbar:
		plant_hotbar.visible = true
		plant_hotbar.select_tool("water")

	# Hover over (5, 5)
	farm_grid.hovered_grid_pos = Vector2i(5, 5)
	overlay_node.queue_redraw()

	for _i in range(5):
		await get_tree().process_frame

	# Check that CropSprite at (5, 5) has material assigned
	var overlay = farm_grid.tile_overlays[5][5] as Node2D
	var crop_spr = overlay.find_child("CropSprite", true, false) as Sprite2D
	assert(crop_spr != null, "CropSprite exists")
	print("CropSprite material after hover: ", crop_spr.material != null)

	# Capture GPU image of the highlighted crop
	var camera = maingame.find_child("GameCamera", true, false)
	if camera:
		camera.global_position = FarmerMovement.grid_to_pixel_center(Vector2i(5, 5), farm_grid)
		camera.zoom = Vector2(2.5, 2.5)

	for _i in range(5):
		await get_tree().process_frame

	var viewport = get_viewport()
	var tex = viewport.get_texture()
	var img = tex.get_image()
	if img:
		var w = viewport.size.x
		var h = viewport.size.y
		var crop_rect = Rect2i(int(w / 2 - 200), int(h / 2 - 150), 400, 300)
		var cropped = img.get_region(crop_rect)
		var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/crop_sprite_highlight_runtime.png"
		cropped.save_png(path)
		print("Saved runtime capture to: ", path)

	get_tree().quit(0)
