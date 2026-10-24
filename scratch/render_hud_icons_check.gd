extends Node

func _ready() -> void:
	var mg_scene = load("res://scenes/MainGame.tscn")
	var mg = mg_scene.instantiate()
	add_child(mg)

	await get_tree().process_frame
	await get_tree().process_frame

	var img = get_viewport().get_texture().get_image()
	# Crop the bottom right corner (x: 1050 to 1280, y: 500 to 720)
	var crop_rect = Rect2i(1050, 500, 230, 220)
	var cropped = img.get_region(crop_rect)
	cropped.save_png("C:/Users/ADMIN/Documents/agri-region-ai-version/scratch/bottom_right_icons.png")
	print("✔ Saved cropped screenshot to scratch/bottom_right_icons.png")
	get_tree().quit()
