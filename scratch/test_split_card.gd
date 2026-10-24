extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.22, 0.14)
	vp.add_child(bg)

	# Build split-card test
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(840, 0)
	panel.add_theme_stylebox_override("panel", preload("res://assets/sprites/hud/Samplebox.tres"))

	var center = CenterContainer.new()
	center.size = Vector2(1280, 720)
	center.add_child(panel)
	vp.add_child(center)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# Top Header
	var header = HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "🏛️ Grain Silo Compound"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08))
	header.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres"))
	close_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	header.add_child(close_btn)

	# Main Split Body
	var split_hbox = HBoxContainer.new()
	split_hbox.add_theme_constant_override("separation", 14)
	root_vbox.add_child(split_hbox)

	var brown_box = preload("res://assets/sprites/hud/TopRight/BrownBox.tres")

	# LEFT / CENTER: Bigger Box (Main Feature Box)
	var left_box = PanelContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 1.45
	left_box.add_theme_stylebox_override("panel", brown_box)
	split_hbox.add_child(left_box)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_box.add_child(left_vbox)

	# Left Feature Header
	var feat_title = Label.new()
	feat_title.text = "📦 Facility Storage Meter & Delivery Routing"
	feat_title.add_theme_font_size_override("font_size", 14)
	feat_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	left_vbox.add_child(feat_title)

	# Storage Meter Row
	var meter_row = HBoxContainer.new()
	left_vbox.add_child(meter_row)
	var meter_lbl = Label.new()
	meter_lbl.text = "Storage Capacity Fill:"
	meter_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_lbl.add_theme_font_size_override("font_size", 13)
	meter_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.70))
	meter_row.add_child(meter_lbl)

	var meter_val = Label.new()
	meter_val.text = "60 / 200 units (30%)"
	meter_val.add_theme_font_size_override("font_size", 13)
	meter_val.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))
	meter_row.add_child(meter_val)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = 200
	bar.value = 60
	bar.show_percentage = false

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.08, 0.05, 1.0)
	sb_bg.border_width_left = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color(0.48, 0.36, 0.22, 1.0)
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.28, 0.78, 0.35)
	sb_fill.corner_radius_top_left = 3
	sb_fill.corner_radius_top_right = 3
	sb_fill.corner_radius_bottom_left = 3
	sb_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", sb_fill)
	left_vbox.add_child(bar)

	# Routing Title
	var route_title = Label.new()
	route_title.text = "🌾 Accepted Crop Routing (Deliveries Allowed):"
	route_title.add_theme_font_size_override("font_size", 13)
	route_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	left_vbox.add_child(route_title)

	# Presets
	var preset_row = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	left_vbox.add_child(preset_row)

	var p_all = Button.new()
	p_all.text = "✨ All Crops"
	p_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_all.custom_minimum_size = Vector2(0, 28)
	p_all.add_theme_font_size_override("font_size", 12)
	p_all.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
	p_all.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08))
	preset_row.add_child(p_all)

	var p_grains = Button.new()
	p_grains.text = "🌾 Grains Only"
	p_grains.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_grains.custom_minimum_size = Vector2(0, 28)
	p_grains.add_theme_font_size_override("font_size", 12)
	p_grains.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	p_grains.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	preset_row.add_child(p_grains)

	var p_perish = Button.new()
	p_perish.text = "❄️ Perishables"
	p_perish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_perish.custom_minimum_size = Vector2(0, 28)
	p_perish.add_theme_font_size_override("font_size", 12)
	p_perish.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	p_perish.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	preset_row.add_child(p_perish)

	# 4x2 Grid of Crops
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(grid)

	var crops = [
		{"t": "✓ 🌾 Rice", "a": true},
		{"t": "✓ 🌽 Corn", "a": true},
		{"t": "✓ 🎋 Sugarcane", "a": true},
		{"t": "✓ 🍍 Pineapple", "a": true},
		{"t": "✓ ☕ Coffee", "a": true},
		{"t": "✓ 🍌 Banana", "a": true},
		{"t": "✓ 🥥 Coconut", "a": true},
		{"t": "🚫 Deselect All", "a": false, "special": true}
	]
	for c in crops:
		var btn = Button.new()
		btn.text = c.t
		btn.custom_minimum_size = Vector2(106, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		if c.get("special", false):
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.60))
		elif c.a:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
			btn.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08))
		else:
			btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
			btn.add_theme_color_override("font_color", Color(0.85, 0.78, 0.70))
		grid.add_child(btn)

	# RIGHT: Smaller Box (Upgrades, Explanation & Actions)
	var right_box = PanelContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_stretch_ratio = 0.95
	right_box.add_theme_stylebox_override("panel", brown_box)
	split_hbox.add_child(right_box)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_box.add_child(right_vbox)

	var lvl_lbl = Label.new()
	lvl_lbl.text = "⭐ Level 1 / 3"
	lvl_lbl.add_theme_font_size_override("font_size", 15)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	right_vbox.add_child(lvl_lbl)

	var status_lbl = Label.new()
	status_lbl.text = "✅ Active & Operating"
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.add_theme_color_override("font_color", Color(0.45, 0.90, 0.50))
	right_vbox.add_child(status_lbl)

	var cur_stats = Label.new()
	cur_stats.text = "📦 Crop Storage Capacity: 200 units\nCorrugated steel grain silo bin compound. Holds farm yields until regional market prices peak."
	cur_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cur_stats.add_theme_font_size_override("font_size", 12)
	cur_stats.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
	right_vbox.add_child(cur_stats)

	var sep = HSeparator.new()
	right_vbox.add_child(sep)

	var next_stats = Label.new()
	next_stats.text = "Next Tier (Level 2):\n📦 Crop Storage Capacity: 400 units\n💰 Cost: ₱800   ⏱️ Build Time: 30s"
	next_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_stats.add_theme_font_size_override("font_size", 12)
	next_stats.add_theme_color_override("font_color", Color(0.55, 0.95, 0.60))
	right_vbox.add_child(next_stats)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	# Actions
	var up_btn = Button.new()
	up_btn.text = "⬆️ Upgrade to Lv.2 (₱800)"
	up_btn.custom_minimum_size = Vector2(0, 42)
	up_btn.add_theme_font_size_override("font_size", 13)
	up_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/DarkWoodenButton/DarkWoodenButton.tres"))
	up_btn.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
	right_vbox.add_child(up_btn)

	var demo_btn = Button.new()
	demo_btn.text = "🗑️ Demolish (+₱250)"
	demo_btn.custom_minimum_size = Vector2(0, 34)
	demo_btn.add_theme_font_size_override("font_size", 13)
	demo_btn.add_theme_stylebox_override("normal", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	demo_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.80))
	right_vbox.add_child(demo_btn)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var img = vp.get_texture().get_image()
	if img:
		img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/test_split_card.png")
		print("✔ Captured test_split_card.png")

	get_tree().quit(0)
