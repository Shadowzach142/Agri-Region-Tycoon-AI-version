extends SceneTree

func _init() -> void:
	print("=== Analyzing Sprinkler Frames ===")
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if not img: return
	
	# Let's find vertical centers of the sprinkler tripod/stem in Sprinklers.png
	# Look for the tripod legs at Y=50..70
	for x in range(img.get_width()):
		# Check if there is a vertical metal post around Y=35..55
		var dark_count := 0
		for y in range(35, 55):
			var p = img.get_pixel(x, y)
			if p.a > 0.5 and p.v < 0.4:
				dark_count += 1
		if dark_count > 12:
			print("Tripod/stem candidate at X=%d (dark_count=%d)" % [x, dark_count])
			
	quit(0)
