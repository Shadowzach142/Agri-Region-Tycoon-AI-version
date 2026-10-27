extends SceneTree

func _init() -> void:
	print("=== Slicing Drones.png into 64x48 frames ===")
	var d_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Drones.png"))
	if d_img:
		for row in range(2):
			for col in range(3):
				var frame = Image.create(64, 48, false, Image.FORMAT_RGBA8)
				frame.blit_rect(d_img, Rect2i(col * 64, row * 48, 64, 48), Vector2i.ZERO)
				var out_path = "res://scratch/extracted_machines/drone_c%d_r%d.png" % [col + 1, row + 1]
				frame.save_png(ProjectSettings.globalize_path(out_path))
				
				# Count non-empty pixels and average color
				var count := 0
				var r := 0.0
				var g := 0.0
				var b := 0.0
				for x in range(64):
					for y in range(48):
						var p = frame.get_pixel(x, y)
						if p.a > 0.1:
							count += 1
							r += p.r; g += p.g; b += p.b
				var avg = Color(r / max(1, count), g / max(1, count), b / max(1, count))
				print("Drone Col %d, Row %d: %d pixels, avg=(%.2f, %.2f, %.2f)" % [col + 1, row + 1, count, avg.r, avg.g, avg.b])

	quit(0)
