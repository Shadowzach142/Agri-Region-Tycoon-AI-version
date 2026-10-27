extends SceneTree

func _init() -> void:
	print("=== Deep Analysis of Sprinklers.png ===")
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if not img: return
	
	# Let's inspect where pixels exist horizontally
	# Print ascii representation of the image rows & cols
	print("Dimensions: %d x %d" % [img.get_width(), img.get_height()])
	
	# Let's find distinct connected components or distinct islands of pixels
	# We saw:
	# Part 1: X=[11..56] (width=46), Y=[20..63] (height=44)
	# Part 2: X=[70..217] (width=148), Y=[3..76] (height=74)
	# Part 3: X=[225..312]
	# Part 4: X=[325..407]
	
	# Let's save exact cropped bounding boxes of each distinct part:
	var bboxes = [
		Rect2i(10, 15, 50, 55),   # Part 1: small sprinkler?
		Rect2i(65, 0, 155, 80),   # Part 2: large machine or sprinkler?
		Rect2i(225, 0, 95, 80),   # Part 3: medium machine or sprinkler?
		Rect2i(320, 0, 95, 80)    # Part 4: another machine or sprinkler?
	]
	
	for i in range(bboxes.size()):
		var b = bboxes[i]
		var crop = Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
		crop.blit_rect(img, b, Vector2i.ZERO)
		var out_path = "res://scratch/extracted_machines/crop_part_%d.png" % (i + 1)
		crop.save_png(ProjectSettings.globalize_path(out_path))
		print("Saved %s: size=%s" % [out_path, b.size])
		
	quit(0)
