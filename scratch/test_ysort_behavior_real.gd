@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/MainGame.tscn").instantiate()
	root.add_child(scene)
	
	var farm_grid = scene.find_child("FarmGrid", true, false)
	var farmer = scene.find_child("Farmer", true, false)
	
	print("MainGame y_sort_enabled: ", scene.y_sort_enabled)
	print("FarmGrid y_sort_enabled: ", farm_grid.y_sort_enabled)
	print("FarmGrid parent: ", farm_grid.get_parent().name)
	print("Farmer parent: ", farmer.get_parent().name)
	print("Farmer z_index: ", farmer.z_index)
	print("Tile 0,0 z_index: ", farm_grid.tile_roots[0][0].z_index)
	print("Tile 0,0 y_sort_enabled: ", farm_grid.tile_roots[0][0].y_sort_enabled)
	
	quit(0)
