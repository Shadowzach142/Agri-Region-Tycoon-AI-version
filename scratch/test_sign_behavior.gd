extends Node

func _ready() -> void:
	print("--- Testing Parcel Sign Behavior on Land Purchase ---")
	
	var farm_grid_script = load("res://src/core/FarmGrid.gd")
	var farm_grid = Node2D.new()
	farm_grid.set_script(farm_grid_script)
	add_child(farm_grid)
	
	EconomyManager.cash = 100000
	
	print("Initial unlocked parcels: ", farm_grid.unlocked_parcels)
	print("Initial parcel_sign_nodes keys: ", farm_grid.parcel_sign_nodes.keys())
	for pid in farm_grid.parcel_sign_nodes.keys():
		var node = farm_grid.parcel_sign_nodes[pid]
		print("  Sign for %s: node valid=%s, parent=%s, name=%s" % [pid, is_instance_valid(node), node.get_parent().name if node.get_parent() else "none", node.name])
	
	# Check tile root children before unlocking
	var sign_tile = Data.get_parcel("east_meadows").get("sign_tile")
	var root = farm_grid.tile_roots[sign_tile.x][sign_tile.y]
	print("Root Tile_%d_%d children before unlock: %s" % [sign_tile.x, sign_tile.y, str(root.get_children().map(func(c): return c.name))])
	
	# Unlock east_meadows
	print("\nUnlocking east_meadows...")
	var success = farm_grid.unlock_parcel("east_meadows")
	print("Unlock success: ", success)
	print("unlocked_parcels after unlock: ", farm_grid.unlocked_parcels)
	print("parcel_sign_nodes keys after unlock: ", farm_grid.parcel_sign_nodes.keys())
	
	# Check children of root after unlock
	print("Root Tile_%d_%d children immediately after unlock: %s" % [sign_tile.x, sign_tile.y, str(root.get_children().map(func(c): return c.name))])
	
	# Wait for idle frame so queue_free() completes
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Root Tile_%d_%d children after process_frame: %s" % [sign_tile.x, sign_tile.y, str(root.get_children().map(func(c): return c.name))])
	
	# Check if any Signpost_ child remains
	var remaining_signs = root.find_children("*Signpost*", "", true, false)
	print("Remaining Signpost nodes on root: ", remaining_signs.size())
	
	get_tree().quit(0)
