@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P3.png")
	var min_y = 999
	var max_y = -1
	var min_x = 999
	var max_x = -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				if x < min_x: min_x = x
				if x > max_x: max_x = x
	print("Rice P3 bounds: X:[%d, %d], Y:[%d, %d], Image Size: %dx%d" % [min_x, max_x, min_y, max_y, img.get_width(), img.get_height()])
	quit(0)
