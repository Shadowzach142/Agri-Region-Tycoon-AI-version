@tool
extends SceneTree

func _init():
	var inner_box_style = load("res://assets/sprites/hud/Inner-container/InnerBarBg.tres") as StyleBoxTexture
	print("Loaded InnerBarBg: ", inner_box_style)
	
	# Option 1: PanelContainer containing ProgressBar
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(100, 20)
	container.add_theme_stylebox_override("panel", inner_box_style)
	
	var empty_bg = StyleBoxEmpty.new()
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.30, 0.78, 0.25, 1)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_right = 2
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", empty_bg)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.value = 100.0
	bar.show_percentage = false
	container.add_child(bar)
	
	root.add_child(container)
	print("Container created successfully! Bar inside container at 100%")
	quit(0)
