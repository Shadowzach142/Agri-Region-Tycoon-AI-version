@tool
extends SceneTree

func _init():
	var panel = PanelContainer.new()
	var clip_style = load("res://assets/sprites/hud/BottomLeft/Clipboard.tres")
	panel.add_theme_stylebox_override("panel", clip_style)
	panel.custom_minimum_size = Vector2(400, 226)
	panel.size = Vector2(400, 226)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)
	
	var portrait_box = VBoxContainer.new()
	portrait_box.custom_minimum_size = Vector2(130, 0)
	portrait_box.add_theme_constant_override("separation", 3)
	hbox.add_child(portrait_box)
	
	var title = Label.new()
	title.text = "Tile (6, 5)"
	title.custom_minimum_size = Vector2(130, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_box.add_child(title)
	
	var plant_box = PanelContainer.new()
	var plant_style = load("res://assets/sprites/hud/BottomLeft/PlantBox.tres")
	plant_box.add_theme_stylebox_override("panel", plant_style)
	plant_box.custom_minimum_size = Vector2(72, 72)
	plant_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_box.add_child(plant_box)
	
	var crop_label = Label.new()
	crop_label.text = "Palay (Rice)"
	crop_label.custom_minimum_size = Vector2(130, 20)
	crop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crop_label.clip_text = true
	portrait_box.add_child(crop_label)
	
	var state_label = Label.new()
	state_label.text = "Ready for Harvest!"
	state_label.custom_minimum_size = Vector2(130, 18)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.clip_text = true
	portrait_box.add_child(state_label)
	
	var right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	hbox.add_child(right_box)
	
	var gauges_box = VBoxContainer.new()
	gauges_box.add_theme_constant_override("separation", 5)
	right_box.add_child(gauges_box)
	
	var inner_bar_style = load("res://assets/sprites/hud/Inner-container/InnerBarBg.tres")
	
	for gauge_data in [["Growth:", 0.0], ["Health:", 100.0], ["Moist:", 71.0]]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		
		var l = Label.new()
		l.text = gauge_data[0]
		l.custom_minimum_size = Vector2(56, 0)
		row.add_child(l)
		
		var bar_box = PanelContainer.new()
		bar_box.add_theme_stylebox_override("panel", inner_bar_style)
		bar_box.custom_minimum_size = Vector2(88, 20)
		bar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.value = gauge_data[1]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.78, 0.25)
		fill.corner_radius_top_left = 2
		fill.corner_radius_bottom_left = 2
		fill.corner_radius_top_right = 2
		fill.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("fill", fill)
		bar_box.add_child(bar)
		row.add_child(bar_box)
		
		var val_l = Label.new()
		val_l.text = "%d%%" % int(gauge_data[1])
		val_l.custom_minimum_size = Vector2(40, 0)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		
		gauges_box.add_child(row)
		
	root.add_child(panel)
	print("Instantiated compact test panel successfully! Panel size:", panel.size)
	quit(0)
