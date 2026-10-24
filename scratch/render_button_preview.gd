@tool
extends SceneTree

func _init() -> void:
	var tex_market = load("res://assets/icons/HUD/Market.png")
	var tex_basket = load("res://assets/icons/HUD/Basket.png")
	var tex_build  = load("res://assets/icons/HUD/Build.png")

	var sq_brown = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
	var sq_brown_hover = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres")
	var sq_brown_pressed = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres")

	var sq_yellow = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareYellowButton.tres")
	var sq_yellow_hover = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareYellowButtonHover.tres")
	var sq_yellow_pressed = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareYellowButtonPressed.tres")

	# Render Option A: HBoxContainer
	var root_a = Control.new()
	root_a.size = Vector2(300, 100)

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(20, 20)
	hbox.add_theme_constant_override("separation", 8)
	root_a.add_child(hbox)

	var buttons_data = [
		{"name": "Market", "tex": tex_market, "style": sq_brown, "hover": sq_brown_hover, "pressed": sq_brown_pressed},
		{"name": "Sell", "tex": tex_basket, "style": sq_yellow, "hover": sq_yellow_hover, "pressed": sq_yellow_pressed},
		{"name": "Shop", "tex": tex_build, "style": sq_brown, "hover": sq_brown_hover, "pressed": sq_brown_pressed}
	]

	for data in buttons_data:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.add_theme_stylebox_override("normal", data["style"])
		btn.add_theme_stylebox_override("hover", data["hover"])
		btn.add_theme_stylebox_override("pressed", data["pressed"])
		btn.icon = data["tex"]
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = false
		hbox.add_child(btn)

	var vp_a = SubViewport.new()
	vp_a.size = Vector2i(300, 100)
	vp_a.add_child(root_a)
	root.add_child(vp_a)

	# Render Option B: VBoxContainer
	var root_b = Control.new()
	root_b.size = Vector2(100, 200)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 6)
	root_b.add_child(vbox)

	for data in buttons_data:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.add_theme_stylebox_override("normal", data["style"])
		btn.add_theme_stylebox_override("hover", data["hover"])
		btn.add_theme_stylebox_override("pressed", data["pressed"])
		btn.icon = data["tex"]
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = false
		vbox.add_child(btn)

	var vp_b = SubViewport.new()
	vp_b.size = Vector2i(100, 200)
	vp_b.add_child(root_b)
	root.add_child(vp_b)

	await process_frame
	await process_frame

	var img_a = vp_a.get_texture().get_image()
	img_a.save_png("C:/Users/ADMIN/Documents/agri-region-ai-version/scratch/preview_hbox.png")
	var img_b = vp_b.get_texture().get_image()
	img_b.save_png("C:/Users/ADMIN/Documents/agri-region-ai-version/scratch/preview_vbox.png")

	print("Rendered preview_hbox.png and preview_vbox.png successfully!")
	quit()
