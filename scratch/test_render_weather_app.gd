extends Node2D

func _ready() -> void:
	var mg_scene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)
	
	# Simulate placed weather station Lv.2
	var b_script = load("res://src/buildings/Building.gd")
	var dummy_station = b_script.new()
	dummy_station.building_type = "weather_station"
	dummy_station.level = 2
	dummy_station.state = dummy_station.BuildingState.ACTIVE
	BuildingManager.register_building(dummy_station)
	
	var weather_app = mg.find_child("WeatherAppModal", true, false)
	if weather_app == null:
		var wa_script = load("res://src/ui/WeatherAppModal.gd")
		weather_app = wa_script.new()
		mg.add_child(weather_app)
	
	weather_app.open_for_station(dummy_station)
	weather_app.refresh()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	
	var panel = weather_app._main_panel
	var global_pos = panel.global_position
	var size = panel.size
	
	var rect = Rect2i(int(global_pos.x) - 10, int(global_pos.y) - 10, int(size.x) + 20, int(size.y) + 20)
	var cropped = img.get_region(rect)
	cropped.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/capture_weather_app_station_lv2.png")
	print("Saved capture_weather_app_station_lv2.png successfully!")
	get_tree().quit(0)
