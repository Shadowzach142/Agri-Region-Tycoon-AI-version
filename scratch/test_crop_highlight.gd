@tool
extends SceneTree

func _init() -> void:
	print("--- Testing Crop Highlight Rendering ---")
	var root = Node2D.new()
	var farm_grid = load("res://src/core/FarmGrid.gd").new()
	root.add_child(farm_grid)
	
	# Test getting crop texture and calculating dest_rect for Rice (1x1)
	var p_rice := Vector2i(2, 2)
	var t_rice: FarmTile = farm_grid.tiles[p_rice.x][p_rice.y]
	t_rice.state = FarmTile.TileState.GROWING
	t_rice.crop_type = "palay"
	t_rice.growth_progress = 0.5
	farm_grid.renderer.update_tile(p_rice, farm_grid.tiles)
	
	var tex_rice: Texture2D = farm_grid.renderer.get_crop_texture_for_tile(t_rice)
	assert(tex_rice != null, "Rice texture must not be null")
	print("Rice texture found: %s (%dx%d)" % [tex_rice.resource_path.get_file(), tex_rice.get_width(), tex_rice.get_height()])
	
	# Test Coconut (2x2)
	var p_coco := Vector2i(4, 4)
	var t_coco: FarmTile = farm_grid.tiles[p_coco.x][p_coco.y]
	t_coco.state = FarmTile.TileState.GROWING
	t_coco.crop_type = "coconut"
	t_coco.growth_progress = 0.8
	t_coco.is_multi_tile_root = true
	t_coco.multi_tile_root_pos = p_coco
	farm_grid.renderer.update_tile(p_coco, farm_grid.tiles)
	
	var tex_coco: Texture2D = farm_grid.renderer.get_crop_texture_for_tile(t_coco)
	assert(tex_coco != null, "Coconut texture must not be null")
	print("Coconut texture found: %s (%dx%d)" % [tex_coco.resource_path.get_file(), tex_coco.get_width(), tex_coco.get_height()])
	
	# Test Banana (2x2)
	var p_bana := Vector2i(6, 4)
	var t_bana: FarmTile = farm_grid.tiles[p_bana.x][p_bana.y]
	t_bana.state = FarmTile.TileState.GROWING
	t_bana.crop_type = "banana"
	t_bana.growth_progress = 0.5
	t_bana.is_multi_tile_root = true
	t_bana.multi_tile_root_pos = p_bana
	farm_grid.renderer.update_tile(p_bana, farm_grid.tiles)
	
	var tex_bana: Texture2D = farm_grid.renderer.get_crop_texture_for_tile(t_bana)
	assert(tex_bana != null, "Banana texture must not be null")
	print("Banana texture found: %s (%dx%d)" % [tex_bana.resource_path.get_file(), tex_bana.get_width(), tex_bana.get_height()])

	root.queue_free()
	print("All textures loaded cleanly.")
	quit(0)
