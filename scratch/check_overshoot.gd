extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	var tex_w = float(img.get_width())
	var tex_h = float(img.get_height())
	var offset = Vector2(0, 9.0 - tex_h / 2.0)
	var scale = Vector2(4.0, 4.0)
	
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.05:
				var px_min = (offset - Vector2(tex_w, tex_h)/2.0 + Vector2(x, y)) * scale
				var px_max = px_min + scale
				var pt = Vector2((px_min.x + px_max.x)*0.5, px_max.y)
				var br_dist = (pt.y + 0.5 * pt.x) - 32.0
				var bl_dist = (pt.y - 0.5 * pt.x) - 32.0
				var y_dist = pt.y - 32.0
				var overshoot = maxf(y_dist, maxf(br_dist, bl_dist))
				if overshoot > 0.0:
					print("Pixel (x=%2d, y=%2d): center_x=%.1f, bot_y=%.1f => overshoot=%.1f (y_dist=%.1f, br=%.1f, bl=%.1f)" % [
						x, y, (px_min.x + px_max.x)*0.5, pt.y, overshoot, y_dist, br_dist, bl_dist
					])
	quit()
