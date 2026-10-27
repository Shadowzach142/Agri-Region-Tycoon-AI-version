extends SceneTree

func _init() -> void:
	print("=== Testing Sprinkler Placement on Isometric Tile ===")
	# Create a 128x128 preview canvas
	var canvas = Image.create(160, 140, false, Image.FORMAT_RGBA8)
	
	# Draw a 128x64 diamond centered at (80, 80)
	var center = Vector2i(80, 80)
	# Draw diamond lines
	var diamond_pts = [
		center + Vector2i(0, -32),
		center + Vector2i(64, 0),
		center + Vector2i(0, 32),
		center + Vector2i(-64, 0)
	]
	# Draw diamond outline
	for i in range(4):
		var p1 = diamond_pts[i]
		var p2 = diamond_pts[(i + 1) % 4]
		_draw_line(canvas, p1, p2, Color(0.4, 0.7, 0.4, 0.8))
		
	# Now blit the aligned sprinkler frame on top!
	var spr = Image.load_from_file(ProjectSettings.globalize_path("res://scratch/extracted_machines/sprinkler_aligned_4.png"))
	if spr:
		# Aligned frame has stem at x=48, base at y=64
		# We want base to land at center (80, 80)
		var dest_pos = center - Vector2i(48, 64)
		for x in range(spr.get_width()):
			for y in range(spr.get_height()):
				var p = spr.get_pixel(x, y)
				if p.a > 0.05:
					var dx = dest_pos.x + x
					var dy = dest_pos.y + y
					if dx >= 0 and dx < canvas.get_width() and dy >= 0 and dy < canvas.get_height():
						canvas.set_pixel(dx, dy, p)
						
	canvas.save_png(ProjectSettings.globalize_path("res://scratch/sprinkler_tile_preview.png"))
	print("Saved res://scratch/sprinkler_tile_preview.png successfully!")
	quit(0)

func _draw_line(img: Image, p1: Vector2i, p2: Vector2i, col: Color) -> void:
	var dist = max(abs(p2.x - p1.x), abs(p2.y - p1.y))
	for s in range(dist + 1):
		var t = float(s) / max(1, dist)
		var pt = Vector2i(int(lerp(float(p1.x), float(p2.x), t)), int(lerp(float(p1.y), float(p2.y), t)))
		if pt.x >= 0 and pt.x < img.get_width() and pt.y >= 0 and pt.y < img.get_height():
			img.set_pixel(pt.x, pt.y, col)
