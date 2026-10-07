extends SceneTree

func _init():
	var canvas = Image.create(384, 256, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.2, 0.2, 0.2))
	
	# Isometric grid step:
	# grid_to_pixel(x, y) = origin + Vector2((x - y) * 64, (x + y) * 32)
	# Wait! In FarmerMovement.gd, what is grid_to_pixel_center?
	# Let's check FarmerMovement.gd!
	quit()
