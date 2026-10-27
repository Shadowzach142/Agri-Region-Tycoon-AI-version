extends SceneTree

func _init() -> void:
	print("--- TESTING GODOT 4 NESTED Y-SORT DRAW ORDER ---")
	var root_node = Node2D.new()
	root_node.y_sort_enabled = true

	var grid = Node2D.new()
	grid.name = "FarmGrid"
	grid.y_sort_enabled = true
	root_node.add_child(grid)

	var tile_1 = Node2D.new()
	tile_1.name = "TileBehind"
	tile_1.position = Vector2(100, 100)
	grid.add_child(tile_1)

	var tile_2 = Node2D.new()
	tile_2.name = "TileFront"
	tile_2.position = Vector2(100, 500)
	grid.add_child(tile_2)

	var farmer = CharacterBody2D.new()
	farmer.name = "Farmer"
	farmer.position = Vector2(100, 300)
	root_node.add_child(farmer)

	# In Godot 4, RenderingServer canvas item sort:
	# grid has position (0, 0).
	# farmer has position (100, 300).
	# Because root_node sorts `grid` (Y=0) vs `farmer` (Y=300):
	# Does `grid` render all its children before `farmer`?
	# Let's inspect canvas item RIDs or draw order:
	print("Root y_sort: ", root_node.y_sort_enabled)
	print("Grid y_sort: ", grid.y_sort_enabled)
	quit(0)
