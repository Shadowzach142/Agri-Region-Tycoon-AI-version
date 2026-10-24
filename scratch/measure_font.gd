@tool
extends SceneTree

func _init():
	var font = load("res://assets/font/quill_and_antler/quill-and-antler.ttf") as Font
	if not font:
		print("Font not found!")
		quit(1)
		return
	
	var strings = [
		"Tile (0, 0)",
		"Tile (19, 19)",
		"📦 Selected: 100 Tiles",
		"Growth:",
		"Health:",
		"Moist:",
		"0%",
		"65%",
		"100%",
		"Avg: 100%",
		"Quality: Grade A",
		"Pests: None (Healthy)",
		"Bahay Kubo (Farm Shack) Lv.1",
		"Click building to Inspect / Upgrade"
	]
	
	for s in strings:
		for sz in [14, 15, 16, 17, 18]:
			var width = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			if sz in [15, 16, 18]:
				print("'%s' at %dpt: width=%.1f" % [s, sz, width])
	
	quit(0)
