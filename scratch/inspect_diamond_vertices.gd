@tool
extends SceneTree

func _init() -> void:
	var list := [
		"res://assets/sprites/Field/Crops/Rice/RICE-P1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P2.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P3.png",
		"res://assets/sprites/Field/Crops/Banana/BANANA-P1.png",
		"res://assets/sprites/Field/Crops/Banana/BANANA-P4.png",
		"res://assets/sprites/Field/Crops/Coconut/COCONUT-P1.png",
		"res://assets/sprites/Field/Crops/Coconut/COCONUT-P3.png"
	]
	for path in list:
		var img := Image.new()
		img.load(path)
		print("=== %s (%dx%d) ===" % [path.get_file(), img.get_width(), img.get_height()])
		for y in range(img.get_height()):
			var min_x := 999
			var max_x := -1
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.1:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
			if max_x >= 0:
				print("y=%2d: x=[%2d, %2d] w=%2d" % [y, min_x, max_x, max_x - min_x + 1])
	quit(0)
