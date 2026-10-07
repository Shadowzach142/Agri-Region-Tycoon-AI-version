extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	if img:
		print("Image size: ", img.get_size())
		for y in range(img.get_height() - 10, img.get_height()):
			var row_pixels = []
			for x in range(img.get_width()):
				var c = img.get_pixel(x, y)
				if c.a > 0.05:
					row_pixels.append(Vector2i(x, y))
			if row_pixels.size() > 0:
				print("y=", y, " count=", row_pixels.size(), " min_x=", row_pixels[0].x, " max_x=", row_pixels[-1].x)
	quit()
