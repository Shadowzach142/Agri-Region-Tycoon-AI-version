extends SceneTree

func _init() -> void:
	print("--- BUILDING SPRITE DIMENSIONS ---")
	var dir = DirAccess.open("res://assets/sprites/buildings")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png") or file_name.ends_with(".PNG"):
				var path = "res://assets/sprites/buildings/" + file_name
				var img = Image.load_from_file(ProjectSettings.globalize_path(path))
				if img:
					print("%-35s : %d x %d" % [file_name, img.get_width(), img.get_height()])
			file_name = dir.get_next()
	quit(0)
