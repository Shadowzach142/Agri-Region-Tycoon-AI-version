@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING MACHINE SPRITES ---")
	var img_drone := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Drones.png")
	if img_drone:
		print("Drone image size: ", img_drone.get_width(), "x", img_drone.get_height())
		for col in range(3):
			for row in range(2):
				var min_x := 9999
				var max_x := -1
				var min_y := 9999
				var max_y := -1
				for y in range(row * 48, (row + 1) * 48):
					for x in range(col * 64, (col + 1) * 64):
						var a := img_drone.get_pixel(x, y).a
						if a > 0.05:
							min_x = mini(min_x, x - col * 64)
							max_x = maxi(max_x, x - col * 64)
							min_y = mini(min_y, y - row * 48)
							max_y = maxi(max_y, y - row * 48)
				print("Col ", col, " Row ", row, ": X=[", min_x, "..", max_x, "] W=", (max_x - min_x + 1), " Y=[", min_y, "..", max_y, "] H=", (max_y - min_y + 1), " Center=(", (min_x + max_x) * 0.5, ", ", (min_y + max_y) * 0.5, ")")

	var img_sprinkler := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if img_sprinkler:
		print("\nSprinkler image size: ", img_sprinkler.get_width(), "x", img_sprinkler.get_height())
		# Find stems/columns
		# Let's inspect non-transparent areas across the 416 width
		var col_has_pixels := []
		for x in range(img_sprinkler.get_width()):
			var count := 0
			for y in range(img_sprinkler.get_height()):
				if img_sprinkler.get_pixel(x, y).a > 0.05:
					count += 1
			col_has_pixels.append(count > 0)

		# Find bounds of contiguous or grouped regions
		var in_group := false
		var start_x := 0
		var groups := []
		for x in range(img_sprinkler.get_width()):
			if col_has_pixels[x] and not in_group:
				in_group = true
				start_x = x
			elif not col_has_pixels[x] and in_group:
				# Check if gap is big (> 5 columns of empty)
				var gap := 0
				for look in range(x, mini(x + 8, img_sprinkler.get_width())):
					if not col_has_pixels[look]:
						gap += 1
					else:
						break
				if gap >= 6 or x == img_sprinkler.get_width() - 1:
					in_group = false
					groups.append(Vector2i(start_x, x - 1))
		if in_group:
			groups.append(Vector2i(start_x, img_sprinkler.get_width() - 1))

		print("Found groups: ", groups)
		for idx in range(groups.size()):
			var g: Vector2i = groups[idx]
			var min_y := 9999
			var max_y := -1
			# Find bottom-most pixel (base of tripod/sprinkler)
			var base_y := -1
			var base_x := -1
			for y in range(img_sprinkler.get_height()):
				for x in range(g.x, g.y + 1):
					if img_sprinkler.get_pixel(x, y).a > 0.05:
						min_y = mini(min_y, y)
						max_y = maxi(max_y, y)
						if y > base_y:
							base_y = y
							base_x = x
			print("Frame ", idx, ": X=[", g.x, "..", g.y, "] W=", (g.y - g.x + 1), " Y=[", min_y, "..", max_y, "] H=", (max_y - min_y + 1), " Base=(", base_x, ", ", base_y, ")")

	quit()
