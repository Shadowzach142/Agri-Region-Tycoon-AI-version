extends SceneTree

func _init() -> void:
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/ground/NGRASS/NGRASS-01.png"))
	var min_y := 999
	var max_y := -1
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			if img.get_pixel(x, y).a > 0.05:
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	print("NGRASS-01 Y bounds: [%d..%d]" % [min_y, max_y])
	quit(0)
