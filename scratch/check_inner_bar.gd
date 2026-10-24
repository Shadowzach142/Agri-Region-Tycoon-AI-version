@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/hud/Inner-container/HUD-dark brown.png")
	var mid_x = img.get_width() / 2
	for y in range(img.get_height()):
		var c = img.get_pixel(mid_x, y)
		print("y=%d: rgba=(%.2f, %.2f, %.2f, %.2f)" % [y, c.r, c.g, c.b, c.a])
	quit(0)
