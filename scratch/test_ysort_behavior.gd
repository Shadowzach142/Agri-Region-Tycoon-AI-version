@tool
extends SceneTree

func _init():
	print("Testing Godot 4 Y-sorting between FarmGrid children and Farmer...")
	var root_node = Node2D.new()
	root_node.y_sort_enabled = true
	
	var farm_grid = Node2D.new()
	farm_grid.name = "FarmGrid"
	farm_grid.y_sort_enabled = true
	root_node.add_child(farm_grid)
	
	# Tile A at Y=100
	var tile_a = Node2D.new()
	tile_a.position = Vector2(100, 100)
	tile_a.z_index = 10
	farm_grid.add_child(tile_a)
	
	# Tile B at Y=500
	var tile_b = Node2D.new()
	tile_b.position = Vector2(100, 500)
	tile_b.z_index = 10
	farm_grid.add_child(tile_b)
	
	# Farmer at Y=300 (between Tile A and Tile B)
	var farmer = CharacterBody2D.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(100, 300)
	farmer.z_index = 10
	root_node.add_child(farmer)
	
	print("Scene structure created. Now testing if Farmer is Y-sorted relative to tiles...")
	quit(0)
