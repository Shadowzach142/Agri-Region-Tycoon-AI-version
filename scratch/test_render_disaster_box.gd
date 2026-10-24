extends Node2D

func _ready() -> void:
	var mg_scene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)
	
	var disaster_box = mg.find_child("DisasterBox", true, false) as Control
	disaster_box.visible = true
	disaster_box.modulate = Color(1, 1, 1, 1)
	
	var title = disaster_box.find_child("TitleLabel", true, false) as Label
	var sub = disaster_box.find_child("SubLabel", true, false) as Label
	title.text = "☀️ EL NIÑO"
	title.add_theme_color_override("font_color", Color(0.85, 0.40, 0.12, 1.0))
	sub.text = "Severe heatwave • Irrigate crops"
	sub.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1.0))
	
	# wait 2 frames then capture
	await get_tree().process_frame
	await get_tree().process_frame
	
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	# crop disaster box rect
	var global_pos = disaster_box.global_position
	var size = disaster_box.size
	print("DisasterBox global_pos:", global_pos, "size:", size)
	
	var rect = Rect2i(int(global_pos.x) - 10, int(global_pos.y) - 10, int(size.x) + 20, int(size.y) + 20)
	var cropped = img.get_region(rect)
	cropped.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/capture_disaster_box.png")
	print("Saved capture_disaster_box.png successfully!")
	get_tree().quit(0)
