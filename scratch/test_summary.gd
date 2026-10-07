extends SceneTree

func _init():
	var crops = ["Rice", "Corn", "Sugarcane", "Pineapple", "Coffee"]
	var base_dir = "res://assets/sprites/Field/Crops"
	
	for offset_val in [9.0, 8.5, 8.0, 7.5, 7.0]:
		var max_crop_overshoot = 0.0
		var worst_crop = ""
		var max_y_overall = -999.0
		
		for crop in crops:
			var crop_dir = "%s/%s" % [base_dir, crop]
			var dir = DirAccess.open(crop_dir)
			if not dir:
				continue
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if fn.ends_with(".png") and not fn.ends_with(".import"):
					var path = "%s/%s" % [crop_dir, fn]
					var img = Image.load_from_file(path)
					if img:
						var tex_w = float(img.get_width())
						var tex_h = float(img.get_height())
						var offset = Vector2(0, offset_val - tex_h / 2.0)
						var scale = Vector2(4.0, 4.0)
						
						for y in range(img.get_height()):
							for x in range(img.get_width()):
								var c = img.get_pixel(x, y)
								if c.a > 0.05:
									var px_min = (offset - Vector2(tex_w, tex_h)/2.0 + Vector2(x, y)) * scale
									var px_max = px_min + scale
									if px_max.y > max_y_overall:
										max_y_overall = px_max.y
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
										if over > max_crop_overshoot:
											max_crop_overshoot = over
											worst_crop = "%s/%s (%d,%d)" % [crop, fn, x, y]
				fn = dir.get_next()
		print("offset_val=%.1f => max_y=%.1f, max_overshoot=%.2f px (%s)" % [offset_val, max_y_overall, max_crop_overshoot, worst_crop])
	quit()
