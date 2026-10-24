extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(scene)
	scene._show_region_select()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/region_screen.png")
	print("Region screen captured!")
	quit(0)
