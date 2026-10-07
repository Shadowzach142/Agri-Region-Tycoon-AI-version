extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	print("--- RICE-P1.png Row-by-Row Width and Bounds ---")
	for y in range(img.get_height()):
		var min_x = -1
		var max_x = -1
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				if min_x == -1:
					min_x = x
				max_x = x
		if min_x != -1:
			var w = max_x - min_x + 1
			var center_x = float(min_x + max_x) / 2.0
			print("y=%2d: min_x=%2d, max_x=%2d, width=%2d, center_x=%.1f" % [y, min_x, max_x, w, center_x])
	quit()
