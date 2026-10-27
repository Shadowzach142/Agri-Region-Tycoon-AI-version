extends SceneTree

func _init() -> void:
	print("=== Inspecting New Sand and Machine Assets ===")
	
	var sand_files = [
		"res://assets/sprites/ground/SAND/Sand-01.png",
		"res://assets/sprites/ground/SAND/Sand-02.png",
		"res://assets/sprites/ground/SAND/Sand-03.png",
		"res://assets/sprites/ground/SAND/WSand-01.png",
		"res://assets/sprites/ground/SAND/WSand-02.png",
		"res://assets/sprites/ground/SAND/WSand-03.png"
	]
	
	print("\n--- SAND TILES ---")
	for path in sand_files:
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			print("%s: %dx%d (format: %d, has_alpha: %s)" % [path.get_file(), img.get_width(), img.get_height(), img.get_format(), img.detect_alpha() != Image.ALPHA_NONE])
		else:
			printerr("Failed to load: %s" % path)
			
	var machine_files = [
		"res://assets/sprites/Machine/Drones.png",
		"res://assets/sprites/Machine/Sprinklers.png"
	]
	
	print("\n--- MACHINE SPRITES ---")
	for path in machine_files:
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			print("%s: %dx%d (format: %d, has_alpha: %s)" % [path.get_file(), img.get_width(), img.get_height(), img.get_format(), img.detect_alpha() != Image.ALPHA_NONE])
		else:
			printerr("Failed to load: %s" % path)

	quit(0)
