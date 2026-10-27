extends Node

func _ready() -> void:
	print("--- Testing Sign Removal in Live MainGame Scene ---")
	
	# Ensure no pending save data
	SaveManager.pending_save_data = {}
	
	var main_game_scene = load("res://scenes/MainGame.tscn")
	var main_game = main_game_scene.instantiate()
	add_child(main_game)
	
	var farm_grid = main_game.find_child("FarmGrid", true, false)
	assert(farm_grid != null, "FarmGrid must exist in MainGame")
	
	EconomyManager.cash = 100000
	
	print("Initial unlocked_parcels: ", farm_grid.unlocked_parcels)
	var sign_tile = Data.get_parcel("east_meadows").get("sign_tile")
	var root = farm_grid.tile_roots[sign_tile.x][sign_tile.y]
	
	var signs_before = []
	for c in root.get_children():
		if "Signpost" in c.name:
			signs_before.append(c)
	print("Signs before purchase on tile (%d, %d): count=%d" % [sign_tile.x, sign_tile.y, signs_before.size()])
	assert(signs_before.size() == 1, "Should have exactly 1 sign before purchase")
	
	# Simulate clicking the sign button to open modal
	var sign_container = signs_before[0]
	var btn = null
	for c in sign_container.get_children():
		if c is Button:
			btn = c
			break
	assert(btn != null, "Sign container must have a Button child")
	print("Found sign button with text: \n", btn.text)
	
	# Click the sign button
	print("Clicking sign button...")
	btn.pressed.emit()
	
	var land_modal = farm_grid.land_modal
	assert(land_modal != null, "Land modal must exist")
	print("Land modal visible: ", land_modal.visible)
	print("Land modal current_parcel_id: ", land_modal.current_parcel_id)
	
	# Click unlock button in modal
	print("Clicking modal unlock button...")
	land_modal._on_unlock_pressed()
	
	print("After purchase, unlocked_parcels: ", farm_grid.unlocked_parcels)
	print("Land modal visible: ", land_modal.visible)
	
	# Let frames process
	await get_tree().process_frame
	await get_tree().process_frame
	
	var signs_after = []
	for c in root.get_children():
		if "Signpost" in c.name and is_instance_valid(c) and not c.is_queued_for_deletion():
			signs_after.append(c)
	print("Signs after purchase on tile (%d, %d): count=%d" % [sign_tile.x, sign_tile.y, signs_after.size()])
	
	# Also check all children of root
	print("All children on root: ", root.get_children().map(func(c): return "%s (valid=%s, queued=%s)" % [c.name, is_instance_valid(c), c.is_queued_for_deletion()]))
	
	get_tree().quit(0)
