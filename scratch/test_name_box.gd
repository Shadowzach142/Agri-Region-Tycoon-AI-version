@tool
extends SceneTree

func _init():
	var raw = Image.load_from_file("res://assets/sprites/StartMenu/long-rectangle.png")
	var min_x = raw.get_width()
	var min_y = raw.get_height()
	var max_x = 0
	var max_y = 0
	for y in range(raw.get_height()):
		for x in range(raw.get_width()):
			if raw.get_pixel(x, y).a > 0.05:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	var cropped = raw.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	var tex = ImageTexture.create_from_image(cropped)
	
	var sbt = StyleBoxTexture.new()
	sbt.texture = tex
	sbt.texture_margin_left = 12
	sbt.texture_margin_right = 12
	sbt.texture_margin_top = 10
	sbt.texture_margin_bottom = 10
	sbt.content_margin_left = 18
	sbt.content_margin_right = 18
	sbt.content_margin_top = 8
	sbt.content_margin_bottom = 8
	sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	# Test layout
	var root_ctrl = Control.new()
	root_ctrl.size = Vector2(800, 200)
	
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", sbt)
	box.custom_minimum_size = Vector2(520, 52)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	box.add_child(vbox)
	
	var lbl_name = Label.new()
	lbl_name.text = "🏆 TIMED RTS CAMPAIGN"
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 18)
	lbl_name.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
	vbox.add_child(lbl_name)
	
	var lbl_tag = Label.new()
	lbl_tag.text = "[ COMPETITIVE SCORE ATTACK • SEASON SPRINT ]"
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_tag.add_theme_font_size_override("font_size", 11)
	lbl_tag.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 1.0))
	vbox.add_child(lbl_tag)
	
	root_ctrl.add_child(box)
	box.position = Vector2(140, 50)
	
	var vp = SubViewport.new()
	vp.size = Vector2i(800, 200)
	root.add_child(vp)
	vp.add_child(root_ctrl)
	
	await process_frame
	await process_frame
	
	var img = vp.get_texture().get_image()
	img.save_png("scratch/test_name_box.png")
	print("Saved scratch/test_name_box.png, box min size: ", box.get_combined_minimum_size())
	quit()
