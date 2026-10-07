extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png")
	if img:
		print("LightGrass1 size: ", img.get_size())
		for y in range(img.get_height()):
			var min_x = -1
			var max_x = -1
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.05:
					if min_x == -1: min_x = x
					max_x = x
			if min_x != -1:
				print("LightGrass1 y=%2d: min_x=%2d, max_x=%2d, w=%2d" % [y, min_x, max_x, max_x - min_x + 1])
	quit()
