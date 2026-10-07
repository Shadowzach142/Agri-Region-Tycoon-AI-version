@tool
extends SceneTree

func _init() -> void:
	var crops: Array[String] = [
		"res://assets/sprites/Field/Crops/Rice/RICE-P1.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P2.png",
		"res://assets/sprites/Field/Crops/Rice/RICE-P3.png",
		"res://assets/sprites/Field/Crops/Corn/CORN-P1.png",
		"res://assets/sprites/Field/Crops/Sugarcane/SUGARCANE-P1.png",
		"res://assets/sprites/Field/Crops/Pineapple/PINEAPPLE-P1.png",
		"res://assets/sprites/Field/Crops/Coffee/COFFEE-P1.png"
	]
	
	for path: String in crops:
		var img := Image.new()
		img.load(path)
		var h := img.get_height()
		var bot_row := -1
		for y in range(h - 1, -1, -1):
			var count := 0
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.1:
					count += 1
			if count > 0:
				bot_row = y
				break
				
		print("%s (%dx%d): bottom_row = %d" % [path.get_file(), img.get_width(), h, bot_row])
		
		# Test different offset formulas:
		# Formula A (old): 12.0 - h / 2.0
		var old_offset := 12.0 - float(h) / 2.0
		var old_screen_bot := (float(bot_row) - float(h) / 2.0) * 4.0 + old_offset * 4.0
		
		# Formula B (flush to y = 32.0):
		# We want (bot_row - h/2)*4 + offset*4 = 32.0
		# => offset*4 = 32.0 - (bot_row - h/2)*4
		# => offset = 8.0 - (bot_row - h/2)
		var flush_offset := 8.0 - (float(bot_row) - float(h) / 2.0)
		var flush_screen_bot := (float(bot_row) - float(h) / 2.0) * 4.0 + flush_offset * 4.0
		
		print("   Old screen bot Y: %.1f (overshoot: +%.1f px)" % [old_screen_bot, old_screen_bot - 32.0])
		print("   Flush offset: %.1f -> screen bot Y: %.1f (overshoot: %.1f px)" % [flush_offset, flush_screen_bot, flush_screen_bot - 32.0])
		
	quit(0)
