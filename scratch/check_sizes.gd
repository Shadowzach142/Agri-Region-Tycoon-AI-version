extends SceneTree

func _init():
	# In FarmGrid.gd:
	# ground_layer.y_sort_enabled = true
	# ground_node.position = tile_pos_px
	# sprite.centered = true
	# sprite.scale = Vector2(4, 4)
	# sprite.offset = Vector2.ZERO (for grass) or Vector2(0, -2) (for bare)
	# Let's inspect how LightGrass1 to 4 and Bare1 to 4 tile together!
	var grass_tex = Image.load_from_file("res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png")
	var bare_tex = Image.load_from_file("res://assets/sprites/ground/GROUND-Bare/Bare1.png")
	var rice_tex = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	
	print("grass_tex size: ", grass_tex.get_size())
	print("bare_tex size: ", bare_tex.get_size())
	print("rice_tex size: ", rice_tex.get_size())
	quit()
