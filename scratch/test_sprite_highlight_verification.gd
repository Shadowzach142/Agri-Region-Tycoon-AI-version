extends Node2D

func _ready() -> void:
	print("--- Running Crop Sprite Highlight Verification ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var farm_grid = maingame.find_child("FarmGrid", true, false)
	var drag_overlay = farm_grid.find_child("DragSelectOverlay", true, false) as DragSelectOverlay
	assert(drag_overlay != null, "DragSelectOverlay must exist")

	var farmer = maingame.find_child("Farmer", true, false)
	TaskManager.select_farmer(farmer)

	# 1. Setup 1x1 Palay at (5, 5)
	var t1: FarmTile = farm_grid.tiles[5][5]
	t1.state = FarmTile.TileState.GROWING
	t1.crop_type = "palay"
	t1.growth_progress = 0.5
	farm_grid.renderer.update_tile(Vector2i(5, 5), farm_grid.tiles)

	var ov1 = farm_grid.tile_overlays[5][5] as Node2D
	var crop1 = ov1.find_child("CropSprite", true, false) as Sprite2D
	assert(crop1 != null, "CropSprite must exist at (5, 5)")
	print("Found 1x1 CropSprite at (5, 5)")

	# 2. Setup 2x2 Coconut Palm at (7, 7)
	for dx in range(2):
		for dy in range(2):
			var p := Vector2i(7 + dx, 7 + dy)
			var t := farm_grid.tiles[p.x][p.y] as FarmTile
			t.state = FarmTile.TileState.GROWING
			t.crop_type = "coconut"
			t.growth_progress = 0.8
			t.multi_tile_root_pos = Vector2i(7, 7)
			t.is_multi_tile_root = (dx == 0 and dy == 0)
			farm_grid.renderer.update_tile(p, farm_grid.tiles)

	var ov2 = farm_grid.tile_overlays[7][7] as Node2D
	var crop2 = ov2.find_child("CropSprite2x2", true, false) as Sprite2D
	assert(crop2 != null, "CropSprite2x2 must exist at (7, 7)")
	print("Found 2x2 CropSprite2x2 at (7, 7)")

	# Wait frames for setup
	for _i in range(5):
		await get_tree().process_frame

	# Test A: Hovering over 1x1 crop with tool
	print("[Test A] Hovering with water tool over (5, 5)...")
	PlantHotbar.set_selected_tool("water")
	var plant_hotbar = maingame.find_child("PlantHotbar", true, false)
	if plant_hotbar:
		plant_hotbar.visible = true

	farm_grid.hovered_grid_pos = Vector2i(5, 5)
	farm_grid._update_hover_cursor()
	drag_overlay.queue_redraw()

	for _i in range(5):
		await get_tree().process_frame

	assert(farm_grid.hover_indicator.visible == false, "hover_indicator must be FALSE on standing crop")
	assert(crop1.material != null, "CropSprite at (5, 5) must have highlight material assigned")
	var mat1 = crop1.material as ShaderMaterial
	var col1: Color = mat1.get_shader_parameter("outline_color")
	print("Crop1 outline color: ", col1)
	assert(col1.g > 0.8, "Crop1 outline color must be green")

	# Test B: Hovering over empty tile (6, 5) resets crop1 highlight
	print("[Test B] Moving hover to empty tile (6, 5)...")
	farm_grid.hovered_grid_pos = Vector2i(6, 5)
	farm_grid._update_hover_cursor()
	drag_overlay.queue_redraw()

	for _i in range(5):
		await get_tree().process_frame

	assert(crop1.material == null, "CropSprite at (5, 5) must be cleared when mouse moves away")
	assert(farm_grid.hover_indicator.visible == true, "hover_indicator must be TRUE on empty tile")

	# Test C: Hovering over 2x2 Coconut child plot (8, 8) highlights root tree
	print("[Test C] Hovering over 2x2 child plot (8, 8)...")
	farm_grid.hovered_grid_pos = Vector2i(8, 8)
	farm_grid._update_hover_cursor()
	drag_overlay.queue_redraw()

	for _i in range(5):
		await get_tree().process_frame

	assert(farm_grid.hover_indicator.visible == false, "hover_indicator must be FALSE on 2x2 crop")
	assert(crop2.material != null, "CropSprite2x2 must have highlight material assigned")

	# Test D: Selecting crop tile (5, 5)
	print("[Test D] Selecting tile (5, 5)...")
	farm_grid.select_tile(Vector2i(5, 5))

	for _i in range(3):
		await get_tree().process_frame

	assert(farm_grid.selection_indicator.visible == false, "selection_indicator must be FALSE on crop tile")
	assert(crop1.material != null, "CropSprite at (5, 5) must have gold highlight material")
	var mat_sel = crop1.material as ShaderMaterial
	var col_sel: Color = mat_sel.get_shader_parameter("outline_color")
	print("Crop1 selection color: ", col_sel)
	assert(col_sel.r > 0.8 and col_sel.g > 0.8, "Selection outline color must be gold")

	# Test E: Deselecting clears material
	print("[Test E] Deselecting on right-click...")
	farm_grid.hovered_grid_pos = Vector2i(-1, -1)
	var mb_right = InputEventMouseButton.new()
	mb_right.button_index = MOUSE_BUTTON_RIGHT
	mb_right.pressed = true
	farm_grid._unhandled_input(mb_right)

	for _i in range(5):
		await get_tree().process_frame

	assert(crop1.material == null, "CropSprite material must be reset to null after deselect")
	print("--- All Highlight Assertions PASSED Successfully! ---")

	# GPU Screenshot Capture of Highlighted 2x2 Rice & Coconut
	print("Capturing GPU screenshot of highlighted crops...")
	# Highlight both for visual snapshot
	drag_overlay._highlight_crop_sprite(Vector2i(5, 5), "green")
	drag_overlay._highlight_crop_sprite(Vector2i(7, 7), "green")

	var camera = maingame.find_child("GameCamera", true, false)
	if camera:
		camera.global_position = FarmerMovement.grid_to_pixel_center(Vector2i(6, 6), farm_grid)
		camera.zoom = Vector2(2.0, 2.0)

	for _i in range(5):
		await get_tree().process_frame

	var vp = get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var w = vp.size.x
		var h = vp.size.y
		var crop_rect = Rect2i(int(w / 2 - 250), int(h / 2 - 180), 500, 360)
		var cropped = img.get_region(crop_rect)
		var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/crop_sprite_highlight_runtime.png"
		cropped.save_png(path)
		print("Saved visual verification capture to: ", path)

	get_tree().quit(0)
