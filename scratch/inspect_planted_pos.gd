@tool
extends SceneTree

func _init() -> void:
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)

	var farm_grid = root_node.find_child("FarmGrid", true, false)
	var pos := Vector2i(2, 2)
	farm_grid.tiles[pos.x][pos.y].state = FarmTile.TileState.PLOWED
	farm_grid.renderer.update_tile(pos, farm_grid.tiles)

	var ground_sprite: Sprite2D = farm_grid.tile_sprites[pos.x][pos.y]
	print("--- PLOWED TILE (2, 2) ---")
	print("GroundSprite texture: ", ground_sprite.texture.resource_path if ground_sprite.texture else "none")
	print("GroundSprite global_position: ", ground_sprite.global_position)
	print("GroundSprite offset: ", ground_sprite.offset)
	print("GroundSprite scale: ", ground_sprite.scale)

	# Now plant Rice
	farm_grid.tiles[pos.x][pos.y].crop_type = "palay"
	farm_grid.tiles[pos.x][pos.y].state = FarmTile.TileState.PLANTED
	farm_grid.renderer.update_tile(pos, farm_grid.tiles)

	var overlay: Node2D = farm_grid.tile_overlays[pos.x][pos.y]
	print("\n--- PLANTED TILE (2, 2) with Palay ---")
	print("GroundSprite visible: ", ground_sprite.visible)
	print("GroundSprite texture: ", ground_sprite.texture.resource_path if ground_sprite.texture else "none")
	print("GroundSprite offset: ", ground_sprite.offset)
	for child in overlay.get_children():
		print("Overlay child: ", child.name, " class: ", child.get_class())
		if child is Sprite2D:
			print("  CropSprite texture: ", child.texture.resource_path if child.texture else "none")
			print("  CropSprite global_position: ", child.global_position)
			print("  CropSprite offset: ", child.offset)
			print("  CropSprite scale: ", child.scale)

	# Also check tile diamond
	var diamond = FarmerMovement.get_tile_diamond_local(pos)
	print("\nTile diamond vertices in FarmGrid local space:")
	for v in diamond:
		print("  ", v)
	print("Tile center (tile_pos_px): ", FarmerMovement.grid_to_pixel_center(pos, null))

	quit(0)
