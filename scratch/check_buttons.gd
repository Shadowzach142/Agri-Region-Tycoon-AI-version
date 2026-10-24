@tool
extends SceneTree

func _init() -> void:
	var b1 = load("res://assets/sprites/hud/Buttons/Brownbutton/HUD-brown button .png") as Texture2D
	var b2 = load("res://assets/sprites/hud/Buttons/WoodenButton/Wooden-button.png") as Texture2D
	var b3 = load("res://assets/sprites/hud/Buttons/DarkWoodenButton/Dark-Wooden-button.png") as Texture2D
	print("HUD-brown button: ", b1.get_size() if b1 else "null")
	print("Wooden-button: ", b2.get_size() if b2 else "null")
	print("Dark-Wooden-button: ", b3.get_size() if b3 else "null")
	quit()
