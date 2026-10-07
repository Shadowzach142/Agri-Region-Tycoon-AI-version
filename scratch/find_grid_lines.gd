extends SceneTree

func _init():
	var img = Image.load_from_file("res://scratch/crop_bottom.png")
	print("--- Finding grid line in crop_bottom.png ---")
	for y in range(img.get_height()):
		var grid_xs = []
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			# Grid line on grass is darker green:
			# Normal grass is ~ a8ca57 (r=0.66, g=0.79, b=0.34)
			# Grid line is darker green, e.g. g < 0.65 and g > 0.35 and g > r:
			if c.g > c.r and c.g < 0.68 and c.r < 0.55:
				grid_xs.append(x)
		if grid_xs.size() > 0:
			print("y=%2d: grid_xs=%s" % [y, str(grid_xs)])
	quit()
