extends Node

func _ready() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # transparent background

	var c_gold_bright := Color(1.0, 0.88, 0.35, 1.0)
	var c_gold_dark   := Color(0.75, 0.55, 0.15, 1.0)
	var c_blue_cyan   := Color(0.25, 0.80, 1.0, 1.0)
	var c_blue_deep   := Color(0.12, 0.45, 0.90, 1.0)
	var c_green_lush  := Color(0.35, 0.88, 0.45, 1.0)
	var c_grid_dark   := Color(0.20, 0.14, 0.10, 0.95)
	var c_radar_line  := Color(0.40, 0.95, 0.70, 0.85)
	var c_border      := Color(0.25, 0.18, 0.12, 1.0)

	# Helper to set pixel
	var set_px := func(x: int, y: int, col: Color) -> void:
		if x >= 0 and x < 32 and y >= 0 and y < 32:
			img.set_pixel(x, y, col)

	# 1. Outer diagnostic frame / scanner circle (diameter ~26px, center 16, 16)
	var center := Vector2(15.5, 15.5)
	for x in range(32):
		for y in range(32):
			var d: float = Vector2(x, y).distance_to(center)
			if d >= 12.0 and d <= 13.5:
				set_px.call(x, y, c_border)
			elif d > 10.5 and d < 12.0:
				set_px.call(x, y, c_gold_dark)
			elif d <= 10.5 and d >= 9.5:
				set_px.call(x, y, c_gold_bright)
			elif d < 9.5:
				# Scanner background tint
				set_px.call(x, y, Color(0.08, 0.14, 0.12, 0.90))

	# 2. Isometric grid cross-hatch inside the radar lens
	for i in range(-8, 9, 4):
		for step in range(32):
			# Diagonal lines / grid
			var x1: int = int(center.x) + step - 16
			var y1: int = int(center.y) + (step - 16) / 2 + i
			if Vector2(x1, y1).distance_to(center) < 9.0:
				set_px.call(x1, y1, Color(0.20, 0.45, 0.35, 0.75))

			var x2: int = int(center.x) - (step - 16)
			var y2: int = int(center.y) + (step - 16) / 2 + i
			if Vector2(x2, y2).distance_to(center) < 9.0:
				set_px.call(x2, y2, Color(0.20, 0.45, 0.35, 0.75))

	# 3. Moisture / Soil diagnostic core (center droplet + radiating pulse)
	# Water droplet shape centered at (15, 15)
	var droplet_pixels := [
		Vector2i(15, 10), Vector2i(16, 10),
		Vector2i(14, 11), Vector2i(15, 11), Vector2i(16, 11), Vector2i(17, 11),
		Vector2i(13, 12), Vector2i(14, 12), Vector2i(15, 12), Vector2i(16, 12), Vector2i(17, 12), Vector2i(18, 12),
		Vector2i(13, 13), Vector2i(14, 13), Vector2i(15, 13), Vector2i(16, 13), Vector2i(17, 13), Vector2i(18, 13),
		Vector2i(13, 14), Vector2i(14, 14), Vector2i(15, 14), Vector2i(16, 14), Vector2i(17, 14), Vector2i(18, 14),
		Vector2i(14, 15), Vector2i(15, 15), Vector2i(16, 15), Vector2i(17, 15),
		Vector2i(15, 16), Vector2i(16, 16)
	]
	for p in droplet_pixels:
		set_px.call(p.x, p.y + 1, c_blue_cyan)

	# Droplet highlight
	set_px.call(14, 13, Color.WHITE)
	set_px.call(14, 14, Color.WHITE)

	# 4. Radiating diagnostic scan sweep (arc from center to top right)
	for r in range(3, 10):
		var sweep_x := int(center.x + float(r) * 0.75)
		var sweep_y := int(center.y - float(r) * 0.70)
		set_px.call(sweep_x, sweep_y, c_radar_line)
		set_px.call(sweep_x + 1, sweep_y, Color(0.60, 1.0, 0.85, 0.95))

	# 5. Diagnostic corner ticks (4 cardinal points)
	for i in range(3):
		set_px.call(int(center.x) + i - 1, 2, c_gold_bright)
		set_px.call(int(center.x) + i - 1, 29, c_gold_bright)
		set_px.call(2, int(center.y) + i - 1, c_gold_bright)
		set_px.call(29, int(center.y) + i - 1, c_gold_bright)

	var path := "res://assets/icons/HUD/Heatmap.png"
	var global_path: String = ProjectSettings.globalize_path(path)
	img.save_png(global_path)
	print("✔ Saved 32x32 Heatmap icon to: %s" % global_path)
	get_tree().quit(0)
