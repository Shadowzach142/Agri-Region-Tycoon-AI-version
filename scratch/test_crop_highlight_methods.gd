extends Node2D

func _ready() -> void:
	print("--- Testing Crop Highlight Rendering Methods ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var farm_grid = maingame.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid exists")

	# Find or plant rice at (5, 5)
	var t: FarmTile = farm_grid.tiles[5][5]
	t.state = FarmTile.TileState.GROWING
	t.crop_type = "palay"
	t.growth_progress = 0.5
	farm_grid.renderer.update_tile(Vector2i(5, 5), farm_grid.tiles)

	var overlay = farm_grid.tile_overlays[5][5] as Node2D
	var crop_spr = overlay.find_child("CropSprite", true, false) as Sprite2D
	print("Crop sprite found at (5, 5): ", crop_spr != null)
	if crop_spr:
		print("CropSprite texture: ", crop_spr.texture.resource_path)
		print("CropSprite position: ", crop_spr.position, " scale: ", crop_spr.scale)

	get_tree().quit(0)
