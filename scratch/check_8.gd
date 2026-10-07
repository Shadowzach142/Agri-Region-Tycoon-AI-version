extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	var tex_w = float(img.get_width())
	var tex_h = float(img.get_height())
	var offset = Vector2(0, 8.0 - tex_h / 2.0)
	var scale = Vector2(4.0, 4.0)
	
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.05:
				var px_min = (offset - Vector2(tex_w, tex_h)/2.0 + Vector2(x, y)) * scale
				var px_max = px_min + scale
				var corners = [
					px_min,
					Vector2(px_max.x, px_min.y),
					Vector2(px_min.x, px_max.y),
					px_max
				]
				for pt in corners:
					var br_dist = (pt.y + 0.5 * pt.x) - 32.0
					var bl_dist = (pt.y - 0.5 * pt.x) - 32.0
					var y_dist = pt.y - 32.0
					var over = maxf(y_dist, maxf(br_dist, bl_dist))
					if over > 0.0:
						print("Pixel (x=%2d, y=%2d) pt=(%.1f, %.1f) => br=%.1f, bl=%.1f, y=%.1f" % [x, y, pt.x, pt.y, br_dist, bl_dist, y_dist])
	quit()
