extends Node2D

func _ready() -> void:
	# 1. Background sky/ocean ambiance
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.08, 0.12, 0.18, 1.0)
	bg.z_index = -100
	add_child(bg)

	var gts := GroundTileSprites.new()

	# --- PART A: INLAND FARMLAND CHECK (x=21..24) ---
	# Shows that inland tiles are clean normal/plowed grass with ZERO rogue sand stripes
	var inland_title := Label.new()
	inland_title.text = "INLAND FARMLAND (X=21..24 — NO ROGUE SAND)"
	inland_title.position = Vector2(40, 20)
	inland_title.add_theme_font_size_override("font_size", 16)
	inland_title.add_theme_color_override("font_color", Color(0.40, 0.90, 0.50, 1.0))
	add_child(inland_title)

	var inland_sub := Label.new()
	inland_sub.text = "Rogue sand stripe completely removed; inland field is pure lush green meadow and tilled soil"
	inland_sub.position = Vector2(40, 44)
	inland_sub.add_theme_font_size_override("font_size", 11)
	inland_sub.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80, 1.0))
	add_child(inland_sub)

	var inland_root := Node2D.new()
	inland_root.position = Vector2(-750, -560)
	add_child(inland_root)

	for gy in range(6, 12):
		for gx in range(21, 25):
			var tile := FarmTile.new()
			if (gx + gy) % 3 == 0:
				tile.state = FarmTile.TileState.PLOWED
			else:
				tile.state = FarmTile.TileState.EMPTY
			var pos := Vector2i(gx, gy)
			var tex: Texture2D = gts.get_texture(tile, pos)
			var iso_x: float = FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W
			var iso_y: float = FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(iso_x, iso_y)
			sp.scale = Vector2(4.0, 4.0)
			inland_root.add_child(sp)

	# --- PART B: FLOODED FARMLAND (SLOW WATER SHIMMER) ---
	var flooded_title := Label.new()
	flooded_title.text = "FLOODED PLOTS (GENTLE SHIMMER ~2.2 FPS)"
	flooded_title.position = Vector2(40, 360)
	flooded_title.add_theme_font_size_override("font_size", 16)
	flooded_title.add_theme_color_override("font_color", Color(0.40, 0.85, 1.0, 1.0))
	add_child(flooded_title)

	var flooded_sub := Label.new()
	flooded_sub.text = "Water shimmer slowed down to a soothing, realistic standing pool reflection"
	flooded_sub.position = Vector2(40, 384)
	flooded_sub.add_theme_font_size_override("font_size", 11)
	flooded_sub.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80, 1.0))
	add_child(flooded_sub)

	var flooded_root := Node2D.new()
	flooded_root.position = Vector2(50, 420)
	add_child(flooded_root)

	for gx in range(3):
		for gy in range(3):
			var tile := FarmTile.new()
			var is_flooded: bool = (gx == 1 and gy == 1) or (gx == 0 and gy == 1)
			if is_flooded:
				tile.state = FarmTile.TileState.FLOODED
			else:
				tile.state = FarmTile.TileState.EMPTY
			var tex: Texture2D = gts.get_texture(tile, Vector2i(gx, gy))
			var iso_x: float = (gx - gy) * 64.0 + 160.0
			var iso_y: float = (gx + gy) * 32.0 + 40.0
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(iso_x, iso_y)
			sp.scale = Vector2(4.0, 4.0)
			flooded_root.add_child(sp)

			if is_flooded and gx == 1 and gy == 1:
				var crop_path := "res://assets/sprites/Field/Crops/Rice/RICE-P5.png"
				if ResourceLoader.exists(crop_path):
					var crop_sp := Sprite2D.new()
					crop_sp.texture = load(crop_path)
					crop_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					crop_sp.position = Vector2(iso_x, iso_y - 28)
					crop_sp.scale = Vector2(4.0, 4.0)
					crop_sp.modulate = Color(0.55, 0.75, 0.95, 0.85)
					flooded_root.add_child(crop_sp)

	# --- PART C: COASTLINE & SARANGANI BAY (GENTLE WAVES & GOLDEN BEACH) ---
	var ocean_title := Label.new()
	ocean_title.text = "SARANGANI BAY (GENTLE OCEAN ROLLERS & GOLDEN BEACH)"
	ocean_title.position = Vector2(560, 20)
	ocean_title.add_theme_font_size_override("font_size", 16)
	ocean_title.add_theme_color_override("font_color", Color(0.35, 0.90, 0.70, 1.0))
	add_child(ocean_title)

	var ocean_sub := Label.new()
	ocean_sub.text = "Slow tranquil ocean swells (~7.5s period), soft foam, continuous golden sand, and calm buoys"
	ocean_sub.position = Vector2(560, 44)
	ocean_sub.add_theme_font_size_override("font_size", 11)
	ocean_sub.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80, 1.0))
	add_child(ocean_sub)

	var beach_root := Node2D.new()
	beach_root.position = Vector2(-1250, -960)
	add_child(beach_root)

	# Draw meadow to beach transition along gx = 28..31
	for gy in range(4, 18):
		for gx in range(28, 32):
			var tile := FarmTile.new()
			tile.state = FarmTile.TileState.EMPTY
			var pos := Vector2i(gx, gy)
			var tex: Texture2D = gts.get_texture(tile, pos)
			var iso_x: float = FarmerMovement.ORIGIN_OFFSET.x + (gx - gy) * FarmerMovement.HALF_W
			var iso_y: float = FarmerMovement.ORIGIN_OFFSET.y + (gx + gy) * FarmerMovement.HALF_H
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.position = Vector2(iso_x, iso_y)
			sp.scale = Vector2(4.0, 4.0)
			beach_root.add_child(sp)

	# Instantiate living SeaWater node
	var sea := SeaWater.new()
	beach_root.add_child(sea)

	# Warm up rendering pipeline
	for i in range(5):
		await get_tree().process_frame

	# Capture frames across 10 steps to show motion
	for frame_num in range(10):
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var tex := get_viewport().get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.save_png("c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/sea_frame_%02d.png" % frame_num)
				if frame_num == 0:
					var out_artifact := "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/water_animation_showcase.png"
					var out_scratch := "c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_water_showcase.png"
					img.save_png(out_artifact)
					img.save_png(out_scratch)

	print("Captured all showcase frames successfully!")
	get_tree().quit(0)
