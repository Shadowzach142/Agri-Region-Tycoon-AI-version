@tool
extends SceneTree

func _init():
	var renderer = TileRenderer.new()
	var crops = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	for c in crops:
		var tex = renderer.get_crop_stage_texture(c, 3)
		if tex:
			print("Crop %s Stage 3 size: %d x %d" % [c, tex.get_width(), tex.get_height()])
	quit(0)
