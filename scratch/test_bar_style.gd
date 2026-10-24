@tool
extends SceneTree

func _init():
	var tex = load("res://assets/sprites/hud/Inner-container/HUD-dark brown.png")
	if not tex:
		print("FAILED to load HUD-dark brown.png")
		quit(1)
		return
	print("Loaded texture: ", tex)
	
	var sb_bg = StyleBoxTexture.new()
	sb_bg.texture = tex
	sb_bg.texture_margin_left = 12.0
	sb_bg.texture_margin_top = 8.0
	sb_bg.texture_margin_right = 12.0
	sb_bg.texture_margin_bottom = 8.0
	sb_bg.content_margin_left = 4.0
	sb_bg.content_margin_top = 3.0
	sb_bg.content_margin_right = 4.0
	sb_bg.content_margin_bottom = 3.0
	sb_bg.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb_bg.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.35, 0.75, 0.25, 1)
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_right = 2
	sb_fill.corner_radius_bottom_left = 2
	
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(100, 20)
	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)
	bar.value = 65.0
	bar.show_percentage = false
	
	root.add_child(bar)
	print("ProgressBar successfully created with inner border background: value=", bar.value)
	quit(0)
