extends SceneTree

func _init():
	var vp = SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(512, 512)
	bg.color = Color(0.44, 0.65, 0.28) # grass green
	vp.add_child(bg)
	
	var center = Vector2(256, 256)
	
	# Draw diamond border
	var border = Line2D.new()
	border.width = 2.0
	border.default_color = Color(0.18, 0.28, 0.14, 0.8)
	border.closed = true
	border.add_point(center + Vector2(0, -32))
	border.add_point(center + Vector2(64, 0))
	border.add_point(center + Vector2(0, 32))
	border.add_point(center + Vector2(-64, 0))
	vp.add_child(border)
	
	# Draw Rice P1 with offset_val = 7.0
	var tex = load("res://assets/sprites/Field/Crops/Rice/RICE-P1.png") as Texture2D
	var spr = Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.scale = Vector2(4.0, 4.0)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_h = float(tex.get_height())
	spr.offset = Vector2(0, 7.0 - tex_h / 2.0)
	spr.position = center
	vp.add_child(spr)
	
	# Wait 2 frames to render
	await process_frame
	await process_frame
	
	var img = vp.get_texture().get_image()
	img.save_png("res://scratch/test_rice_7.png")
	print("Saved scratch/test_rice_7.png")
	quit()
