extends Node

func _ready() -> void:
	print("--- Rendering All BuildingCardPopup Types ---")
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.22, 0.14)
	vp.add_child(bg)

	var popup_scene = load("res://scenes/BuildingCardPopup.tscn")
	assert(popup_scene != null)
	var popup = popup_scene.instantiate() as BuildingCardPopup
	vp.add_child(popup)

	# Mock building node
	var mock_building = Node2D.new()
	mock_building.set_script(load("res://src/buildings/Building.gd"))
	mock_building.state = mock_building.BuildingState.ACTIVE
	mock_building.level = 1
	mock_building.max_level = 3
	vp.add_child(mock_building)

	var test_types = [
		{"type": "bodega", "name": "silo_card"},
		{"type": "cold_storage", "name": "cold_storage_card"},
		{"type": "rice_mill", "name": "rice_mill_card"},
		{"type": "water_tower", "name": "water_tower_card"},
		{"type": "drone_station", "name": "drone_station_card"},
		{"type": "bayanihan_center", "name": "bayanihan_card"},
		{"type": "weather_station", "name": "weather_station_card"},
		{"type": "solar_dryer", "name": "solar_dryer_card"},
		{"type": "bahay_kubo", "name": "bahay_kubo_card"}
	]

	for item in test_types:
		mock_building.building_type = item.type
		mock_building.level = 1
		mock_building.used_storage = 60 if item.type in ["bodega", "cold_storage"] else 0
		if item.type == "bodega":
			mock_building.assigned_crops = ["palay", "yellow_corn", "sugarcane"]
		else:
			mock_building.assigned_crops = []

		popup.open_for_building(mock_building)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var img = vp.get_texture().get_image()
		if img:
			var out_path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/%s.png" % item.name
			img.save_png(out_path)
			print("Saved screenshot: %s" % out_path)

	print("All visual test renders completed successfully!")
	get_tree().quit(0)
