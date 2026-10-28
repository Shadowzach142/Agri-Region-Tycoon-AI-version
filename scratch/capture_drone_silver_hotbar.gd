# capture_drone_silver_hotbar.gd
extends Node

func _ready() -> void:
	print("--- CAPTURING SILVER DRONE HOTBAR & LEVEL GATING ---")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game = main_scene.instantiate()
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = game.find_child("FarmGrid", true, false)
	var hotbar = game.find_child("PlantHotbar", true, false)

	# Clean slate
	BuildingManager.placed_buildings.clear()

	# 1. Place a Drone Landing Pad (gives 1 drone, baseline Lv.1)
	var pad: Node2D = Node2D.new()
	pad.set_script(load("res://src/buildings/Building.gd"))
	pad.building_type = "drone_pad"
	pad.state = pad.BuildingState.ACTIVE
	pad.level = 1
	pad.position = FarmerMovement.grid_to_pixel_center(Vector2i(6, 4), farm_grid)
	farm_grid.add_child(pad)
	BuildingManager.register_building(pad)

	farm_grid._sync_drones()
	assert(farm_grid.drones.size() >= 1, "Expected at least 1 drone")

	# Wait for rendering
	await get_tree().process_frame
	await get_tree().process_frame

	# Ensure we start in Worker mode: select a farmer
	var workers := get_tree().get_nodes_in_group("farmers")
	if not workers.is_empty():
		farm_grid.deselect_all_drones()
		TaskManager.select_farmer(workers[0])
	hotbar._update_visibility_from_selection()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Capture Screen 1: Worker Mode (Wood theme)
	var img_worker = get_viewport().get_texture().get_image()
	img_worker.save_png("res://scratch/capture_worker_wood_hotbar.png")
	print("Saved scratch/capture_worker_wood_hotbar.png")

	# Switch to Drone Mode (Hangar is NOT built yet -> Lv.1 via landing pad)
	TaskManager.deselect_all_farmers()
	farm_grid.select_drone_by_index(1)
	hotbar._update_visibility_from_selection()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Capture Screen 2: Drone Mode Lv.1 (Silver theme, Seeds locked with padlock)
	var img_drone_lv1 = get_viewport().get_texture().get_image()
	img_drone_lv1.save_png("res://scratch/capture_drone_lv1_silver_hotbar.png")
	print("Saved scratch/capture_drone_lv1_silver_hotbar.png")

	# Open slot 2 flyout to show locked directives (Plant, Harvest, Auto Farm locked at Lv.1)
	hotbar._open_flyout_for_category("tools")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Capture Screen 3: Drone Mode Lv.1 with Actions Flyout open
	var img_drone_flyout = get_viewport().get_texture().get_image()
	img_drone_flyout.save_png("res://scratch/capture_drone_flyout_lv1.png")
	print("Saved scratch/capture_drone_flyout_lv1.png")

	# Close flyout
	hotbar._close_flyout()

	# Now construct Drone Command Hangar at Level 2!
	var hangar: Node2D = Node2D.new()
	hangar.set_script(load("res://src/buildings/Building.gd"))
	hangar.building_type = "drone_station"
	hangar.state = hangar.BuildingState.ACTIVE
	hangar.level = 2
	hangar.position = FarmerMovement.grid_to_pixel_center(Vector2i(8, 4), farm_grid)
	farm_grid.add_child(hangar)
	BuildingManager.register_building(hangar)

	# Trigger hotbar refresh for drone 1
	farm_grid.select_drone_by_index(1)
	hotbar._update_visibility_from_selection()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Capture Screen 4: Drone Mode Lv.2 (Silver theme, Seeds UNLOCKED and showing palay seed)
	var img_drone_lv2 = get_viewport().get_texture().get_image()
	img_drone_lv2.save_png("res://scratch/capture_drone_lv2_silver_hotbar.png")
	print("Saved scratch/capture_drone_lv2_silver_hotbar.png")

	print("--- VISUAL CAPTURE COMPLETED SUCCESSFULLY! ---")
	get_tree().quit(0)
