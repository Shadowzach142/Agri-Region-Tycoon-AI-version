extends SceneTree

func _init() -> void:
	print("--- DETAILED SPRITE ALIGNMENT ANALYSIS ---")
	var buildings = [
		{"type": "rice_mill", "file": "Kiskisan_Rice_Mill.png", "fp": Vector2i(2, 2)},
		{"type": "sugar_mill", "file": "Trapiche_Sugar_Central.png", "fp": Vector2i(3, 2)},
		{"type": "copra_dryer", "file": "Tapahan_Copra_Dryer.png", "fp": Vector2i(3, 2)},
		{"type": "coffee_roastery", "file": "Artisan_Coffee_Roastery.png", "fp": Vector2i(2, 2)},
		{"type": "tacurong_mill", "file": "Tacurong-Grain-mill.png", "fp": Vector2i(3, 3)},
		{"type": "koronadal_wholesale", "file": "Koronadal-Wholesale.png", "fp": Vector2i(4, 4)},
		{"type": "gensan_seaport", "file": "Gensan-seaport.png", "fp": Vector2i(4, 4)},
		{"type": "bayanihan_center", "file": "byahero.png", "fp": Vector2i(2, 2)},
		{"type": "bahay_kubo", "file": "KUBO.png", "fp": Vector2i(2, 2)},
		{"type": "cold_storage", "file": "Cold_Storage.png", "fp": Vector2i(3, 3)},
		{"type": "weather_station", "file": "Weather_Station.png", "fp": Vector2i(3, 3)},
		{"type": "drone_station", "file": "Drone_Station.png", "fp": Vector2i(2, 2)},
		{"type": "water_tower", "file": "Water_Station.png", "fp": Vector2i(2, 2)},
	]

	for b in buildings:
		var path = "res://assets/sprites/buildings/" + b.file
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if not img:
			continue
		var w = img.get_width()
		var h = img.get_height()
		# Find bounding box of non-transparent pixels
		var min_x = w; var max_x = 0; var min_y = h; var max_y = 0
		for y in range(h):
			for x in range(w):
				if img.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)

		var opaque_w = max_x - min_x + 1
		var opaque_h = max_y - min_y + 1
		var center_x = (min_x + max_x) * 0.5
		print("%-20s | Size: %3dx%3d | Opaque BBox: (%3d,%3d) to (%3d,%3d) [%3dx%3d] | CenterX: %.1f | BaseY: %d" % [
			b.type, w, h, min_x, min_y, max_x, max_y, opaque_w, opaque_h, center_x, max_y
		])

	quit(0)
