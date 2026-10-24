@tool
extends SceneTree

func _init():
	var root_2d = Node2D.new()
	root_2d.y_sort_enabled = true
	
	var grid = Node2D.new()
	grid.name = "FarmGrid"
	grid.y_sort_enabled = true
	grid.z_index = 0
	root_2d.add_child(grid)
	
	var tile_north = Sprite2D.new()
	tile_north.name = "TileNorth"
	tile_north.position = Vector2(100, 100)
	tile_north.z_index = 10
	grid.add_child(tile_north)
	
	var tile_south = Sprite2D.new()
	tile_south.name = "TileSouth"
	tile_south.position = Vector2(100, 500)
	tile_south.z_index = 10
	grid.add_child(tile_south)
	
	var farmer = CharacterBody2D.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(100, 300)
	farmer.z_index = 10
	root_2d.add_child(farmer)
	
	root.add_child(root_2d)
	
	# Let's inspect CanvasItem draw order in Godot
	print("Testing draw order...")
	# In Godot 4, let's see how CanvasItem rendering treats this
	# Let's check RenderingServer
	print("grid.is_y_sort_enabled():", grid.is_y_sort_enabled())
	print("farmer z_index:", farmer.z_index)
	print("tile_north z_index:", tile_north.z_index)
	quit(0)
