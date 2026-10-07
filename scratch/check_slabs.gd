@tool
extends SceneTree

func _init() -> void:
	var crops := ["Rice", "Corn", "Sugarcane", "Pineapple", "Coffee", "Banana", "Coconut"]
	for c in crops:
		var dir := DirAccess.open("res://assets/sprites/Field/Crops/" + c)
		if dir:
			for f in dir.get_files():
				if f.ends_with(".png"):
					var path: String = "res://assets/sprites/Field/Crops/" + c + "/" + f
					var img := Image.new()
					img.load(path)
					# Check bottom row y = img.height - 1
					var bot_y := img.get_height() - 1
					var bot_pixels := 0
					for x in range(img.get_width()):
						if img.get_pixel(x, bot_y).a > 0.1:
							bot_pixels += 1
					
					# Check row 20 or row (bot_y - 11) for width 32 slab
					var has_slab := false
					if img.get_width() == 32:
						var row_check = mini(20, bot_y - 5)
						var slab_w := 0
						for x in range(32):
							if img.get_pixel(x, row_check).a > 0.1:
								slab_w += 1
						if slab_w >= 30 and bot_pixels > 0:
							has_slab = true
					
					print("%-20s (%2dx%2d): bot_pixels=%d -> has_slab=%s" % [
						c + "/" + f, img.get_width(), img.get_height(), bot_pixels, has_slab
					])
	quit(0)
