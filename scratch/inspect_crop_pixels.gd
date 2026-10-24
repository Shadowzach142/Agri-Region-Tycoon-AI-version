@tool
extends SceneTree

func _init():
	var crops = [
		"res://assets/sprites/Field/Crops/Rice/RICE-P1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P2.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P3.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P3.png",
		"res://assets/sprites/Field/Crops/Banana/BANANA-P4.png"
	]
	for p in crops:
		var img = Image.load_from_file(p)
		var w = img.get_width()
		var h = img.get_height()
		# Find bottom-most non-transparent pixel
		var bottom_y = -1
		var min_x = w
		var max_x = -1
		for y in range(h - 1, -1, -1):
			for x in range(w):
				if img.get_pixel(x, y).a > 0.05:
					if bottom_y == -1:
						bottom_y = y
					min_x = min(min_x, x)
					max_x = max(max_x, x)
		print("%s: size %dx%d, bottom_non_alpha_y=%d (dist from bot=%d), x_range=[%d, %d] (mid=%d, img_mid=%d)" % [
			p.get_file(), w, h, bottom_y, h - 1 - bottom_y, min_x, max_x, (min_x + max_x) / 2, w / 2
		])
	quit(0)
