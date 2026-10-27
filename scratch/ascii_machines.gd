extends SceneTree

func _init() -> void:
	_ascii_art("res://scratch/extracted_machines/crop_part_1.png", "Part 1 (Sprinkler?)", 40, 20)
	_ascii_art("res://scratch/extracted_machines/crop_part_2.png", "Part 2", 50, 25)
	_ascii_art("res://scratch/extracted_machines/crop_part_3.png", "Part 3", 40, 25)
	_ascii_art("res://scratch/extracted_machines/crop_part_4.png", "Part 4", 40, 25)
	_ascii_art("res://scratch/extracted_machines/drone_cell_1.png", "Drone Cell 1", 32, 24)
	quit(0)

func _ascii_art(path: String, title: String, max_w: int, max_h: int) -> void:
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if not img: return
	print("\n================ " + title + " ================")
	var step_x = max(1, img.get_width() / max_w)
	var step_y = max(1, img.get_height() / max_h)
	for y in range(0, img.get_height(), step_y):
		var line = ""
		for x in range(0, img.get_width(), step_x):
			var p = img.get_pixel(x, y)
			if p.a < 0.1:
				line += " "
			elif p.v < 0.3:
				line += "#"
			elif p.v < 0.6:
				line += "+"
			else:
				line += "."
		print(line)
