extends SceneTree

func _init() -> void:
	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	var root = get_root()
	root.add_child(mm)
	
	var hover_card = mm.get_node_or_null("%ModeHoverCard")
	print("hover_card: ", hover_card)
	if hover_card:
		print("visible: ", hover_card.visible)
		print("is_visible_in_tree: ", hover_card.is_visible_in_tree())
		print("size: ", hover_card.size)
		print("global_position: ", hover_card.global_position)
		print("modulate: ", hover_card.modulate)
		print("self_modulate: ", hover_card.self_modulate)
		for child in hover_card.get_children():
			print(" child: ", child.name, " vis: ", child.visible, " size: ", child.size)
	quit()
