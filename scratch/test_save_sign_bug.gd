extends Node

func _ready() -> void:
	print("--- Simulating Save/Load Signpost Duplication Bug ---")
	
	# Step 1: Create a save where east_meadows is bought
	var fake_save_data = {
		"meta": {"region_key": "cotabato", "game_mode": "career", "day": 1, "title": "Test Save"},
		"farm_grid": {
			"unlocked_parcels": ["homestead", "east_meadows"],
			"tiles": []
		}
	}
	SaveManager.pending_save_data = fake_save_data
	
	# Step 2: Now instantiate FarmGrid (which happens when MainGame loads)
	var farm_grid_script = load("res://src/core/FarmGrid.gd")
	var farm_grid = Node2D.new()
	farm_grid.set_script(farm_grid_script)
	add_child(farm_grid)
	
	# Let's inspect tile_roots[14][2] (sign_tile for east_meadows)
	var root_east = farm_grid.tile_roots[14][2]
	var signs_east = []
	for c in root_east.get_children():
		if "Signpost" in c.name:
			signs_east.append(c.name)
	
	print("East Meadows is unlocked in save: ", farm_grid.unlocked_parcels.has("east_meadows"))
	print("Signs found on East Meadows tile root (14, 2): ", signs_east)
	
	# Also inspect south_plains (which was NOT unlocked)
	var root_south = farm_grid.tile_roots[2][14]
	var signs_south = []
	for c in root_south.get_children():
		if "Signpost" in c.name:
			signs_south.append(c.name)
	print("Signs found on South Plains tile root (2, 14): ", signs_south)
	
	if signs_east.size() > 0:
		print("FAIL: East Meadows sign is STILL on the tile even though East Meadows was bought!")
	else:
		print("SUCCESS: East Meadows has 0 signs after loading save!")
	
	if signs_south.size() == 1:
		print("SUCCESS: South Plains has exactly 1 sign after loading save!")
	else:
		print("FAIL: South Plains sign count is %d (expected 1)" % signs_south.size())
	
	assert(signs_east.size() == 0, "East Meadows must have 0 signs when loaded as unlocked")
	assert(signs_south.size() == 1, "South Plains must have exactly 1 sign when loaded as locked")

	# Test unlocking South Plains live
	print("\nUnlocking South Plains live...")
	EconomyManager.cash = 100000
	var success = farm_grid.unlock_parcel("south_plains")
	assert(success, "Unlocking South Plains should succeed")
	
	var signs_south_after = []
	for c in root_south.get_children():
		if "Signpost" in c.name and is_instance_valid(c) and not c.is_queued_for_deletion():
			signs_south_after.append(c.name)
	print("Signs found on South Plains tile root after purchase: ", signs_south_after)
	assert(signs_south_after.size() == 0, "South Plains must have 0 signs after purchase")
	print("SUCCESS: All assertions passed!")
	
	get_tree().quit(0)
