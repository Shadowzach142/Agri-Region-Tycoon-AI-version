extends SceneTree

func _init() -> void:
	print("=== Slicing Machine Sprites for Inspection ===")
	DirAccess.make_dir_recursive_absolute("res://scratch/extracted_machines")
	
	# Slicing Drones.png (192x96) -> 3 frames of 64x96
	var d_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Drones.png"))
	if d_img:
		for i in range(3):
			var cell = Image.create(64, 96, false, Image.FORMAT_RGBA8)
			cell.blit_rect(d_img, Rect2i(i * 64, 0, 64, 96), Vector2i.ZERO)
			cell.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/drone_cell_%d.png" % (i + 1)))
			print("Saved drone_cell_%d.png (64x96)" % (i + 1))
			
	# Slicing Sprinklers.png (416x80)
	var s_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/Machine/Sprinklers.png"))
	if s_img:
		# Let's save the whole image and also inspect its regions
		s_img.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinklers_full.png"))
		
		# Let's also slice into distinct parts:
		# Sprite 1: [0..64] (single small sprinkler?)
		var s1 = Image.create(64, 80, false, Image.FORMAT_RGBA8)
		s1.blit_rect(s_img, Rect2i(0, 0, 64, 80), Vector2i.ZERO)
		s1.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinkler_part_1.png"))
		
		# Let's inspect the remaining sections:
		# [64..220], [220..315], [315..416]
		var s2 = Image.create(160, 80, false, Image.FORMAT_RGBA8)
		s2.blit_rect(s_img, Rect2i(64, 0, 160, 80), Vector2i.ZERO)
		s2.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinkler_part_2.png"))
		
		var s3 = Image.create(96, 80, false, Image.FORMAT_RGBA8)
		s3.blit_rect(s_img, Rect2i(224, 0, 96, 80), Vector2i.ZERO)
		s3.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinkler_part_3.png"))
		
		var s4 = Image.create(96, 80, false, Image.FORMAT_RGBA8)
		s4.blit_rect(s_img, Rect2i(320, 0, 96, 80), Vector2i.ZERO)
		s4.save_png(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinkler_part_4.png"))

	quit(0)
