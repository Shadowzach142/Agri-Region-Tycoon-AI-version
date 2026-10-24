extends SceneTree

func _init():
	for name in ["byahero.png", "Tacurong-Grain-mill.png", "Koronadal-Wholesale.png", "Gensan-seaport.png"]:
		var img = Image.load_from_file("res://assets/sprites/buildings/" + name)
		print("%s: %dx%d" % [name, img.get_width(), img.get_height()])
	quit()
