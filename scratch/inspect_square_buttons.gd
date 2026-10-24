extends SceneTree

func _init():
	var dir = DirAccess.open("assets/sprites/hud/Buttons/Squarebutton")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.ends_with(".import"):
				var path = "assets/sprites/hud/Buttons/Squarebutton/" + file_name
				var img = Image.load_from_file(path)
				if img:
					print(file_name, " -> Size: ", img.get_size(), " format: ", img.get_format())
			file_name = dir.get_next()
	quit()
