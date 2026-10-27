extends SceneTree

func _init() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Palette
	var c_outline := Color(0.12, 0.07, 0.04, 1.0)
	var c_gold_hi := Color(1.0, 0.92, 0.45, 1.0)
	var c_gold_mid := Color(0.88, 0.68, 0.22, 1.0)
	var c_gold_dark := Color(0.48, 0.30, 0.10, 1.0)

	var c_red_hi := Color(0.96, 0.32, 0.28, 1.0)
	var c_red_mid := Color(0.82, 0.16, 0.16, 1.0)
	var c_red_dark := Color(0.58, 0.08, 0.08, 1.0)

	var c_white := Color(1.0, 1.0, 1.0, 1.0)
	var c_white_sh := Color(0.82, 0.80, 0.80, 1.0)

	# Helper distance to octagon center (15.5, 15.5)
	# Octagon bounds: x in [4, 27], y in [4, 27]
	for y in range(32):
		for x in range(32):
			var dx: float = absf(x - 15.5)
			var dy: float = absf(y - 15.5)
			# Octagon equation: max(dx, dy) <= 12 and (dx + dy) <= 17.5
			var r_box: float = maxf(dx, dy)
			var r_diag: float = dx + dy

			if r_box <= 12.5 and r_diag <= 17.5:
				# Outer outline
				if r_box >= 11.5 or r_diag >= 16.5:
					img.set_pixel(x, y, c_outline)
				# Golden rim
				elif r_box >= 9.5 or r_diag >= 14.5:
					if y <= 15 and x <= 15:
						img.set_pixel(x, y, c_gold_hi)
					elif y > 16 and x > 16:
						img.set_pixel(x, y, c_gold_dark)
					else:
						img.set_pixel(x, y, c_gold_mid)
				# Inner dark ring for depth
				elif r_box >= 8.5 or r_diag >= 13.5:
					img.set_pixel(x, y, Color(0.20, 0.04, 0.04, 1.0))
				# Red Octagon Face
				else:
					if y <= 11:
						img.set_pixel(x, y, c_red_hi)
					elif y >= 20:
						img.set_pixel(x, y, c_red_dark)
					else:
						img.set_pixel(x, y, c_red_mid)

	# Draw bold white 'X' in center (thickness 2-3px)
	# Center is at 15.5, 15.5. Range of X arms: -5 to +5
	for i in range(-5, 6):
		var px1 := 15 + i
		var py1 := 15 + i
		var px2 := 16 + i
		var py2 := 15 - i

		# Main diagonal
		for off_x in [-1, 0]:
			var x1: int = px1 + off_x
			var y1: int = py1
			if x1 >= 9 and x1 <= 22 and y1 >= 9 and y1 <= 22:
				img.set_pixel(x1, y1, c_white if y1 <= 15 else c_white_sh)

		# Anti diagonal
		for off_x in [-1, 0]:
			var x2: int = px2 + off_x
			var y2: int = py2
			if x2 >= 9 and x2 <= 22 and y2 >= 9 and y2 <= 22:
				img.set_pixel(x2, y2, c_white if y2 <= 15 else c_white_sh)

	# Save PNG
	var target_path := "c:/Users/ADMIN/Documents/agri-region-ai-version/assets/icons/Tools/Cancel.png"
	var err := img.save_png(target_path)
	if err == OK:
		print("✔ Cancel icon generated successfully at: ", target_path)
	else:
		print("❌ Error generating Cancel icon: ", err)
	quit(0)
