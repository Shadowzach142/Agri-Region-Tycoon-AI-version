extends SceneTree

func _init():
	var img = Image.load_from_file("C:/Users/ADMIN/.gemini/antigravity-ide/brain/2d912a7e-1d60-4cc4-ac48-537a84772546/.user_uploaded/media_1790730708990.png")
	# Let's find the grid lines in the grass around the tile.
	# The grid lines are dark green/brown lines drawn with Line2D on the ground:
	# border.default_color = Color(0.18, 0.28, 0.14, 0.45)
	# On top of grass, they create darker pixels.
	# Let's scan columns x=300 to 450, for y=300 to 360, and print pixel luminance or color.
	# Even better, let's find the bottom vertex of the grid tile itself!
	# The grass grid lines slope at 2:1 (dy/dx = 0.5).
	# Let's inspect the grass pixels to the left and right of y=330..350:
	for y in range(325, 345):
		var row = ""
		for x in range(330, 420):
			var c = img.get_pixel(x, y)
			# print a 1-char representation based on color
			# Brown slab:
			if c.r > c.g:
				row += "#"
			# Dark grid line (luminance lower than surrounding grass):
			elif c.g < 0.55 and c.g > 0.2:
				row += "+"
			else:
				row += "."
		print("y=%3d: %s" % [y, row])
	quit()
