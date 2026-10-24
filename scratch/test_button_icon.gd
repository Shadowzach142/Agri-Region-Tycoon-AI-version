@tool
extends SceneTree

func _init() -> void:
	var ctrl = Control.new()
	ctrl.custom_minimum_size = Vector2(400, 200)
	ctrl.size = Vector2(400, 200)

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(20, 20)
	hbox.add_theme_constant_override("separation", 10)
	ctrl.add_child(hbox)

	var style_normal = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
	var style_hover = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres")
	var style_pressed = load("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres")

	var icons = [
		{"name": "Shop", "path": "res://assets/icons/HUD/Build.png"},
		{"name": "Sell", "path": "res://assets/icons/HUD/Basket.png"},
		{"name": "Market", "path": "res://assets/icons/HUD/Market.png"}
	]

	for item in icons:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(46, 46)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.icon = load(item["path"])
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = false
		hbox.add_child(btn)

	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(400, 200)
	sub_viewport.add_child(ctrl)
	root.add_child(sub_viewport)

	await process_frame
	await process_frame

	var img = sub_viewport.get_texture().get_image()
	img.save_png("C:/Users/ADMIN/Documents/agri-region-ai-version/scratch/test_buttons_preview.png")
	print("Preview saved to scratch/test_buttons_preview.png")
	quit()
