extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png")
	for y in range(img.get_height()):
		var line = ""
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a < 0.1:
				line += " "
			else:
				line += "."
		if line.strip_edges() != "":
			print("y=%2d: %s" % [y, line])
	quit()
