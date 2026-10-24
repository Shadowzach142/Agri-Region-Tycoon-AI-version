extends Node

func _ready() -> void:
	var main = load("res://scenes/MainGame.tscn").instantiate()
	add_child(main)
	
	for _i in range(5):
		await get_tree().process_frame
		
	var hotbar = main.find_child("PlantHotbar", true, false)
	hotbar._populate_crop_hover("palay")
	hotbar.hover_card.visible = true
	
	for _i in range(5):
		await get_tree().process_frame
		
	print("--- Hotbar Inspection ---")
	print("Hotbar rect: ", hotbar.get_global_rect())
	var vbox = hotbar.get_node("HotbarVBox")
	print("VBox rect: ", vbox.get_global_rect())
	print("VBox alignment: ", vbox.alignment)
	for c in vbox.get_children():
		print("  child: ", c.name, " visible: ", c.visible, " global_rect: ", c.get_global_rect(), " min: ", c.get_combined_minimum_size())
		if c.name == "CropHoverCard":
			for sub in c.get_children():
				print("    hover child: ", sub.name, " rect: ", sub.get_global_rect(), " min: ", sub.get_combined_minimum_size())
				for s2 in sub.get_children():
					print("      s2: ", s2.name, " rect: ", s2.get_global_rect(), " min: ", s2.get_combined_minimum_size())
	
	# Let's save a full viewport screenshot to check visually
	var tex = get_viewport().get_texture()
	var img = tex.get_image()
	img.save_png("res://scratch/full_viewport_hover_test.png")
	print("Saved scratch/full_viewport_hover_test.png")
	get_tree().quit(0)
