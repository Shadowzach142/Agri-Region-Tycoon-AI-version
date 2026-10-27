extends SceneTree

func _init() -> void:
	print("=== Testing Sprinkler Frame Centering ===")
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if not img: return
	
	# The 5 stem X positions:
	var stems = [23, 98, 175, 269, 365]
	# Base Y is at y=63 for frame 1, and ~64 for frames 2..5
	var base_ys = [63, 63, 64, 64, 64]
	
	# Let's create normalized 96x80 frames centered on stem_x and aligned to base_y = 64
	for i in range(5):
		var sx = stems[i]
		var by = base_ys[i]
		var frame = Image.create(96, 80, false, Image.FORMAT_RGBA8)
		# We want stem at x=48 in the 96px frame, and base at y=64
		# src_x = sx - 48, src_y = by - 64
		var src_rect = Rect2i(sx - 48, by - 64, 96, 80)
		
		# Blit with bounds clamping
		for fx in range(96):
			for fy in range(80):
				var gx = src_rect.position.x + fx
				var gy = src_rect.position.y + fy
				if gx >= 0 and gx < img.get_width() and gy >= 0 and gy < img.get_height():
					var p = img.get_pixel(gx, gy)
					if p.a > 0.05:
						frame.set_pixel(fx, fy, p)
		var out_p = "res://scratch/extracted_machines/sprinkler_aligned_%d.png" % (i + 1)
		frame.save_png(ProjectSettings.globalize_path(out_p))
		print("Saved %s centered on stem X=%d, base Y=%d" % [out_p, sx, by])
		
	quit(0)
