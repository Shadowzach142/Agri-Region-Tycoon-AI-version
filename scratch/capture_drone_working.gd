extends Node

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main_scene)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Commission a drone and Lv.3 hangar
	var b_script = load("res://src/buildings/Building.gd")
	var drone_station = Node2D.new()
	drone_station.set_script(b_script)
	drone_station.building_type = "drone_station"
	drone_station.level = 3
	drone_station.state = 1
	drone_station.grid_pos = Vector2i(2, 2)
	BuildingManager.register_building(drone_station)
	BuildingManager.active_drones = 1
	BuildingManager.active_workers = 1
	
	var farm_grid = main_scene.find_child("FarmGrid", true, false)
	farm_grid._sync_drones()
	
	# Set up a parched plot at (4,4) so drone flies and sprays water
	var tile = farm_grid.get_tile(Vector2i(4, 4))
	tile.state = FarmTile.TileState.GROWING
	tile.crop_type = "palay"
	tile.soil_moisture = 20.0
	tile.growth_progress = 0.5
	farm_grid.renderer.update_tile(Vector2i(4, 4), farm_grid.tiles)
	
	# Deploy drone to whole farm
	if farm_grid.drone:
		farm_grid.drone.deploy_whole_farm("palay")
		# Move drone directly to working state on the parched plot to capture the hydration beam and spray
		farm_grid.drone.job = {"type": "water", "pos": Vector2i(4, 4), "fp": Vector2i(1, 1), "crop": "palay"}
		farm_grid.drone.state = FarmDrone.State.WORKING
		farm_grid.drone.position = farm_grid.drone._job_target_local(farm_grid.drone.job)
	
	# Wait 5 frames for rendering
	for i in range(5):
		await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://scratch/drone_working_capture.png")
	print("CAPTURE_SAVED: res://scratch/drone_working_capture.png")
	get_tree().quit(0)
