extends SceneTree

func _init() -> void:
	print("=== Detailed Pixel Analysis ===")
	
	# Analyze Drone cells
	for i in range(1, 4):
		var path = "res://scratch/extracted_machines/drone_cell_%d.png" % i
		_analyze_colors(path, "Drone Cell %d" % i)
		
	# Analyze Sprinkler parts
	for i in range(1, 5):
		var path = "res://scratch/extracted_machines/sprinkler_part_%d.png" % i
		_analyze_colors(path, "Sprinkler Part %d" % i)
		
	# Analyze Sand tiles
	for name in ["Sand-01", "Sand-02", "Sand-03", "WSand-01", "WSand-02", "WSand-03"]:
		var path = "res://assets/sprites/ground/SAND/%s.png" % name
		_analyze_colors(path, name)

	quit(0)

func _analyze_colors(path: String, label: String) -> void:
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if not img: return
	var opaque_pixels := 0
	var sum_r := 0.0
	var sum_g := 0.0
	var sum_b := 0.0
	var min_x := 9999
	var max_x := -1
	var min_y := 9999
	var max_y := -1
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var p = img.get_pixel(x, y)
			if p.a > 0.05:
				opaque_pixels += 1
				sum_r += p.r
				sum_g += p.g
				sum_b += p.b
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	if opaque_pixels > 0:
		var avg_col = Color(sum_r / opaque_pixels, sum_g / opaque_pixels, sum_b / opaque_pixels)
		print("%s (%dx%d): %d opaque pixels, bounds=[(%d,%d)..(%d,%d)] size=(%dx%d), avg_rgb=(%.2f, %.2f, %.2f)" % [
			label, img.get_width(), img.get_height(), opaque_pixels, min_x, min_y, max_x, max_y, max_x - min_x + 1, max_y - min_y + 1, avg_col.r, avg_col.g, avg_col.b
		])
	else:
		print("%s: completely empty!" % label)
