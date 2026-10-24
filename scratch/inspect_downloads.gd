@tool
extends SceneTree

func _init() -> void:
	var files = [
		"C:/Users/ADMIN/Downloads/images__6_-removebg-preview.png",
		"C:/Users/ADMIN/Downloads/images__6_-removebg-preview (1).png",
		"C:/Users/ADMIN/Downloads/images__6_-removebg-preview (2).png",
		"C:/Users/ADMIN/Downloads/images__6_-removebg-preview (3).png",
		"C:/Users/ADMIN/Downloads/images__6_-removebg-preview (4).png",
		"C:/Users/ADMIN/Downloads/unnamed.png",
		"C:/Users/ADMIN/Downloads/6ff20796616991b057781ef41e85d784-removebg-preview.png"
	]
	for f in files:
		if FileAccess.file_exists(f):
			var img = Image.load_from_file(f)
			if img:
				print("File: ", f, " size: ", img.get_size())
	quit()
