@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("scratch/menu_final_preview.png")
	if not img:
		quit()
	# Scan X: 500..600, Y: 130..170
	for y in range(130, 160, 2):
		var line = "y=" + str(y) + ": "
		for x in range(500, 600, 5):
			var c = img.get_pixel(x, y)
			line += "#" if (c.r < 0.25 and c.g < 0.25 and c.b < 0.25) else "."
		print(line)
	quit()
