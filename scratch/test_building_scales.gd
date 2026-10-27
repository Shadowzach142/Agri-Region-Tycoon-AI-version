extends SceneTree

func _init() -> void:
	print("=== BUILDING SIZING & PROPORTION AUDIT ===")
	
	# Reference: Bahay Kubo
	var kubo_w = 64.0 * 2.0 # 128
	var kubo_h = 96.0 * 2.0 # 192
	var kubo_top = -156.0
	var kubo_bottom = kubo_top + kubo_h # +36.0
	print("REFERENCE: Bahay Kubo (2x2):")
	print("  Width: %.1f | Height: %.1f | Top Y: %.1f | Bottom Y: %.1f" % [kubo_w, kubo_h, kubo_top, kubo_bottom])
	print("")

	var configs = [
		{
			"type": "rice_mill",
			"file": "Kiskisan_Rice_Mill.png",
			"fp": Vector2i(3, 3),
			"scale": 3.4,
			"coff": Vector2(46.0, 54.0),
		},
		{
			"type": "coffee_roastery",
			"file": "Artisan_Coffee_Roastery.png",
			"fp": Vector2i(3, 3),
			"scale": 3.2,
			"coff": Vector2(52.0, 53.0),
		},
		{
			"type": "sugar_mill",
			"file": "Trapiche_Sugar_Central.png",
			"fp": Vector2i(4, 4),
			"scale": 3.4,
			"coff": Vector2(56.0, 52.0),
		},
		{
			"type": "copra_dryer",
			"file": "Tapahan_Copra_Dryer.png",
			"fp": Vector2i(4, 4),
			"scale": 3.4,
			"coff": Vector2(64.0, 52.0),
		},
		{
			"type": "tacurong_mill",
			"file": "Tacurong-Grain-mill.png",
			"fp": Vector2i(4, 4),
			"scale": 2.6,
			"coff": Vector2(80.0, 58.0),
		},
	]

	for c in configs:
		var path = "res://assets/sprites/buildings/" + c.file
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		var w = float(img.get_width())
		var h = float(img.get_height())
		var sc: float = c.scale
		var coff: Vector2 = c.coff
		var fp: Vector2i = c.fp
		
		# Diamond bounds for footprint
		var diamond_w = float(fp.x) * 128.0 # if symmetric
		var diamond_half_w = float(fp.x) * 64.0
		var diamond_bottom = float(fp.y) * 32.0
		
		var spr_w = w * sc
		var spr_h = h * sc
		var spr_pos_x = -coff.x * sc
		var spr_pos_y = -coff.y * sc
		var spr_top = spr_pos_y
		var spr_bottom = spr_pos_y + spr_h

		var h_diff = spr_h - kubo_h
		var top_diff = kubo_top - spr_top # positive means taller/higher reach than Kubo

		print("%-18s (fp: %dx%d, sc: %.1fx):" % [c.type, fp.x, fp.y, sc])
		print("  Sprite Size: %5.1fx%5.1f (H diff vs Kubo: %+5.1fpx)" % [spr_w, spr_h, h_diff])
		print("  Y Extents: Top: %5.1f (vs Kubo %5.1f, taller by %+5.1fpx) | Bottom: %5.1f (Diamond max: %5.1f)" % [
			spr_top, kubo_top, top_diff, spr_bottom, diamond_bottom
		])
		print("  Width Extents: [%5.1f to %5.1f] (Diamond half_w: %5.1f)" % [
			spr_pos_x, spr_pos_x + spr_w, diamond_half_w
		])
		print("")

	quit(0)
