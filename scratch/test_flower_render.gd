@tool
extends SceneTree

func _init() -> void:
	var flower_map := {
		"tile_041.png": "flower_santan.png",
		"tile_042.png": "flower_gumamela.png",
		"tile_043.png": "flower_garden_hedge.png",
		"tile_044.png": "flower_bougainvillea.png",
		"tile_045.png": "flower_topiary_shrub.png",
		"tile_046.png": "flower_wildflower_bed.png",
		"tile_047.png": "flower_blossom_cluster.png"
	}
	
	# Load a grass tile
	var grass_path := "res://assets/sprites/ground/NGRASS/NGRASS-01.png"
	var grass_img := Image.new()
	var err := grass_img.load(grass_path)
	if err != OK:
		print("Failed to load grass img, using blank diamond")
	
	var tile_w := 128
	var tile_h := 64
	var total_w := (tile_w + 16) * flower_map.size()
	var total_h := 120
	
	var out_img := Image.create(total_w, total_h, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0.08, 0.12, 0.10, 1.0)) # Dark garden backdrop
	
	var col_idx := 0
	for old_name in flower_map:
		var new_name: String = flower_map[old_name]
		var f_path: String = "res://assets/sprites/Decorations/Flowers/" + old_name
		var f_img := Image.new()
		f_img.load(f_path)
		
		var base_x := col_idx * (tile_w + 16) + 8
		var base_y := 30
		
		# Draw grass tile if available
		if grass_img != null and grass_img.get_width() > 0:
			for gy in range(grass_img.get_height()):
				for gx in range(grass_img.get_width()):
					var gc := grass_img.get_pixel(gx, gy)
					if gc.a > 0.05:
						out_img.set_pixel(base_x + gx, base_y + gy, gc)
						
		# Draw soft drop shadow under the flower
		var shadow_cx := base_x + 64
		var shadow_cy := base_y + 36
		for sy in range(-8, 9):
			for sx in range(-20, 21):
				var dist_sq := (float(sx) / 20.0) * (float(sx) / 20.0) + (float(sy) / 8.0) * (float(sy) / 8.0)
				if dist_sq <= 1.0:
					var px := shadow_cx + sx
					var py := shadow_cy + sy
					if px >= 0 and px < total_w and py >= 0 and py < total_h:
						var old_c := out_img.get_pixel(px, py)
						var shadow_alpha := (1.0 - dist_sq) * 0.40
						var blended := old_c.lerp(Color(0.02, 0.05, 0.02, 1.0), shadow_alpha)
						out_img.set_pixel(px, py, blended)
						
		# Blit flower at 2.0x integer scale
		var sc := 2
		var spr_w := f_img.get_width() * sc
		var spr_h := f_img.get_height() * sc
		var spr_x := base_x + int((tile_w - spr_w) * 0.5)
		var spr_y := base_y + int((tile_h - spr_h) * 0.5) + 2
		
		for fy in range(f_img.get_height()):
			for fx in range(f_img.get_width()):
				var fc := f_img.get_pixel(fx, fy)
				if fc.a > 0.1:
					for dy in range(sc):
						for dx in range(sc):
							var px := spr_x + fx * sc + dx
							var py := spr_y + fy * sc + dy
							if px >= 0 and px < total_w and py >= 0 and py < total_h:
								# Alpha blend with background
								var bg := out_img.get_pixel(px, py)
								var blended := bg.lerp(fc, fc.a)
								out_img.set_pixel(px, py, blended)
								
		col_idx += 1
		
	out_img.save_png("res://scratch/flowers_on_tiles_test.png")
	print("Saved flowers on tiles preview to res://scratch/flowers_on_tiles_test.png")
	quit(0)
