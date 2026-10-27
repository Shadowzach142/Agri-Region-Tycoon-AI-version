extends SceneTree

func _init() -> void:
	print("=== Analyzing 5 Sprinkler Sprites ===")
	var s_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if not s_img: return
	
	# Let's crop each of the 5 sprinkler frames:
	# Stems were at ~23, ~98, ~175, ~269, ~365
	# Notice:
	# 1: Idle sprinkler tripod [0..60] (no water spray)
	# 2: Sprinkler with water spray frame A [60..140] (center ~100)
	# 3: Sprinkler with water spray frame B [140..220] (center ~175)
	# 4: Sprinkler with water spray frame C [220..315] (center ~270)
	# 5: Sprinkler with water spray frame D [315..416] (center ~365)
	
	# Let's verify pixel columns and crop each cleanly centered on its stem!
	var stems = [23, 98, 175, 269, 365]
	for i in range(stems.size()):
		var stem_x = stems[i]
		# 64px wide centered around stem_x, or 80px wide
		var crop_w = 80
		var left_x = clampi(stem_x - 40, 0, s_img.get_width() - crop_w)
		var f = Image.create(crop_w, 80, false, Image.FORMAT_RGBA8)
		f.blit_rect(s_img, Rect2i(left_x, 0, crop_w, 80), Vector2i.ZERO)
		var out_p = "res://scratch/extracted_machines/sprinkler_f%d.png" % (i + 1)
		f.save_png(ProjectSettings.globalize_path(out_p))
		
		# Let's count water droplets (cyan / light blue / high value pixels)
		var water_pixels := 0
		for x in range(crop_w):
			for y in range(80):
				var p = f.get_pixel(x, y)
				if p.a > 0.1 and (p.b > p.r + 0.1 or p.v > 0.8):
					water_pixels += 1
		print("Sprinkler Frame %d: stem_x=%d, left_x=%d, water_pixels=%d" % [i + 1, stem_x, left_x, water_pixels])

	quit(0)
