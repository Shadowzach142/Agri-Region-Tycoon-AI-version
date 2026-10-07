@tool
extends SceneTree

func _init() -> void:
	var list := [
		"res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png",
		"res://assets/sprites/ground/GROUND-Bare/Bare1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P2.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P3.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P1.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P3.png"
	]
	for path in list:
		var img := Image.new()
		img.load(path)
		print("--- " + path.get_file() + " (%dx%d) ---" % [img.get_width(), img.get_height()])
		# print row opacity distribution
		for y in range(img.get_height()):
			var row_str := ""
			var count := 0
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.1:
					count += 1
			if count > 0:
				print("y=%2d: %2d pixels" % [y, count])
	quit(0)
