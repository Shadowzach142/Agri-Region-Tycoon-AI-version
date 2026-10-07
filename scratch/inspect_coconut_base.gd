@tool
extends SceneTree

func _init() -> void:
	for p in ["res://assets/sprites/Field/Crops/Coconut/COCONUT-P1.png",
			  "res://assets/sprites/Field/Crops/Coconut/COCONUT-P2.png",
			  "res://assets/sprites/Field/Crops/Coconut/COCONUT-P3.png"]:
		var img := Image.new()
		img.load(p)
		print("=== " + p.get_file() + " (%dx%d) ===" % [img.get_width(), img.get_height()])
		# print bottom rows to see where the trunk base is
		for y in range(img.get_height() - 15, img.get_height()):
			var min_x := 999
			var max_x := -1
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.1:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
			if max_x >= 0:
				print("y=%2d: x=[%2d, %2d] w=%2d" % [y, min_x, max_x, max_x - min_x + 1])
	quit(0)
