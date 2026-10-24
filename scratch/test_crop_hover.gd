extends Node2D

func _ready() -> void:
	var hud_scene = load("res://scenes/MainGame.tscn")
	var root = hud_scene.instantiate()
	add_child(root)
	
	# Wait a frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var hotbar = root.find_child("PlantHotbar", true, false)
	if hotbar:
		# Trigger hover on palay
		hotbar._populate_crop_hover("palay")
		hotbar.hover_card.visible = true
		print("Hover card visible: ", hotbar.hover_card.visible)
		print("Hover card size: ", hotbar.hover_card.size)
		print("Hover card pos: ", hotbar.hover_card.position)
		print("Hover card custom_min: ", hotbar.hover_card.custom_minimum_size)
		print("Hotbar size: ", hotbar.size)
		print("Hotbar pos: ", hotbar.position)
		
		# Take screenshot
		await get_tree().process_frame
		await get_tree().process_frame
		var img = get_viewport().get_texture().get_image()
		img.save_png("res://scratch/crop_hover_capture.png")
		print("Screenshot saved to scratch/crop_hover_capture.png")
	
	get_tree().quit()
