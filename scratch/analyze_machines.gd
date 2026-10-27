extends SceneTree

func _init() -> void:
	print("=== Analyzing Machine Sprites and Sand Tiles ===")
	
	# Check Drones.png
	var d_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Drones.png"))
	if d_img:
		print("Drones.png: size = %dx%d" % [d_img.get_width(), d_img.get_height()])
		# Look for non-transparent bounding boxes or grid divisions
		# If 192x96:
		# Could it be 6 cols x 3 rows of 32x32? (192/32 = 6, 96/32 = 3)
		# Or 4 cols x 2 rows of 48x48? (192/48 = 4, 96/48 = 2)
		# Or 3 cols of 64x96? Or 2 rows of 64x48?
		print("  Grid possibilities for Drones.png:")
		for gw in [16, 24, 32, 48, 64, 96]:
			if d_img.get_width() % gw == 0:
				for gh in [16, 24, 32, 48, 64, 96]:
					if d_img.get_height() % gh == 0:
						print("    %dx%d frames -> %d cols x %d rows (%d frames)" % [gw, gh, d_img.get_width() / gw, d_img.get_height() / gh, (d_img.get_width() / gw) * (d_img.get_height() / gh)])

	# Check Sprinklers.png
	var s_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if s_img:
		print("\nSprinklers.png: size = %dx%d" % [s_img.get_width(), s_img.get_height()])
		# 416x80
		# What factors of 416 and 80?
		# 416 = 32 * 13? Let's check: 32 * 13 = 416! 416 / 13 = 32!
		# Or 52 * 8? Or 416 / 64 = 6.5
		# 80 = 80, or 40*2, or 16*5
		print("  Grid possibilities for Sprinklers.png:")
		for gw in [16, 26, 32, 52, 64, 80, 104]:
			if s_img.get_width() % gw == 0:
				for gh in [16, 20, 32, 40, 80]:
					if s_img.get_height() % gh == 0:
						print("    %dx%d frames -> %d cols x %d rows (%d frames)" % [gw, gh, s_img.get_width() / gw, s_img.get_height() / gh, (s_img.get_width() / gw) * (s_img.get_height() / gh)])

	quit(0)
