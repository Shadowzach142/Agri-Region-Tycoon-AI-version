extends SceneTree

func _init():
	for fp in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]:
		var pts := FarmerMovement.get_footprint_polygon_local(Vector2i(0, 0), fp)
		var center := (pts[0] + pts[2]) * 0.5
		var top = pts[0] - center
		var right = pts[1] - center
		var bottom = pts[2] - center
		var left = pts[3] - center
		var width = right.x - left.x
		var height = bottom.y - top.y
		print("Footprint %s: width=%.1f, height=%.1f, top=%s, right=%s, bottom=%s, left=%s" % [fp, width, height, top, right, bottom, left])
	quit()
