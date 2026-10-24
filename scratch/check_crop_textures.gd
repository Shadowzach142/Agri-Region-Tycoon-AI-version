@tool
extends SceneTree

func _init():
	var crops = ["palay", "yellow_corn", "sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	var renderer = TileRenderer.new()
	for c in crops:
		for stage in [1, 2, 3, 4, 5]:
			var tex = renderer.get_crop_stage_texture(c, stage)
			print("Crop %s Stage %d: %s" % [c, stage, "FOUND" if tex != null else "NULL"])
		var regr = renderer.get_regrowth_texture(c)
		if regr != null:
			print("Crop %s Regrowth: FOUND" % c)
	quit(0)
