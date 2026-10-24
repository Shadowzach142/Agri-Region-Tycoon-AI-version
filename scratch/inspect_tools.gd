@tool
extends SceneTree

func print_ascii(path: String, title: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if not img:
		print("Fail to load ", path)
		return
	print("=== ", title, " (", img.get_width(), "x", img.get_height(), ") ===")
	for y in range(img.get_height()):
		var line = ""
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a < 0.1:
				line += " "
			elif c.r > 0.8 and c.g > 0.8:
				line += "#"
			elif c.r > 0.6:
				line += "@"
			elif c.g > 0.6:
				line += "%"
			elif c.b > 0.6:
				line += "~"
			else:
				line += "."
		# only print line if not completely empty
		if line.strip_edges() != "":
			print(line)

func _init() -> void:
	print_ascii("res://assets/icons/Tools/Market.png", "Market.png")
	print_ascii("res://assets/icons/Tools/Basket.png", "Basket.png")
	print_ascii("res://assets/icons/Tools/Pick.png", "Pick.png")
	print_ascii("res://assets/icons/Tools/watering.png", "watering.png")
	quit()
