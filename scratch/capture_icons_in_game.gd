extends Node

func _ready() -> void:
	# Load and instantiate MainGame
	var main_scene = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main_scene)

	await get_tree().process_frame
	await get_tree().process_frame

	var farmer = main_scene.find_child("Farmer", true, false)
	if farmer:
		TaskManager.select_farmer(farmer)

	await get_tree().process_frame

	var hotbar = main_scene.find_child("PlantHotbar", true, false)
	if hotbar:
		# Set tools to clear (Axe)
		hotbar.selected_category_items["tools"] = "clear"
		hotbar.selected_category_items["treatments"] = "spray_biological"
		hotbar._update_category_slots_display()
		# Open flyout drawer for treatments to showcase both Chem and Duck
		hotbar._open_flyout_for_category("treatments")
		# Populate hover card for Duck
		hotbar._populate_hover_card("spray_biological")
		if hotbar.hover_card:
			hotbar.hover_card.visible = true

	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	var out_path := "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/new_icons_in_game.png"
	img.save_png(out_path)
	print("✔ Captured screenshot to: %s" % out_path)
	get_tree().quit(0)
