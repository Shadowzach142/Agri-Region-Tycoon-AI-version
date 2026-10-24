@tool
extends SceneTree

func _init():
	print("--- TESTING GODOT 4 HIERARCHICAL Y-SORT ---")
	var root_node = Node2D.new()
	root_node.y_sort_enabled = true
	root.add_child(root_node)

	var grid = Node2D.new()
	grid.name = "FarmGrid"
	grid.position = Vector2(0, 0)
	grid.y_sort_enabled = true
	root_node.add_child(grid)

	# Tile in grid at Y=500
	var tile_south = Node2D.new()
	tile_south.name = "TileSouth"
	tile_south.position = Vector2(100, 500)
	grid.add_child(tile_south)

	# Sprite inside TileSouth
	var sprite_south = Sprite2D.new()
	sprite_south.name = "SpriteSouth"
	tile_south.add_child(sprite_south)

	# Farmer outside grid, sibling of grid, at Y=200
	var farmer = CharacterBody2D.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(100, 200)
	root_node.add_child(farmer)

	print("root_node.y_sort_enabled: ", root_node.y_sort_enabled)
	print("grid.y_sort_enabled: ", grid.y_sort_enabled)
	print("tile_south.y_sort_enabled: ", tile_south.y_sort_enabled)
	
	quit(0)
