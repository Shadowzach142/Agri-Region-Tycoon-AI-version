extends Node

func _ready() -> void:
	print("--- Running test_hover_render ---")
	var hotbar_script = load("res://src/ui/PlantHotbar.gd")
	var hotbar = Control.new()
	hotbar.set_script(hotbar_script)
	hotbar.custom_minimum_size = Vector2(450, 300)
	hotbar.size = Vector2(450, 300)
	add_child(hotbar)
	
	# Wait for ready
	await get_tree().process_frame
	
	hotbar._populate_crop_hover("palay")
	hotbar.hover_card.visible = true
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Hover card size: ", hotbar.hover_card.size)
	print("Hover card min size: ", hotbar.hover_card.get_combined_minimum_size())
	for c in hotbar.hover_card.get_children():
		print("  child: ", c.name, " size: ", c.size, " min: ", c.get_combined_minimum_size())
		if c is VBoxContainer:
			for sub in c.get_children():
				print("    sub: ", sub.name, " size: ", sub.size, " min: ", sub.get_combined_minimum_size())
				if sub is VBoxContainer:
					for lbl in sub.get_children():
						print("      lbl: ", lbl.name, " text: ", lbl.text.substr(0, 30), " size: ", lbl.size, " min: ", lbl.get_combined_minimum_size())

	get_tree().quit()
