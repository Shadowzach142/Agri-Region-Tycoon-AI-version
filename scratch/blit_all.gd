extends SceneTree

func _init():
	var crops = [
		{"name": "Rice", "path": "res://assets/sprites/Field/Crops/Rice/RICE-P1.png"},
		{"name": "Corn", "path": "res://assets/sprites/Field/Crops/Corn/CORN-P3.png"},
		{"name": "Sugarcane", "path": "res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P3.png"},
		{"name": "Pineapple", "path": "res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P3.png"},
		{"name": "Coffee", "path": "res://assets/sprites/Field/Crops/Coffee/COFFEE-P3.png"}
	]
	
	for c_data in crops:
		var canvas = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.44, 0.65, 0.28))
		var center = Vector2i(128, 160)
		var border_color = Color(0.18, 0.28, 0.14)
		draw_line(canvas, center + Vector2i(0, -32), center + Vector2i(64, 0), border_color)
		draw_line(canvas, center + Vector2i(64, 0), center + Vector2i(0, 32), border_color)
		draw_line(canvas, center + Vector2i(0, 32), center + Vector2i(-64, 0), border_color)
		draw_line(canvas, center + Vector2i(-64, 0), center + Vector2i(0, -32), border_color)
		
		var tex_img = Image.load_from_file(c_data["path"])
		var tex_w = tex_img.get_width()
		var tex_h = tex_img.get_height()
		var scaled_img = Image.create(tex_w * 4, tex_h * 4, false, Image.FORMAT_RGBA8)
		for y in range(tex_h):
			for x in range(tex_w):
				var c = tex_img.get_pixel(x, y)
				for dy in range(4):
					for dx in range(4):
						scaled_img.set_pixel(x * 4 + dx, y * 4 + dy, c)
		
		var top_left = center + Vector2i(-tex_w * 2, (7 - tex_h) * 4)
		for y in range(scaled_img.get_height()):
			for x in range(scaled_img.get_width()):
				var c = scaled_img.get_pixel(x, y)
				if c.a > 0.05:
					var dst_x = top_left.x + x
					var dst_y = top_left.y + y
					if dst_x >= 0 and dst_x < 256 and dst_y >= 0 and dst_y < 256:
						canvas.set_pixel(dst_x, dst_y, c)
		
		canvas.save_png("res://scratch/crop_blit_%s.png" % c_data["name"].to_lower())
		print("Saved scratch/crop_blit_%s.png" % c_data["name"].to_lower())
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
		if curr == p2: break
		var e2 = 2 * err
		if e2 >= dy: err += dy; curr.x += sx
		if e2 <= dx: err += dx; curr.y += sy
