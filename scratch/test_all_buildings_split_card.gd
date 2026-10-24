extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.22, 0.14)
	vp.add_child(bg)

	# Test rendering multiple building types
	var building_types = ["bodega", "rice_mill", "water_tower", "drone_station", "weather_station"]
	for b_type in building_types:
		var b_data = Data.get_building(b_type)
		print("Found building data for: ", b_type, " -> ", b_data.get("display_name", ""))
	
	get_tree().quit(0)
