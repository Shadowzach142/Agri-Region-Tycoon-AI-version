@tool
extends SceneTree

func _init():
	print("--- TEST SIBLING VS CHILD Y-SORT IN GODOT 4 ---")
	var root_2d = Node2D.new()
	root_2d.y_sort_enabled = true
	root.add_child(root_2d)

	var grid = Node2D.new()
	grid.name = "FarmGrid"
	grid.position = Vector2(0, 0)
	grid.y_sort_enabled = true
	root_2d.add_child(grid)

	# Tile A at Y=100
	var tile_a = Node2D.new()
	tile_a.name = "TileA"
	tile_a.position = Vector2(100, 100)
	tile_a.z_index = 10
	grid.add_child(tile_a)

	# Tile B at Y=500
	var tile_b = Node2D.new()
	tile_b.name = "TileB"
	tile_b.position = Vector2(100, 500)
	tile_b.z_index = 10
	grid.add_child(tile_b)

	# Farmer sibling at Y=300
	var farmer_sibling = CharacterBody2D.new()
	farmer_sibling.name = "FarmerSibling"
	farmer_sibling.position = Vector2(100, 300)
	farmer_sibling.z_index = 10
	root_2d.add_child(farmer_sibling)

	print("Structure created.")
	# In Godot 4, canvas item draw list:
	# Does farmer_sibling get drawn between tile_a and tile_b?
	# Let's inspect RenderingServer or check how Godot sorts them:
	print("grid y_sort: ", grid.y_sort_enabled)
	print("root y_sort: ", root_2d.y_sort_enabled)
	
	quit(0)
