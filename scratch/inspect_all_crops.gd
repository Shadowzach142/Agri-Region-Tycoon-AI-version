@tool
extends SceneTree

func _init() -> void:
	var crops := ["Rice", "Banana", "Coconut", "Corn", "Coffee", "Pineapple", "Sugarcane"]
	for c in crops:
		var dir := DirAccess.open("res://assets/sprites/Field/Crops/" + c)
		if dir:
			for f in dir.get_files():
				if f.ends_with(".png"):
					var path: String = "res://assets/sprites/Field/Crops/" + c + "/" + f
					var img := Image.new()
					img.load(path)
					# Find bottom-most row with pixels
					var bot_y := -1
					for y in range(img.get_height() - 1, -1, -1):
						var count := 0
						for x in range(img.get_width()):
							if img.get_pixel(x, y).a > 0.1:
								count += 1
						if count > 0:
							bot_y = y
							break
					
					# Find row where width is maximal (left-right diamond tips)
					var max_w := 0
					var mid_y := -1
					for y in range(img.get_height()):
						var count := 0
						for x in range(img.get_width()):
							if img.get_pixel(x, y).a > 0.1:
								count += 1
						if count > max_w:
							max_w = count
							mid_y = y
					
					print("%s/%s (%dx%d): bottom_row=%d, max_width_row=%d (max_w=%d)" % [
						c, f, img.get_width(), img.get_height(), bot_y, mid_y, max_w
					])
	quit(0)
