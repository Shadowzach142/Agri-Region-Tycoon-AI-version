@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/ground/SAND/Sand-01.png")
	if img:
		print("Sand-01 corner (0,0): ", img.get_pixel(0, 0))
	var d_img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Drones.png")
	if d_img:
		print("Drones corner (0,0): ", d_img.get_pixel(0, 0))
	var s_img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if s_img:
		print("Sprinklers corner (0,0): ", s_img.get_pixel(0, 0))
	quit()
