extends SceneTree

func _init():
	var canvas = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.44, 0.65, 0.28)) # grass
	
	var center = Vector2i(128, 128)
	
	# Draw diamond border onto canvas:
	# Top: center + (0, -32), Right: center + (64, 0), Bottom: center + (0, 32), Left: center + (-64, 0)
	var border_color = Color(0.18, 0.28, 0.14)
	draw_line(canvas, center + Vector2i(0, -32), center + Vector2i(64, 0), border_color)
	draw_line(canvas, center + Vector2i(64, 0), center + Vector2i(0, 32), border_color)
	draw_line(canvas, center + Vector2i(0, 32), center + Vector2i(-64, 0), border_color)
	draw_line(canvas, center + Vector2i(-64, 0), center + Vector2i(0, -32), border_color)
	
	# Load and blit Rice P1 scaled 4x
	var tex_img = Image.load_from_file("res://assets/sprites/Field/Crops/Rice/RICE-P1.png")
	var scaled_img = Image.create(tex_img.get_width() * 4, tex_img.get_height() * 4, false, Image.FORMAT_RGBA8)
	for y in range(tex_img.get_height()):
		for x in range(tex_img.get_width()):
			var c = tex_img.get_pixel(x, y)
			for dy in range(4):
				for dx in range(4):
					scaled_img.set_pixel(x * 4 + dx, y * 4 + dy, c)
	
	# At offset_val = 7.0:
	# top_left_px = center + Vector2i(-tex_w/2 * 4, (7.0 - tex_h) * 4)
	# tex_w = 32, tex_h = 32 => top_left_px = center + Vector2i(-64, (7 - 32) * 4) = center + Vector2i(-64, -100)
	var top_left = center + Vector2i(-64, (7 - 32) * 4)
	for y in range(scaled_img.get_height()):
		for x in range(scaled_img.get_width()):
			var c = scaled_img.get_pixel(x, y)
			if c.a > 0.05:
				var dst_x = top_left.x + x
				var dst_y = top_left.y + y
				if dst_x >= 0 and dst_x < 256 and dst_y >= 0 and dst_y < 256:
					canvas.set_pixel(dst_x, dst_y, c)
	
	canvas.save_png("res://scratch/rice_blit_7.png")
	print("Saved scratch/rice_blit_7.png")
	quit()

func draw_line(img: Image, p1: Vector2i, p2: Vector2i, col: Color):
	var dx = abs(p2.x - p1.x)
	var dy = -abs(p2.y - p1.y)
	var sx = 1 if p1.x < p2.x else -1
	var sy = 1 if p1.y < p2.y else -1
	var err = dx + dy
	var curr = p1
	while true:
		if curr.x >= 0 and curr.x < img.get_width() and curr.y >= 0 and curr.y < img.get_height():
			img.set_pixel(curr.x, curr.y, col)
		if curr == p2:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			curr.x += sx
		if e2 <= dx:
			err += dx
			curr.y += sy
