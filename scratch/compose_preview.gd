@tool
extends SceneTree

func _init() -> void:
	print("Compositing preview image...")
	var canvas := Image.create(1100, 680, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.10, 0.13, 0.16))

	# 1. Beach Sand Row
	for i in range(1, 4):
		var dry := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/ground/SAND/Sand-%02d.png" % i)
		if dry:
			dry.resize(128, 128, Image.INTERPOLATE_NEAREST)
			canvas.blend_rect(dry, Rect2i(0, 0, 128, 128), Vector2i(50 + (i - 1) * 160, 60))
		var wet := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/ground/SAND/WSand-%02d.png" % i)
		if wet:
			wet.resize(128, 128, Image.INTERPOLATE_NEAREST)
			canvas.blend_rect(wet, Rect2i(0, 0, 128, 128), Vector2i(560 + (i - 1) * 160, 60))

	# 2. Drone Machine Sprites (Lv. 1, 2, 3 across Rotor Frame 0 and 1)
	var drone_sheet := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Drones.png")
	if drone_sheet:
		for col in range(3):
			for row in range(2):
				var frame := Image.create(64, 48, false, Image.FORMAT_RGBA8)
				frame.blend_rect(drone_sheet, Rect2i(col * 64, row * 48, 64, 48), Vector2i.ZERO)
				frame.resize(128, 96, Image.INTERPOLATE_NEAREST)
				var px := 80 + col * 320 + row * 140
				var py := 260
				canvas.blend_rect(frame, Rect2i(0, 0, 128, 96), Vector2i(px, py))

	# 3. Sprinkler Machine Sprites (5 frames)
	var sprinkler_sheet := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if sprinkler_sheet:
		var stems := [Vector2i(23, 63), Vector2i(98, 63), Vector2i(175, 63), Vector2i(269, 63), Vector2i(365, 63)]
		var regions := [
			Rect2i(11, 20, 46, 44),
			Rect2i(70, 12, 67, 53),
			Rect2i(137, 3, 81, 74),
			Rect2i(225, 3, 88, 74),
			Rect2i(325, 3, 83, 74)
		]
		for i in range(5):
			var reg: Rect2i = regions[i]
			var stem: Vector2i = stems[i]
			var f_img := Image.create(reg.size.x, reg.size.y, false, Image.FORMAT_RGBA8)
			f_img.blend_rect(sprinkler_sheet, reg, Vector2i.ZERO)
			# Scale 1.5x nearest
			f_img.resize(int(reg.size.x * 1.5), int(reg.size.y * 1.5), Image.INTERPOLATE_NEAREST)
			var base_x := 100 + i * 195
			var base_y := 560
			var stem_offset := Vector2i(int((stem.x - reg.position.x) * 1.5), int((stem.y - reg.position.y) * 1.5))
			var dest := Vector2i(base_x, base_y) - stem_offset
			canvas.blend_rect(f_img, Rect2i(0, 0, f_img.get_width(), f_img.get_height()), dest)

	var out_path := "c:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/beach_and_machines_composite.png"
	canvas.save_png(out_path)
	print("SUCCESS: Saved composite image to ", out_path)
	quit()
