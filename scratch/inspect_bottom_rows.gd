@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/StartMenu/long-rectangle.png")
	var sub = img.get_region(Rect2i(101, 47, 191, 47))
	# Print rows 30 to 46
	for y in range(25, 47):
		var line = "y=" + str(y) + ": "
		for x in range(0, 191, 4):
			var a = sub.get_pixel(x, y).a
			var c = sub.get_pixel(x, y)
			if a < 0.1:
				line += " "
			elif c.r < 0.2:
				line += "#"
			else:
				line += "."
		print(line)
	quit()
