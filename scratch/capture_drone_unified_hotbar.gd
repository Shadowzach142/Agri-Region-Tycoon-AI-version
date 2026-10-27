# capture_drone_unified_hotbar.gd
# Captures visual proof of the unified hotbar drone controls and strict highlight isolation.
extends Node

func _ready() -> void:
	print("--- CAPTURING UNIFIED DRONE HOTBAR & HIGHLIGHT ISOLATION ---")
	call_deferred("_run_capture")

func _run_capture() -> void:
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game = main_scene.instantiate()
	add_child(game)

	await get_tree().process_frame
	await get_tree().process_frame

	var farm_grid = game.find_child("FarmGrid", true, false)
	var hud = game.find_child("HUDLayer", true, false)
	var hotbar = game.find_child("PlantHotbar", true, false)

	# 1. Commission 2 Drone Landing Pads (Pad 1: Lv.2, Pad 2: Lv.1)
	var pad1: Node2D = Node2D.new()
	pad1.set_script(load("res://src/buildings/Building.gd"))
	pad1.building_type = "drone_pad"
	pad1.state = pad1.BuildingState.ACTIVE
	pad1.level = 2
	pad1.position = FarmerMovement.grid_to_pixel_center(Vector2i(6, 4), farm_grid)
	farm_grid.add_child(pad1)
	BuildingManager.register_building(pad1)

	var pad2: Node2D = Node2D.new()
	pad2.set_script(load("res://src/buildings/Building.gd"))
	pad2.building_type = "drone_pad"
	pad2.state = pad2.BuildingState.ACTIVE
	pad2.level = 1
	pad2.position = FarmerMovement.grid_to_pixel_center(Vector2i(6, 7), farm_grid)
	farm_grid.add_child(pad2)
	BuildingManager.register_building(pad2)

	farm_grid._sync_drones()
	assert(farm_grid.drones.size() >= 2, "Need at least 2 drones")

	var d1: FarmDrone = farm_grid.drones[0]
	var d2: FarmDrone = farm_grid.drones[1]

	# Deploy Drone 1 to Field A (Palay)
	var zone_a: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
		Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)
	]
	d1.deploy(zone_a, "palay")
	d1.job = {"type": "plant", "pos": Vector2i(2, 3), "fp": Vector2i(1, 1), "crop": "palay"}
	d1.state = FarmDrone.State.WORKING

	# Deploy Drone 2 to Field B (Corn)
	var zone_b: Array[Vector2i] = [
		Vector2i(2, 6), Vector2i(2, 7), Vector2i(2, 8),
		Vector2i(3, 6), Vector2i(3, 7), Vector2i(3, 8)
	]
	d2.deploy(zone_b, "yellow_corn")
	d2.job = {"type": "plow", "pos": Vector2i(3, 7), "fp": Vector2i(1, 1)}
	d2.state = FarmDrone.State.WORKING

	# Select Drone 1
	farm_grid.select_drone_by_index(1)
	await get_tree().process_frame
	await get_tree().process_frame

	# Ensure queue_redraw happened
	if d1._zone_layer: d1._zone_layer.queue_redraw()
	if d2._zone_layer: d2._zone_layer.queue_redraw()

	await RenderingServer.frame_post_draw

	# Capture Screen 1: Drone 1 Selected (Hotbar shows Drone #1 with crop/modes; Field A is highlighted; Field B has NO highlights!)
	var img1 = get_viewport().get_texture().get_image()
	img1.save_png("res://scratch/capture_drone1_selected.png")
	print("Saved scratch/capture_drone1_selected.png")

	# Select Drone 2
	farm_grid.select_drone_by_index(2)
	await get_tree().process_frame
	await get_tree().process_frame

	if d1._zone_layer: d1._zone_layer.queue_redraw()
	if d2._zone_layer: d2._zone_layer.queue_redraw()

	await RenderingServer.frame_post_draw

	# Capture Screen 2: Drone 2 Selected (Hotbar shows Drone #2; Field B is highlighted; Field A has NO highlights!)
	var img2 = get_viewport().get_texture().get_image()
	img2.save_png("res://scratch/capture_drone2_selected.png")
	print("Saved scratch/capture_drone2_selected.png")

	# Switch to human workers
	hotbar._on_switch_unit_type()
	await get_tree().process_frame
	await get_tree().process_frame

	if d1._zone_layer: d1._zone_layer.queue_redraw()
	if d2._zone_layer: d2._zone_layer.queue_redraw()

	await RenderingServer.frame_post_draw

	# Capture Screen 3: Worker Selected (Hotbar shows Worker 1; NO drone fields highlighted!)
	var img3 = get_viewport().get_texture().get_image()
	img3.save_png("res://scratch/capture_worker_selected.png")
	print("Saved scratch/capture_worker_selected.png")

	print("--- CAPTURE COMPLETED SUCCESSFULLY! ---")
	get_tree().quit(0)
