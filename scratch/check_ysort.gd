@tool
extends SceneTree

func _init():
	var main_scene = load("res://scenes/MainGame.tscn")
	var main_game = main_scene.instantiate()
	root.add_child(main_game)
	
	var farm_grid = main_game.find_child("FarmGrid", true, false)
	var farmer = main_game.find_child("Farmer", true, false)
	
	print("MainGame y_sort_enabled:", main_game.y_sort_enabled)
	print("FarmGrid y_sort_enabled:", farm_grid.y_sort_enabled)
	print("FarmGrid z_index:", farm_grid.z_index)
	print("Farmer z_index:", farmer.z_index)
	print("Farmer y_sort_enabled:", farmer.y_sort_enabled)
	
	var tile_roots = farm_grid.tile_roots
	if tile_roots.size() > 0 and tile_roots[0].size() > 0:
		var t00 = tile_roots[0][0]
		print("Tile 0,0 name:", t00.name, "pos:", t00.position, "z_index:", t00.z_index)
		print("Tile 0,0 y_sort_enabled:", t00.y_sort_enabled)
	
	quit(0)
