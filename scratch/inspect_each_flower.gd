@tool
extends SceneTree

func _init() -> void:
	var files := [
		"tile_041.png",
		"tile_042.png",
		"tile_043.png",
		"tile_044.png",
		"tile_045.png",
		"tile_046.png",
		"tile_047.png"
	]
	
	for fname in files:
		var path: String = "res://assets/sprites/Decorations/Flowers/" + fname
		var img := Image.new()
		img.load(path)
		print("==========================================")
		print("FILE: ", fname)
		for y in range(img.get_height()):
			var row := ""
			var has_pixel := false
			for x in range(img.get_width()):
				var c := img.get_pixel(x, y)
				if c.a < 0.2:
					row += "  "
				else:
					has_pixel = true
					if c.r > 0.5 and c.g > 0.5 and c.b < 0.4:
						row += "🟡" # yellow
					elif c.r > 0.5 and c.b > 0.4:
						row += "🟣" # purple/magenta
					elif c.r > 0.5 and c.g < 0.4:
						row += "🔴" # red
					elif c.b > 0.5 and c.r < 0.4:
						row += "🔵" # blue
					elif c.g > c.r and c.g > c.b:
						row += "🌿" # green
					elif c.r > 0.7 and c.g > 0.7 and c.b > 0.7:
						row += "⚪" # white
					else:
						row += "🟫" # dark/shadow
			if has_pixel:
				print("%2d: %s" % [y, row])
	quit(0)
