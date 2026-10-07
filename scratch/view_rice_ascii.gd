@tool
extends SceneTree

func _init() -> void:
	var path := "res://assets/sprites/Field/Crops/Rice/RICE-P1.png"
	var img := Image.new()
	img.load(path)
	for y in range(img.get_height()):
		var line := "%2d: " % y
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				line += " "
			elif c.g > c.r and c.g > c.b: # green sprout
				line += "V"
			elif c.b > c.r and c.b > 0.5: # water
				line += "~"
			else: # soil / curb
				line += "#"
		print(line)
	quit(0)
