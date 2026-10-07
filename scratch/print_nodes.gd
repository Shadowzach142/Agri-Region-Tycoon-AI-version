@tool
extends SceneTree

func _init():
	var main_scene = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	func print_tree(node: Node, depth: int):
		if node is Control and node.visible:
			print("  ".repeat(depth), node.name, " [", node.get_class(), "] rect: ", node.get_global_rect())
		for c in node.get_children():
			print_tree(c, depth + 1)
			
	print_tree(main_scene, 0)
	quit()
