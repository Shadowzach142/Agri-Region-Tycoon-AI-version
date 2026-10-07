extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	for y in range(18, 32):
		var line = ""
		for x in range(32):
			var c = img.get_pixel(x, y)
			if c.a < 0.1:
				line += " "
			else:
				line += "#"
		print("y=%2d: %s" % [y, line])
	quit()
