extends Node

func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var root_node = main_scene.instantiate()
	add_child(root_node)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = root_node.find_child("FarmGrid", true, false)
	var crops := ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]

	for c in crops:
		print("=================== CROP: %s ===================" % c)
		var pos := Vector2i(2, 2)
		farm_grid.tiles[pos.x][pos.y].crop_type = c
		farm_grid.tiles[pos.x][pos.y].state = FarmTile.TileState.PLANTED
		farm_grid.tiles[pos.x][pos.y].growth_progress = 0.0
		farm_grid.tiles[pos.x][pos.y].is_multi_tile_root = (c == "coconut")
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)

		var overlay: Node2D = farm_grid.tile_overlays[pos.x][pos.y]
		for child in overlay.get_children():
			if child is Sprite2D:
				print("Stage 1: tex=%s (%dx%d), offset=%s, pos=%s" % [
					child.texture.resource_path.get_file(),
					child.texture.get_width(), child.texture.get_height(),
					child.offset, child.position
				])

		# Stage mature (HARVESTABLE)
		farm_grid.tiles[pos.x][pos.y].state = FarmTile.TileState.HARVESTABLE
		farm_grid.tiles[pos.x][pos.y].growth_progress = 1.0
		farm_grid.renderer.update_tile(pos, farm_grid.tiles)
		for child in overlay.get_children():
			if child is Sprite2D:
				print("Mature: tex=%s (%dx%d), offset=%s, pos=%s" % [
					child.texture.resource_path.get_file(),
					child.texture.get_width(), child.texture.get_height(),
					child.offset, child.position
				])

	root_node.queue_free()
	get_tree().quit(0)
