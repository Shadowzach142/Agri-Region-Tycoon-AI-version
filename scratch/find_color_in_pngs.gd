extends SceneTree

func _init():
	var dir = DirAccess.open("res://")
	search_dir("res://assets")
	quit()

func search_dir(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			search_dir(path + "/" + file_name)
		elif file_name.ends_with(".png"):
			check_png(path + "/" + file_name)
		file_name = dir.get_next()

func check_png(file_path: String):
	var img = Image.load_from_file(file_path)
	if not img:
		return
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.5:
				var hex = c.to_html(false).to_lower()
				if hex == "78492f" or hex == "5d3518":
					print("FOUND MATCH in ", file_path, " at (", x, ",", y, ") hex=", hex)
					return
