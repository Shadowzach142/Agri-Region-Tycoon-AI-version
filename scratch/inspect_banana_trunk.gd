@tool
extends SceneTree

func _init() -> void:
	for i in range(1, 7):
		var p := "res://assets/sprites/Field/Crops/Banana/BANANA-P%d.png" % i
		var img := Image.new()
		img.load(p)
		var last_y := img.get_height() - 1
		var min_x := 999
		var max_x := -1
		for x in range(img.get_width()):
			if img.get_pixel(x, last_y).a > 0.1:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
		var center_x := (min_x + max_x) / 2.0
		var img_center_x := img.get_width() / 2.0
		print("Banana P%d (%dx%d): bottom row=%d, x=[%d, %d], trunk_center=%.1f, img_center=%.1f, diff=%.1f" % [
			i, img.get_width(), img.get_height(), last_y, min_x, max_x, center_x, img_center_x, center_x - img_center_x
		])
	quit(0)
