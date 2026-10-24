@tool
extends SceneTree

func _init():
	var style_inner = load("res://assets/sprites/hud/Inner-container/InnerBarBg.tres") as StyleBoxTexture
	assert(style_inner != null, "InnerBarBg must load")
	
	for val in [0.0, 71.0, 100.0]:
		var box = PanelContainer.new()
		box.custom_minimum_size = Vector2(100, 18)
		box.add_theme_stylebox_override("panel", style_inner)
		
		var empty_bg = StyleBoxEmpty.new()
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.30, 0.78, 0.25, 1)
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_right = 2
		
		var bar = ProgressBar.new()
		bar.layout_mode = 2
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("background", empty_bg)
		bar.add_theme_stylebox_override("fill", fill_style)
		bar.value = val
		bar.show_percentage = false
		
		box.add_child(bar)
		root.add_child(box)
		print("Tested bar at value=%.1f inside PanelContainer" % val)
	
	quit(0)
