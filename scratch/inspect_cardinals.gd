@tool
extends SceneTree

func _init() -> void:
	var files := [
		"res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png",
		"res://assets/sprites/ground/GROUND-Bare/Bare1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P1.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P1.png",
		"res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P1.png",
		"res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P1.png"
	]
	for path in files:
		var img := Image.new()
		img.load(path)
		# find top-most pixel near center x=15..16
		var top_y := -1
		for y in range(img.get_height()):
			if img.get_pixel(15, y).a > 0.1 or img.get_pixel(16, y).a > 0.1:
				top_y = y
				break
		# find left-most pixel (x=0) y
		var left_y := -1
		for y in range(img.get_height()):
			if img.get_pixel(0, y).a > 0.1:
				left_y = y
				break
		# find right-most pixel (x=31) y
		var right_y := -1
		for y in range(img.get_height()):
			if img.get_pixel(31, y).a > 0.1:
				right_y = y
				break
		# find bottom-most pixel near center x=15..16
		var bot_y := -1
		for y in range(img.get_height() - 1, -1, -1):
			if img.get_pixel(15, y).a > 0.1 or img.get_pixel(16, y).a > 0.1:
				bot_y = y
				break
		print("%s:" % path.get_file())
		print("  top(x=15..16)=%d, left(x=0)=%d, right(x=31)=%d, bottom(x=15..16)=%d" % [
			top_y, left_y, right_y, bot_y
		])
	quit(0)
