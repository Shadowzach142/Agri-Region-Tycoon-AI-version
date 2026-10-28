extends SceneTree

func _init() -> void:
	print("--- BEGIN PROTOTYPE TEST: WATER SPRITES LOADING & ALIGNMENT ---")
	
	# 1. Verify all water textures load
	var calm_tex: Array[Texture2D] = []
	for i in range(1, 6):
		var path := "res://assets/sprites/water/water_%02d.png" % i
		var tex := load(path) as Texture2D
		assert(tex != null, "Failed to load calm water texture: " + path)
		calm_tex.append(tex)
	print("✓ Check 1 Passed: Loaded 5 calm water frames (water_01..05)")

	var light_tex: Array[Texture2D] = []
	for i in range(1, 9):
		var path := "res://assets/sprites/water/water_light_%02d.png" % i
		var tex := load(path) as Texture2D
		assert(tex != null, "Failed to load light water texture: " + path)
		light_tex.append(tex)
	print("✓ Check 2 Passed: Loaded 8 light water wave frames (water_light_01..08)")

	var dark_tex: Array[Texture2D] = []
	for i in range(1, 9):
		var path := "res://assets/sprites/water/water_dark_%02d.png" % i
		var tex := load(path) as Texture2D
		assert(tex != null, "Failed to load dark water wave texture: " + path)
		dark_tex.append(tex)
	print("✓ Check 3 Passed: Loaded 8 dark water wave frames (water_dark_01..08)")

	print("--- ALL PRELIMINARY TEXTURE CHECKS PASSED ---")
	quit(0)
