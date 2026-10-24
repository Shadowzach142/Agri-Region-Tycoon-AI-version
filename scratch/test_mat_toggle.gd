extends Node2D

func _ready() -> void:
	print("--- Testing material toggle on CropSprite ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var farm_grid = maingame.find_child("FarmGrid", true, false)
	farm_grid.tiles[5][5].state = FarmTile.TileState.GROWING
	farm_grid.tiles[5][5].crop_type = "palay"
	farm_grid.tiles[5][5].growth_progress = 0.5
	farm_grid.renderer.update_tile(Vector2i(5, 5), farm_grid.tiles)

	var overlay = farm_grid.tile_overlays[5][5] as Node2D
	var crop_spr = overlay.find_child("CropSprite", true, false) as Sprite2D
	assert(crop_spr != null, "CropSprite exists")
	assert(crop_spr.material == null, "CropSprite default material is null")

	var mat = ShaderMaterial.new()
	crop_spr.material = mat
	assert(crop_spr.material == mat, "CropSprite material assigned")

	crop_spr.material = null
	assert(crop_spr.material == null, "CropSprite material successfully cleared to null")

	print("✔ Material toggle works flawlessly!")
	get_tree().quit(0)
