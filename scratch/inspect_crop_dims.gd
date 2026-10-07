@tool
extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/sprites/Field/Crops")
	if dir:
		for folder in dir.get_directories():
			var sub := DirAccess.open("res://assets/sprites/Field/Crops/" + folder)
			if sub:
				for file in sub.get_files():
					if file.ends_with(".png"):
						var path := "res://assets/sprites/Field/Crops/" + folder + "/" + file
						var tex: Texture2D = load(path)
						if tex:
							print("%s/%s -> %d x %d" % [folder, file, tex.get_width(), tex.get_height()])
	quit(0)
