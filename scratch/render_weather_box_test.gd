@tool
extends SceneTree

func _init() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(500, 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var bg_color = ColorRect.new()
	bg_color.size = Vector2(500, 200)
	bg_color.color = Color(0.12, 0.22, 0.13, 1)
	vp.add_child(bg_color)

	# Build RegionWeatherBox
	var rwb = Control.new()
	rwb.size = Vector2(227, 123)
	rwb.position = Vector2(20, 20)

	var bg = TextureRect.new()
	bg.texture = load("res://assets/sprites/hud/TopLeft/Region-climate-humidity.png")
	bg.size = Vector2(227, 123)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rwb.add_child(bg)

	var reg_lbl = Label.new()
	reg_lbl.text = "Cotabato Basin"
	reg_lbl.position = Vector2(29, 16)
	reg_lbl.size = Vector2(166, 25)
	reg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reg_lbl.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1))
	reg_lbl.add_theme_font_size_override("font_size", 20)
	rwb.add_child(reg_lbl)

	# WeatherRow
	var w_row = HBoxContainer.new()
	w_row.position = Vector2(29, 53)
	w_row.size = Vector2(83, 39)
	w_row.alignment = BoxContainer.ALIGNMENT_CENTER
	w_row.add_theme_constant_override("separation", 4)

	var w_icon = TextureRect.new()
	w_icon.texture = load("res://assets/icons/Tempreture/Sunny.png")
	w_icon.custom_minimum_size = Vector2(22, 22)
	w_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w_row.add_child(w_icon)

	var w_lbl = Label.new()
	w_lbl.text = "28°C"
	w_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	w_lbl.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1))
	w_lbl.add_theme_font_size_override("font_size", 18)
	w_row.add_child(w_lbl)
	rwb.add_child(w_row)

	# HumidityRow
	var h_row = HBoxContainer.new()
	h_row.position = Vector2(112, 53)
	h_row.size = Vector2(83, 39)
	h_row.alignment = BoxContainer.ALIGNMENT_CENTER
	h_row.add_theme_constant_override("separation", 4)

	var h_icon = TextureRect.new()
	h_icon.texture = load("res://assets/icons/Topleft/water-drop.png")
	h_icon.custom_minimum_size = Vector2(18, 18)
	h_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h_row.add_child(h_icon)

	var h_lbl = Label.new()
	h_lbl.text = "65%"
	h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_lbl.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1))
	h_lbl.add_theme_font_size_override("font_size", 18)
	h_row.add_child(h_lbl)
	rwb.add_child(h_row)

	vp.add_child(rwb)
	root.add_child(vp)

	# Also test wooden button right next to it
	var btn = Button.new()
	btn.text = "BACKLOG (L)"
	btn.position = Vector2(280, 50)
	btn.custom_minimum_size = Vector2(160, 36)
	var sb = load("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres") as StyleBox
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84, 1))
	btn.add_theme_font_size_override("font_size", 13)
	vp.add_child(btn)

	# Wait 2 frames and save image
	await process_frame
	await process_frame

	var img = vp.get_texture().get_image()
	img.save_png("scratch/test_weather_box_render.png")
	print("Saved scratch/test_weather_box_render.png!")
	quit()
