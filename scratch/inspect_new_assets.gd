@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING NEW ASSETS ---")
	var paths = [
		"res://assets/icons/Tempreture/Cold .png",
		"res://assets/icons/Tempreture/Fire.png",
		"res://assets/icons/Tempreture/Just-Right.png",
		"res://assets/icons/Tempreture/Sunny.png",
		"res://assets/sprites/hud/Buttons/WoodenButton/Wooden-button.png",
		"res://assets/sprites/hud/Buttons/DarkWoodenButton/Dark-Wooden-button.png",
		"res://assets/icons/HUD/Basket.png",
		"res://assets/icons/HUD/Build.png",
		"res://assets/icons/HUD/Market.png",
		"res://assets/icons/Tools/Pick.png",
		"res://assets/icons/Tools/watering.png",
		"res://assets/icons/Topleft/water-drop.png",
		"res://assets/icons/Disaster/Wave.png",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			var tex = load(p) as Texture2D
			if tex:
				print("%s => %dx%d" % [p, tex.get_width(), tex.get_height()])
			else:
				print("%s => FAILED TO CAST AS TEXTURE" % p)
		else:
			print("%s => NOT FOUND" % p)
	quit()
