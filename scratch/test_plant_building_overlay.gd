extends Node2D

func _ready() -> void:
	print("--- TEST PLANT OVERLAY VS BUILDING Y-SORT ---")
	var grid = Node2D.new()
	grid.y_sort_enabled = true
	add_child(grid)

	# 1. Tile A behind building at Y = 200
	var tile_behind = Node2D.new()
	tile_behind.name = "TileBehind"
	tile_behind.position = Vector2(500, 200)
	tile_behind.z_index = 10
	grid.add_child(tile_behind)

	# 2. Building at Y = 300
	var building = Node2D.new()
	building.name = "Building"
	building.position = Vector2(500, 300)
	building.z_index = 10  # Changed from 14 to 10
	grid.add_child(building)

	# 3. Tile B in front of building at Y = 400
	var tile_front = Node2D.new()
	tile_front.name = "TileFront"
	tile_front.position = Vector2(500, 400)
	tile_front.z_index = 10
	grid.add_child(tile_front)

	# Wait a frame to let Godot sort canvas items
	await get_tree().process_frame

	print("Children of grid: ")
	for ch in grid.get_children():
		print("  - %s at Y=%.1f (z_index=%d)" % [ch.name, ch.position.y, ch.z_index])

	print("✔ Test completed cleanly.")
	get_tree().quit(0)
