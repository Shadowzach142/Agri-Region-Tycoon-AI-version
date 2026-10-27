@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if not img:
		quit()
		return
	
	# Look for the tripod feet: in frame 0, let's see what colors make up the tripod
	print("--- FRAME 0 (Idle Tripod) ---")
	for y in range(20, 64):
		var line := ""
		for x in range(15, 45):
			var a := img.get_pixel(x, y).a
			if a > 0.5:
				line += "#"
			else:
				line += " "
		if line.strip_edges() != "":
			# print(y, ": ", line)
			pass

	# Find the vertical central pipe/stem of the tripod across the entire image
	# Around y=40..50, where is the stem?
	# Let's inspect rows 45 to 55 across all X
	print("Non-blue/non-water pixels around y=48:")
	for x in range(img.get_width()):
		var c := img.get_pixel(x, 48)
		# tripod is typically metal (gray/green/dark), not light cyan or white
		if c.a > 0.5 and (c.r > 0.2 or c.b < 0.7 or c.g > 0.3):
			# print if dense
			pass

	# Let's check frames 0, 1, 2, 3, 4:
	# In frame 0, center of tripod:
	# Feet are at Y=63. Let's find tripod feet positions:
	for f_x in [0, 83, 166, 249, 332]:
		var min_x := 999
		var max_x := -1
		var base_y := 0
		for y in range(40, 65):
			for x in range(f_x, mini(f_x + 85, img.get_width())):
				var c := img.get_pixel(x, y)
				if c.a > 0.3:
					# Is it tripod? (not spray droplets: droplets around y=40..65 are usually light cyan/white, tripod is dark/green)
					if c.b < 0.85 or c.r > 0.25:
						min_x = mini(min_x, x)
						max_x = maxi(max_x, x)
						base_y = maxi(base_y, y)
		print("Segment near ", f_x, ": X=[", min_x, "..", max_x, "] mid=", (min_x + max_x)*0.5, " base_y=", base_y)

	quit()
