@tool
extends SceneTree

func _init() -> void:
	print("--- Starting Crop Alignment, Coconut Center, and Banana 2x2 Test ---")
	
	var root_node = Node2D.new()
	var farm_grid = load("res://src/core/FarmGrid.gd").new()
	root_node.add_child(farm_grid)
	
	# -------------------------------------------------------------------------
	# 1. Verify 1x1 Crop Alignment (Rice, Corn, Sugarcane, Pineapple, Coffee)
	# -------------------------------------------------------------------------
	var test_1x1_crops: Array[String] = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee"]
	for i in range(test_1x1_crops.size()):
		var crop_id: String = test_1x1_crops[i]
		var pos := Vector2i(i, 0)
		var tile: FarmTile = farm_grid.tiles[pos.x][pos.y]
		tile.state = FarmTile.TileState.PLANTED
		tile.crop_type = crop_id
		tile.growth_progress = 0.0
		tile.health = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		
		var overlay = farm_grid.tile_overlays[pos.x][pos.y]
		var spr: Sprite2D = overlay.find_child("CropSprite", false, false) as Sprite2D
		assert(spr != null, "CropSprite missing for %s" % crop_id)
		assert(spr.position == Vector2.ZERO, "CropSprite position must be Vector2.ZERO")
		
		var tex_h: float = float(spr.texture.get_height())
		var expected_offset_y := 12.0 - tex_h / 2.0
		assert(spr.offset.y == expected_offset_y, "%s offset.y should be %.1f, got %.1f" % [crop_id, expected_offset_y, spr.offset.y])
		
		# Screen equator check (row 20 for 32h, row 52 for 64h)
		var tex_equator_row := 20.0 if tex_h == 32.0 else (52.0 if tex_h == 64.0 else 0.0)
		if tex_equator_row > 0.0:
			var img_center_y := tex_h / 2.0
			var screen_equator := (tex_equator_row - img_center_y) * 4.0 + spr.offset.y * 4.0
			assert(abs(screen_equator) < 0.001, "%s screen equator should be 0.0, got %.2f" % [crop_id, screen_equator])
			print("  ✔ 1x1 %s (height %d): offset=(0, %.1f), screen equator=%.1f (PERFECT)" % [crop_id, int(tex_h), spr.offset.y, screen_equator])

	# -------------------------------------------------------------------------
	# 2. Verify Coconut 2x2 Centering at Vector2(0, 32)
	# -------------------------------------------------------------------------
	var coco_root := Vector2i(0, 2)
	var coco_tile: FarmTile = farm_grid.tiles[coco_root.x][coco_root.y]
	coco_tile.state = FarmTile.TileState.GROWING
	coco_tile.crop_type = "coconut"
	coco_tile.growth_progress = 0.8
	coco_tile.health = 1.0
	coco_tile.is_multi_tile_root = true
	coco_tile.multi_tile_root_pos = coco_root
	
	farm_grid.renderer.update_tile(coco_root, farm_grid.tiles)
	var coco_overlay = farm_grid.tile_overlays[coco_root.x][coco_root.y]
	var coco_spr: Sprite2D = coco_overlay.find_child("CropSprite2x2", false, false) as Sprite2D
	assert(coco_spr != null, "Coconut CropSprite2x2 missing")
	assert(coco_spr.position == Vector2(0, 32), "Coconut CropSprite2x2 must be positioned at (0, 32), got %s" % coco_spr.position)
	print("  ✔ Coconut 2x2 sprite position: %s (EXACT CENTER OF 4 PLOTS)" % coco_spr.position)

	# -------------------------------------------------------------------------
	# 3. Verify Banana 2x2 Configuration & Centering at Vector2(0, 32)
	# -------------------------------------------------------------------------
	var banana_data: Dictionary = farm_grid.data_crops.get("banana", {}) if "data_crops" in farm_grid else {}
	# Check directly in Data.CROPS
	var global_data = load("res://autoload/Data.gd").new()
	var b_dict: Dictionary = global_data.CROPS.get("banana", {})
	
	print("  ✔ Banana footprint: ", b_dict.get("footprint"))
	assert(b_dict.get("footprint") == Vector2i(2, 2), "Banana footprint must be 2x2")
	assert(b_dict.get("seed_cost") == 140, "Banana seed cost must be 140")
	assert(b_dict.get("yield_quantity") == 400, "Banana yield must be 400")
	assert(b_dict.get("is_perennial") == true, "Banana is_perennial must be true")
	assert(b_dict.get("regrowth_days") == 18, "Banana regrowth_days must be 18")

	var banana_root := Vector2i(2, 2)
	var b_tile: FarmTile = farm_grid.tiles[banana_root.x][banana_root.y]
	b_tile.state = FarmTile.TileState.GROWING
	b_tile.crop_type = "banana"
	b_tile.growth_progress = 0.5
	b_tile.health = 1.0
	b_tile.is_multi_tile_root = true
	b_tile.multi_tile_root_pos = banana_root
	
	farm_grid.renderer.update_tile(banana_root, farm_grid.tiles)
	var b_overlay = farm_grid.tile_overlays[banana_root.x][banana_root.y]
	var b_spr: Sprite2D = b_overlay.find_child("CropSprite2x2", false, false) as Sprite2D
	assert(b_spr != null, "Banana CropSprite2x2 missing")
	assert(b_spr.position == Vector2(0, 32), "Banana CropSprite2x2 must be positioned at (0, 32), got %s" % b_spr.position)
	print("  ✔ Banana 2x2 sprite position: %s (EXACT CENTER OF 4 PLOTS)" % b_spr.position)
	print("  ✔ Banana stage 2 trunk offset: %s" % b_spr.offset)

	# Test all 6 banana stages trunk offsets
	for s in range(1, 7):
		if s <= 4:
			b_tile.state = FarmTile.TileState.GROWING
			b_tile.growth_progress = 0.1 if s == 1 else (0.4 if s == 2 else (0.8 if s == 3 else 1.0))
			b_tile.health = 1.0
			b_tile.pest_type = ""
		elif s == 5:
			b_tile.pest_type = "kuhol"
			b_tile.health = 0.5
		elif s == 6:
			b_tile.state = FarmTile.TileState.FLOODED
			b_tile.health = 0.1
		
		farm_grid.renderer.update_tile(banana_root, farm_grid.tiles)
		var st_spr: Sprite2D = b_overlay.find_child("CropSprite2x2", false, false) as Sprite2D
		assert(st_spr != null)
		assert(st_spr.position == Vector2(0, 32))
		print("  ✔ Banana stage %d rendered at %s with offset %s" % [s, st_spr.position, st_spr.offset])

	print("--- ALL TESTS PASSED SUCCESSFULLY! ---")
	root_node.queue_free()
	quit(0)
