@tool
extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/sprites/Field/Crops/Coffee")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".png"):
				var p: String = "res://assets/sprites/Field/Crops/Coffee/" + f
				var img := Image.new()
				img.load(p)
				for y in range(img.get_height()):
					var min_x := 999
					var max_x := -1
					for x in range(img.get_width()):
						if img.get_pixel(x, y).a > 0.1:
							min_x = mini(min_x, x)
							max_x = maxi(max_x, x)
					if max_x - min_x + 1 >= 32:
						print("Coffee/%s: at y=%d: x=[%d, %d] w=%d (img: %dx%d)" % [
							f, y, min_x, max_x, max_x - min_x + 1, img.get_width(), img.get_height()
						])
	quit(0)
