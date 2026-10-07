@tool
extends SceneTree

func _init() -> void:
	# Tile centers in local space relative to (x, y) at (0, 0):
	# (x, y) = (0, 0)
	# (x+1, y) = (64, 32)
	# (x, y+1) = (-64, 32)
	# (x+1, y+1) = (0, 64)
	var avg_x := (0.0 + 64.0 - 64.0 + 0.0) / 4.0
	var avg_y := (0.0 + 32.0 + 32.0 + 64.0) / 4.0
	print("2x2 Grove geometric center: (%.1f, %.1f)" % [avg_x, avg_y]) # (0.0, 32.0)

	# When tree base is at y = 32.0:
	# Coconut P3 is 80x96. Bottom row is 95.
	# Position = (0, 32). Offset = (0, -48).
	# Base Y = 32 + (96/2 - 48)*4 = 32.0! (Touched down exactly at center 32.0!)
	print("Coconut base touchdown: Y = 32.0")

	# Banana P4 is 64x64. Bottom row is 63.
	# Position = (0, 32). Offset = (0, -32).
	# Base Y = 32 + (64/2 - 32)*4 = 32.0! (Touched down exactly at center 32.0!)
	print("Banana base touchdown: Y = 32.0")

	quit(0)
