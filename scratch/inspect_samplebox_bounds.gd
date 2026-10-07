@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/sprites/StartMenu/samplebox1.png")
	print("samplebox1 size: ", img.get_size())
	# Check where the inner parchment area starts
	# Center X is 128
	var top_y = 0
	for y in range(img.get_height()):
		var c = img.get_pixel(128, y)
		if c.r > 0.8 and c.g > 0.7:
			top_y = y
			break
	print("samplebox1 inner parchment starts at Y = ", top_y)
	
	var bot_y = 0
	for y in range(img.get_height() - 1, -1, -1):
		var c = img.get_pixel(128, y)
		if c.r > 0.8 and c.g > 0.7:
			bot_y = y
			break
	print("samplebox1 inner parchment ends at Y = ", bot_y)
	quit()
