extends MainLoop

func _process(_delta: float) -> bool:
	var btn := Button.new()
	btn.text = "Housing Full"
	btn.disabled = true
	var sb := btn.get_theme_stylebox("disabled")
	print("Disabled stylebox type: ", sb.get_class())
	if sb is StyleBoxFlat:
		print("bg_color: ", sb.bg_color)
		print("border_color: ", sb.border_color)
		print("corner_radius: ", sb.corner_radius_top_left)
	var c := btn.get_theme_color("font_disabled_color")
	print("font_disabled_color: ", c)
	return true
