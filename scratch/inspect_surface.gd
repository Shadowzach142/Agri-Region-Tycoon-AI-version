extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	# Let's inspect the colors across rows 16 to 25
	# On the top surface, there is soil and blue water puddles (e.g. blue pixels) and green seedlings.
	# On the side slab, it is solid dark brown vertical earth!
	for y in range(16, 26):
		var num_blue = 0
		var num_green = 0
		var num_brown = 0
		for x in range(32):
			var c = img.get_pixel(x, y)
			if c.a > 0.05:
				if c.b > 0.6 and c.b > c.r:
					num_blue += 1
				elif c.g > 0.5 and c.g > c.r:
					num_green += 1
				else:
					num_brown += 1
		print("y=%2d: blue=%2d, green=%2d, brown=%2d" % [y, num_blue, num_green, num_brown])
	quit()
