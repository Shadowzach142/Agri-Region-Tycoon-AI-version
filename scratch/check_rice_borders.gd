extends SceneTree

func _init() -> void:
	var img = load("res://assets/sprites/Field/Crops/Rice/RICE-P2.png").get_image()
	print("RICE-P2 size: ", img.get_size())
	# Check top row, bottom row, left col, right col
	var top_opaque = 0
	for x in range(img.get_width()):
		if img.get_pixel(x, 0).a > 0.1:
			top_opaque += 1
	var bottom_opaque = 0
	for x in range(img.get_width()):
		if img.get_pixel(x, img.get_height() - 1).a > 0.1:
			bottom_opaque += 1
	var left_opaque = 0
	for y in range(img.get_height()):
		if img.get_pixel(0, y).a > 0.1:
			left_opaque += 1
	var right_opaque = 0
	for y in range(img.get_height()):
		if img.get_pixel(img.get_width() - 1, y).a > 0.1:
			right_opaque += 1
	print("Top opaque: ", top_opaque, " Bottom opaque: ", bottom_opaque, " Left opaque: ", left_opaque, " Right opaque: ", right_opaque)
	quit(0)
