@tool
extends SceneTree

func _init() -> void:
	var crops := [
		"res://assets/sprites/ground/GROUND-Bare/Bare1.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P1.png",
		"res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P1.png",
		"res://assets/sprites/Field/Crops/Coffee/COFFEE-P1.png",
		"res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P1.png"
	]
	for path in crops:
		var img := Image.new()
		img.load(path)
		print("=== %s ===" % path.get_file())
		for y in range(img.get_height()):
			var line := "%2d: " % y
			for x in range(img.get_width()):
				var c := img.get_pixel(x, y)
				if c.a < 0.1:
					line += " "
				else:
					line += "#"
			print(line)
	quit(0)
