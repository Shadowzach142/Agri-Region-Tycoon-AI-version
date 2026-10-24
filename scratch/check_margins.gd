@tool
extends SceneTree

func _init() -> void:
	var img = Image.load_from_file("res://assets/sprites/hud/Buttons/WoodenButton/Wooden-button.png")
	var dark_img = Image.load_from_file("res://assets/sprites/hud/Buttons/DarkWoodenButton/Dark-Wooden-button.png")
	print("Wooden-button size: ", img.get_size())
	print("Dark-Wooden-button size: ", dark_img.get_size())

	# Check corner alpha
	print("Top-left pixel: ", img.get_pixel(0, 0))
	print("Center pixel: ", img.get_pixel(72, 15))
	quit()
