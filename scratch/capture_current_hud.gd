@tool
extends SceneTree

func _init() -> void:
	var main_scene = load("res://scenes/MainGame.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)

	# Wait a frame for layout
	await process_frame
	await process_frame

	var img = root.get_texture().get_image()
	img.save_png("C:/Users/ADMIN/Documents/agri-region-ai-version/scratch/current_hud_screenshot.png")
	print("Saved screenshot to scratch/current_hud_screenshot.png")
	quit()
