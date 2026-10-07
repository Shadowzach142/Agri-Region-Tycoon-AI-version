extends SceneTree

func _init():
	# Let's test a 2x2 grid of tiles:
	# (0,0): Rice P1
	# (1,0): Rice P1
	# (0,1): Rice P1
	# (1,1): Rice P1
	# Surrounded by Grass tiles!
	# We want to see how GroundSprite with offset.y = -(tex_h - 32)/2.0 looks!
	
	var canvas = Image.create(512, 384, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.2, 0.25, 0.15)) # dark background
	
	var origin = Vector2i(256, 64)
	
	# Let's render tiles in isometric order (x from 0..3, y from 0..3)
	# Y-sorting: sort tiles by screen Y
	var tile_coords = []
	for x in range(4):
		for y in range(4):
			tile_coords.append(Vector2i(x, y))
	tile_coords.sort_custom(func(a, b):
		return (a.x + a.y) < (b.x + b.y)
	)
	
	var grass_img = Image.load_from_file("res://assets/sprites/ground/GROUND-Light-Grass/LightGrass1.png")
	var rice_img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	
	for coord in tile_coords:
		var pos_px = origin + Vector2i((coord.x - coord.y) * 64, (coord.x + coord.y) * 32)
		var is_rice = (coord.x >= 1 and coord.x <= 2 and coord.y >= 1 and coord.y <= 2)
		var tex = rice_img if is_rice else grass_img
		
		var tex_w = tex.get_width()
		var tex_h = tex.get_height()
		# Scale 4x
		var offset_y = -int((tex_h - 32) / 2.0)
		# When centered = true and offset = Vector2(0, offset_y):
		# top_left = pos_px + Vector2i(-tex_w / 2 * 4, (-tex_h / 2 + offset_y) * 4)
		var top_left = pos_px + Vector2i(-tex_w * 2, (-tex_h / 2 + offset_y) * 4)
		
		for y in range(tex_h):
			for x in range(tex_w):
				var c = tex.get_pixel(x, y)
				if c.a > 0.05:
					for dy in range(4):
						for dx in range(4):
							var px = top_left.x + x * 4 + dx
							var py = top_left.y + y * 4 + dy
							if px >= 0 and px < canvas.get_width() and py >= 0 and py < canvas.get_height():
								canvas.set_pixel(px, py, c)
	
	canvas.save_png("res://scratch/grid_rice_test.png")
	print("Saved scratch/grid_rice_test.png")
	quit()
