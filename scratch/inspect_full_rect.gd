@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/StartMenu/long-rectangle.png")
	print("Checking all non-transparent pixels in long-rectangle.png (400x150):")
	for y in range(0, 150, 5):
		var row_str = ""
		for x in range(0, 400, 10):
			row_str += "#" if img.get_pixel(x, y).a > 0.05 else " "
		if row_str.strip_edges() != "":
			print("y=", y, " |", row_str, "|")
	quit()
