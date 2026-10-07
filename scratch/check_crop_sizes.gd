extends SceneTree

func _init():
	var crops = ["Rice", "Corn", "Sugarcane", "Pineapple", "Coffee"]
	var base_dir = "res://assets/sprites/Field/Crops"
	for crop in crops:
		var dir = DirAccess.open("%s/%s" % [base_dir, crop])
		if dir:
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if fn.ends_with(".png") and not fn.ends_with(".import"):
					var img = Image.load_from_file("%s/%s/%s" % [base_dir, crop, fn])
					if img:
						print("%s/%s: size=%s" % [crop, fn, img.get_size()])
				fn = dir.get_next()
	quit()
