extends Node2D

func _ready() -> void:
	var farmer_scene = load("res://scenes/MainGame.tscn")
	var game = farmer_scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	var farmer = game.find_child("Farmer", true, false)
	var sprite = farmer.find_child("FarmerSprite", true, false) as Sprite2D
	var label = farmer.find_child("FarmerLabel", true, false) as Label

	print("Farmer global_position: ", farmer.global_position)
	print("Sprite position: ", sprite.position, " scale: ", sprite.scale, " texture size: ", sprite.texture.get_size() if sprite.texture else Vector2.ZERO)
	print("Label offsets: left=", label.offset_left, " top=", label.offset_top, " right=", label.offset_right, " bottom=", label.offset_bottom)
	print("Label current text: '", label.text, "'")
	get_tree().quit(0)
