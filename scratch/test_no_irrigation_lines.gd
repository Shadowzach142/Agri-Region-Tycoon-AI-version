extends Node

func _ready() -> void:
	print("--- BEGIN TEST: VERIFY NO PIPE / LINE OVERLAYS ON TILES WITH WATER TOWER ---")

	var b_class = load("res://src/buildings/Building.gd")
	var tower = b_class.new()
	tower.building_type = "water_tower"
	tower.state = tower.BuildingState.ACTIVE
	tower.level = 1
	tower.grid_pos = Vector2i(0, 0)
	BuildingManager.register_building(tower)

	assert(BuildingManager.has_irrigation() == true, "FAIL: has_irrigation should be true with active water tower")

	var renderer = TileRenderer.new()

	# Test 1: Direct call to _draw_drip_irrigation_lines should produce zero child nodes
	var dummy_overlay = Node2D.new()
	var test_tile = FarmTile.new()
	test_tile.state = FarmTile.TileState.PLOWED
	renderer._draw_drip_irrigation_lines(dummy_overlay, test_tile)
	assert(dummy_overlay.get_child_count() == 0, "FAIL: _draw_drip_irrigation_lines must produce 0 children")
	print("✓ Test 1 Passed: _draw_drip_irrigation_lines adds 0 children")

	# Test 2: Growing crop tile also produces 0 drip line children
	test_tile.state = FarmTile.TileState.GROWING
	test_tile.crop_type = "palay"
	renderer._draw_drip_irrigation_lines(dummy_overlay, test_tile)
	assert(dummy_overlay.get_child_count() == 0, "FAIL: _draw_drip_irrigation_lines must produce 0 children for GROWING")
	print("✓ Test 2 Passed: _draw_drip_irrigation_lines produces 0 children for GROWING crop")

	# Test 3: Level 3 Solar Drip network also produces 0 pipe lines
	tower.level = 3
	renderer._draw_drip_irrigation_lines(dummy_overlay, test_tile)
	assert(dummy_overlay.get_child_count() == 0, "FAIL: Level 3 must produce 0 pipe lines")
	print("✓ Test 3 Passed: Level 3 pump tower produces 0 pipe lines")

	# Cleanup
	BuildingManager.unregister_building(tower)
	tower.queue_free()
	dummy_overlay.queue_free()

	print("--- ALL TESTS PASSED: PIPE/LINE OVERLAYS REMOVED ---")
	get_tree().quit(0)
