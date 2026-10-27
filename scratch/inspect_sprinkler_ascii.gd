@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if not img:
		quit()
		return
	
	print("--- FRAME 0 (11..56, Y=20..64) ---")
	for y in range(20, 64):
		var line := ""
		for x in range(11, 57):
			var a := img.get_pixel(x, y).a
			if a > 0.5:
				line += "X"
			else:
				line += "."
		print("%2d: %s" % [y, line])
	quit()
