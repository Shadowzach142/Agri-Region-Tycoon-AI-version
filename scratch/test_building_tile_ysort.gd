extends SceneTree

func _init() -> void:
	print("=== Y-SORT COORDINATE AUDIT: BUILDINGS VS ADJACENT TILES ===")
	var sizes = [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]
	var start_pos = Vector2i(4, 4)

	for fp in sizes:
		print("\n--- Testing Footprint %dx%d at %s ---" % [fp.x, fp.y, start_pos])
		# Building center
		var top_y = (float(start_pos.x) + float(start_pos.y)) * 32.0
		var bottom_y = (float(start_pos.x + fp.x) + float(start_pos.y + fp.y)) * 32.0
		var b_center_y = (top_y + bottom_y) * 0.5

		print("  Building Center Y: %.1f | Top Y: %.1f | Bottom Vertex Y: %.1f" % [b_center_y, top_y, bottom_y])

		# Check North/Behind tiles (should sort BEHIND building: tile_y < b_y)
		var behind_tiles = [
			Vector2i(start_pos.x - 1, start_pos.y),
			Vector2i(start_pos.x, start_pos.y - 1),
			Vector2i(start_pos.x - 1, start_pos.y - 1),
		]
		for t in behind_tiles:
			var t_y = (float(t.x) + float(t.y) + 1.0) * 32.0
			var diff = t_y - b_center_y
			print("    Behind tile %s: Y = %5.1f (diff vs center: %+5.1f) -> %s" % [
				t, t_y, diff, "BEHIND building (CORRECT)" if diff < 0 else "ERROR: In front!"
			])

		# Check South/In Front tiles (should sort IN FRONT of building: tile_y > b_y)
		var in_front_tiles = [
			Vector2i(start_pos.x + fp.x, start_pos.y + fp.y),
			Vector2i(start_pos.x + fp.x, start_pos.y + fp.y - 1),
			Vector2i(start_pos.x + fp.x - 1, start_pos.y + fp.y),
			Vector2i(start_pos.x, start_pos.y + fp.y),
			Vector2i(start_pos.x + fp.x, start_pos.y),
		]
		for t in in_front_tiles:
			var t_y = (float(t.x) + float(t.y) + 1.0) * 32.0
			var diff = t_y - b_center_y
			print("    Front  tile %s: Y = %5.1f (diff vs center: %+5.1f) -> %s" % [
				t, t_y, diff, "IN FRONT of building (CORRECT)" if diff > 0 else "ERROR: Behind!"
			])

	quit(0)
