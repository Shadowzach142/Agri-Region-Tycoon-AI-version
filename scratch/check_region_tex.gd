@tool
extends SceneTree

func _init() -> void:
	var tex = load("res://assets/sprites/hud/TopLeft/Region-climate-humidity.png") as Texture2D
	if tex:
		print("Region-climate-humidity size: ", tex.get_size())
	quit()
