extends SceneTree

func _init() -> void:
	print("=== Finding non-empty sprite clusters ===")
	_analyze_image("res://assets/sprites/Machine/Drones.png", "Drones")
	_analyze_image("res://assets/sprites/Machine/Sprinklers.png", "Sprinklers")
	quit(0)

func _analyze_image(path: String, label: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if not img:
		printerr("Failed to load: " + path)
		return
	print("\n--- " + label + " (" + str(img.get_width()) + "x" + str(img.get_height()) + ") ---")
	
	# Check vertical slices or connected components
	# Let's check non-empty columns
	var col_has_pixels: Array[bool] = []
	for x in range(img.get_width()):
		var has_p := false
		for y in range(img.get_height()):
			if img.get_pixel(x, y).a > 0.05:
				has_p = true
				break
		col_has_pixels.append(has_p)
		
	# Find column spans
	var col_spans: Array[Vector2i] = []
	var in_span := false
	var span_start := 0
	for x in range(img.get_width()):
		if col_has_pixels[x] and not in_span:
			in_span = true
			span_start = x
		elif not col_has_pixels[x] and in_span:
			in_span = false
			col_spans.append(Vector2i(span_start, x - 1))
	if in_span:
		col_spans.append(Vector2i(span_start, img.get_width() - 1))
		
	print("Detected %d vertical sprite columns:" % col_spans.size())
	for idx in range(col_spans.size()):
		var span = col_spans[idx]
		# Find row bounds within this column span
		var min_y := 9999
		var max_y := -1
		for x in range(span.x, span.y + 1):
			for y in range(img.get_height()):
				if img.get_pixel(x, y).a > 0.05:
					if y < min_y: min_y = y
					if y > max_y: max_y = y
		print("  Sprite #%d: X=[%d..%d] (width=%d), Y=[%d..%d] (height=%d)" % [idx + 1, span.x, span.y, span.y - span.x + 1, min_y, max_y, max_y - min_y + 1])
