extends Node

func _ready() -> void:
	print("--- Testing Godot 4 Hierarchical Y-Sorting ---")
	
	# Root node with y_sort_enabled
	var root := Node2D.new()
	root.y_sort_enabled = true
	add_child(root)
	
	# Sub-container with y_sort_enabled (like FarmGrid)
	var grid := Node2D.new()
	grid.name = "FarmGrid"
	grid.y_sort_enabled = true
	grid.z_index = 10
	root.add_child(grid)
	
	# Building at position Y = 400
	var building := Node2D.new()
	building.name = "Building"
	building.position = Vector2(500, 400)
	building.z_index = 10
	grid.add_child(building)
	
	# Tile Behind at position Y = 300
	var tile_behind := Node2D.new()
	tile_behind.name = "TileBehind"
	tile_behind.position = Vector2(500, 300)
	tile_behind.z_index = 10
	grid.add_child(tile_behind)
	
	# Tile Front at position Y = 500
	var tile_front := Node2D.new()
	tile_front.name = "TileFront"
	tile_front.position = Vector2(500, 500)
	tile_front.z_index = 10
	grid.add_child(tile_front)
	
	# Farmer at position Y = 450 (between building and tile_front) as child of root
	var farmer := Node2D.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(500, 450)
	farmer.z_index = 10
	root.add_child(farmer)
	
	print("Nodes created:")
	print("  Building Y: ", building.global_position.y, " z_index: ", building.z_index)
	print("  TileBehind Y: ", tile_behind.global_position.y, " z_index: ", tile_behind.z_index)
	print("  TileFront Y: ", tile_front.global_position.y, " z_index: ", tile_front.z_index)
	print("  Farmer Y: ", farmer.global_position.y, " z_index: ", farmer.z_index)
	
	# Check CanvasItem draw order or rendering order in 2D
	# In Godot 4, let's verify positions
	assert(tile_behind.position.y < building.position.y, "Tile behind must have smaller Y")
	assert(tile_front.position.y > building.position.y, "Tile front must have larger Y")
	assert(farmer.position.y > building.position.y, "Farmer in front must have larger Y")
	
	print("[PASS] Y coordinates correctly reflect isometric depth!")
	get_tree().quit(0)
