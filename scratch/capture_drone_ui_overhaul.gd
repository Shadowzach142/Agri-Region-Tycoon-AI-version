extends Node

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main_scene)

	await get_tree().process_frame
	await get_tree().process_frame

	# 1. Commission Lv.2 Hangar and Drone Landing Pad
	var b_script = load("res://src/buildings/Building.gd")
	var drone_station = Node2D.new()
	drone_station.set_script(b_script)
	drone_station.building_type = "drone_station"
	drone_station.level = 2
	drone_station.state = 1
	drone_station.grid_pos = Vector2i(2, 2)
	BuildingManager.register_building(drone_station)

	var drone_pad = Node2D.new()
	drone_pad.set_script(b_script)
	drone_pad.building_type = "drone_pad"
	drone_pad.level = 2
	drone_pad.state = 1
	drone_pad.grid_pos = Vector2i(4, 2)
	BuildingManager.register_building(drone_pad)

	var farm_grid = main_scene.find_child("FarmGrid", true, false)
	farm_grid._sync_drones()

	var hud = main_scene.find_child("HUDLayer", true, false)
	var qbar: DroneQuickBar = hud.find_child("DroneQuickBar", true, false)
	var deck: DroneCommandDeck = hud.find_child("DroneCommandDeck", true, false)

	# Select farmer to show worker hotbar with strictly 3 slots
	var farmers = get_tree().get_nodes_in_group("farmers")
	if not farmers.is_empty():
		TaskManager.select_farmer(farmers[0])

	# Capture 1: Drone QuickBar Capsule Pill at Level 2 (with Crop Flyout Open)
	qbar.show_for_drone()
	deck.visible = false
	qbar._on_crop_btn_pressed() # open sleek flyout

	await get_tree().process_frame
	await get_tree().process_frame

	var img1 = get_viewport().get_texture().get_image()
	img1.save_png("res://scratch/drone_quickbar_lv2.png")
	print("CAPTURE_SAVED: res://scratch/drone_quickbar_lv2.png")

	# Capture 2: Drone QuickBar Capsule Pill (Closed flyout, compact floating pill)
	qbar._crop_popup_panel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame

	var img2 = get_viewport().get_texture().get_image()
	img2.save_png("res://scratch/drone_quickbar_lv1.png")
	print("CAPTURE_SAVED: res://scratch/drone_quickbar_lv1.png")

	# Capture 3: Drone Command Deck at Level 2
	deck.open()
	await get_tree().process_frame
	await get_tree().process_frame

	var img3 = get_viewport().get_texture().get_image()
	img3.save_png("res://scratch/drone_deck_lv1.png")
	print("CAPTURE_SAVED: res://scratch/drone_deck_lv1.png")

	get_tree().quit(0)
