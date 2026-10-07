@tool
extends SceneTree

func _init() -> void:
	var files := [
		"res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png",
		"res://assets/sprites/ground/GROUND-Bare/Bare1.png"
	]
	for path in files:
		var img := Image.new()
		img.load(path)
		var min_x: int = 9999
		var max_x: int = -1
		var min_y: int = 9999
		var max_y: int = -1
		for x in range(img.get_width()):
			for y in range(img.get_height()):
				if img.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
		print("%s (%dx%d): bbox x=[%d, %d], y=[%d, %d], w=%d, h=%d" % [
			path, img.get_width(), img.get_height(), min_x, max_x, min_y, max_y,
			(max_x - min_x + 1) if max_x >= 0 else 0,
			(max_y - min_y + 1) if max_y >= 0 else 0
		])
	quit(0)
