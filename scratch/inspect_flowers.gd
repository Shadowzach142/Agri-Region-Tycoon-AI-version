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
		
		var solid_pixels := 0
		var r_sum := 0.0
		var g_sum := 0.0
		var b_sum := 0.0
		var color_counts := {}
		
		var min_x := 999
		var max_x := -1
		var min_y := 999
		var max_y := -1
		
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c := img.get_pixel(x, y)
				if c.a > 0.1:
					solid_pixels += 1
					min_x = min(min_x, x)
					max_x = max(max_x, x)
					min_y = min(min_y, y)
					max_y = max(max_y, y)
					var hex := c.to_html(false)
					color_counts[hex] = color_counts.get(hex, 0) + 1
					r_sum += c.r
					g_sum += c.g
					b_sum += c.b
					
		var avg_col := Color(r_sum / solid_pixels, g_sum / solid_pixels, b_sum / solid_pixels) if solid_pixels > 0 else Color.BLACK
		var sorted_colors := color_counts.keys()
		sorted_colors.sort_custom(func(a, b): return color_counts[a] > color_counts[b])
		var top_colors := []
		for i in range(min(7, sorted_colors.size())):
			top_colors.append("#%s (%d px)" % [sorted_colors[i], color_counts[sorted_colors[i]]])
			
		print("==================================================")
		print("FILE: %s (Dimensions: %dx%d, BoundingBox: [%d,%d to %d,%d], Solid px: %d)" % [
			fname, img.get_width(), img.get_height(), min_x, min_y, max_x, max_y, solid_pixels
		])
		print("  Avg RGB: %s (#%s)" % [avg_col, avg_col.to_html(false)])
		print("  Dominant Colors: %s" % [", ".join(top_colors)])
		
	quit(0)
