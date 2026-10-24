@tool
extends SceneTree

func _init() -> void:
	var tex_normal = load("res://assets/sprites/hud/Buttons/WoodenButton/Wooden-button.png") as Texture2D
	var tex_dark = load("res://assets/sprites/hud/Buttons/DarkWoodenButton/Dark-Wooden-button.png") as Texture2D

	var sb_normal = StyleBoxTexture.new()
	sb_normal.texture = tex_normal
	sb_normal.texture_margin_left = 10.0
	sb_normal.texture_margin_top = 6.0
	sb_normal.texture_margin_right = 10.0
	sb_normal.texture_margin_bottom = 9.0
	sb_normal.content_margin_left = 12.0
	sb_normal.content_margin_top = 4.0
	sb_normal.content_margin_right = 12.0
	sb_normal.content_margin_bottom = 7.0

	var btn = Button.new()
	btn.text = "BACKLOG (L)"
	btn.custom_minimum_size = Vector2(160, 36)
	btn.add_theme_stylebox_override("normal", sb_normal)
	print("Button test created successfully! Normal tex size: ", tex_normal.get_size(), " Dark tex size: ", tex_dark.get_size())
	quit()
