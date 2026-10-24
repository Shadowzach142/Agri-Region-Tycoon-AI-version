@tool
extends SceneTree

func _init():
	var root_2d = Node2D.new()
	root_2d.y_sort_enabled = true
	
	var grid = Node2D.new()
	grid.name = "FarmGrid"
	grid.y_sort_enabled = true
	root_2d.add_child(grid)
	
	# TileNorth at Y=100, extends down to Y=400 (drawn as a 100x300 rect)
	var tile_north = ColorRect.new()
	tile_north.name = "TileNorth"
	tile_north.position = Vector2(0, 100)
	tile_north.size = Vector2(100, 300) # Reaches Y=400!
	tile_north.color = Color.GREEN
	grid.add_child(tile_north)
	
	# Farmer at Y=200, extends down to Y=250 (drawn as 100x50 rect)
	var farmer = ColorRect.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(0, 200)
	farmer.size = Vector2(100, 50)
	farmer.color = Color.RED
	root_2d.add_child(farmer)
	
	# In theory:
	# TileNorth has Y=100.
	# Farmer has Y=200.
	# If Y-sorted: Farmer (Y=200) should be drawn ON TOP of TileNorth (Y=100)!
	# That means at Y=220, the color should be RED!
	# But if Y-sorting is broken (because grid is a separate parent):
	# What happens?
	root.add_child(root_2d)
	
	print("Created test scene...")
	quit(0)
