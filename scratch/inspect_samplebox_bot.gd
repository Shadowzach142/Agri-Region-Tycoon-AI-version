@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/StartMenu/samplebox1.png")
	for y in range(120, 144, 2):
		var line = "y=%3d: " % y
		for x in range(0, 256, 4):
			var c = img.get_pixel(x, y)
			if c.a < 0.1:
				line += " "
			elif c.r < 0.3:
				line += "#"
			elif c.r > 0.8:
				line += "."
			else:
				line += "-"
		print(line)
	quit()
