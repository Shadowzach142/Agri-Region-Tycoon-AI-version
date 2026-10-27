@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if not img:
		quit()
		return
	
	# Check row 62 and 63 across image:
	print("Tripod feet at y=63:")
	var in_foot := false
	var foot_start := 0
	var feet := []
	for x in range(img.get_width()):
		var c := img.get_pixel(x, 63)
		# dark metal foot
		var is_foot := (c.a > 0.8 and c.r < 0.6 and c.g < 0.6 and c.b < 0.6)
		if is_foot and not in_foot:
			in_foot = true
			foot_start = x
		elif not is_foot and in_foot:
			in_foot = false
			feet.append(Vector2i(foot_start, x - 1))
	if in_foot:
		feet.append(Vector2i(foot_start, img.get_width() - 1))
	print("Feet detected: ", feet)
	quit()
