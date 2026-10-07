extends SceneTree

func _init():
	var img = Image.load_from_file("res://scratch/crop_bottom.png")
	for y in range(40, 75):
		var line = ""
		for x in range(35, 65):
			var c = img.get_pixel(x, y)
			line += "%s " % c.to_html(false)
		print("y=%2d: %s" % [y, line])
	quit()
