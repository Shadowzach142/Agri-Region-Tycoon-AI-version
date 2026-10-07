@tool
extends SceneTree

func _init() -> void:
	var crops: Array[String] = ["Rice", "Corn", "Sugarcane", "Pineapple", "Coffee"]
	for c: String in crops:
		var dir := DirAccess.open("res://assets/sprites/Field/Crops/" + c)
		if dir:
			for f: String in dir.get_files():
				if f.ends_with(".png"):
					var path: String = "res://assets/sprites/Field/Crops/" + c + "/" + f
					var img := Image.new()
					img.load(path)
					# Count pixels in row 20 and bottom row
					var r20 := 0
					var bot := 0
					var bot_y := img.get_height() - 1
					for x in range(img.get_width()):
						if img.get_pixel(x, mini(20, bot_y)).a > 0.1:
							r20 += 1
						if img.get_pixel(x, bot_y).a > 0.1:
							bot += 1
					print("%-20s (%dx%d): r20=%2d, bot=%2d" % [c + "/" + f, img.get_width(), img.get_height(), r20, bot])
	quit(0)
