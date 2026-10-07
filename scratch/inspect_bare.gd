extends SceneTree

func _init():
	for i in range(1, 5):
		var path = "res://assets/sprites/ground/GROUND-Bare/Bare%d.png" % i
		var img = Image.load_from_file(path)
		if img:
			print("=== Bare", i, " size: ", img.get_size(), " ===")
			for y in range(img.get_height() - 10, img.get_height()):
				var row_pixels = []
				for x in range(img.get_width()):
					var c = img.get_pixel(x, y)
					if c.a > 0.05:
						row_pixels.append(x)
				if row_pixels.size() > 0:
					print("y=", y, " count=", row_pixels.size(), " min_x=", row_pixels[0], " max_x=", row_pixels[-1])
	quit()
