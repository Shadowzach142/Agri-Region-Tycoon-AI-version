@tool
extends SceneTree

func _init() -> void:
	var crops: Array[String] = ["Coffee", "Pineapple", "Sugarcane", "Corn", "Rice"]
	for c in crops:
		var dir := DirAccess.open("res://assets/sprites/Field/Crops/" + c)
		if dir:
			for f in dir.get_files():
				if f.ends_with(".png"):
					var p: String = "res://assets/sprites/Field/Crops/" + c + "/" + f
					var img := Image.new()
					img.load(p)
					var target_row: int = 20 if img.get_height() == 32 else 52
					var min_x: int = 999
					var max_x: int = -1
					for x in range(img.get_width()):
						if img.get_pixel(x, target_row).a > 0.1:
							min_x = mini(min_x, x)
							max_x = maxi(max_x, x)
					print("%s/%s: at y=%d: x=[%d, %d] w=%d" % [c, f, target_row, min_x, max_x, max_x - min_x + 1])
	quit(0)
