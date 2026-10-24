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
	
	# Deploy whole farm patrol
	if farm_grid.drone:
		farm_grid.drone.deploy_whole_farm("palay")
	
	# Open drone command deck
	var hud = main_scene.find_child("HUDLayer", true, false)
	var deck = hud.find_child("DroneCommandDeck", true, false)
	deck.open()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://scratch/drone_deck_capture.png")
	print("CAPTURE_SAVED: res://scratch/drone_deck_capture.png")
	get_tree().quit(0)
