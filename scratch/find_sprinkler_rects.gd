@tool
extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("c:/Users/ADMIN/Documents/agri-region-ai-version/assets/sprites/Machine/Sprinklers.png")
	if not img:
		quit()
		return
	
	# Stems at: 23, 98, 175, 269, 365
	var dividers: Array[int] = [0, 60, 137, 222, 317, 416]
	for i in range(5):
		var x_start: int = dividers[i]
		var x_end: int = dividers[i + 1] - 1
		var min_x: int = 999
		var max_x: int = -1
		var min_y: int = 999
		var max_y: int = -1
		for y in range(img.get_height()):
			for x in range(x_start, x_end + 1):
				if img.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
		var stem_x: float = [23.0, 98.5, 175.0, 269.0, 365.0][i]
		print("Frame %d (Stem %.1f): X=[%d..%d] (rel: %.1f..%.1f) Y=[%d..%d] (rel base 63: %.1f..%.1f) W=%d H=%d" % [
			i, stem_x, min_x, max_x, float(min_x) - stem_x, float(max_x) - stem_x, min_y, max_y, float(min_y) - 63.0, float(max_y) - 63.0, max_x - min_x + 1, max_y - min_y + 1
		])
	quit()
