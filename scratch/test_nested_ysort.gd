@tool
extends SceneTree

func _init():
	# Test if Godot 4 y-sort sorts grandchildren across siblings
	var root_2d = Node2D.new()
	root_2d.y_sort_enabled = true
	root.add_child(root_2d)

	var container = Node2D.new()
	container.name = "Container"
	container.position = Vector2(0, 0)
	container.y_sort_enabled = true
	root_2d.add_child(container)

	var child_in_container = Sprite2D.new()
	child_in_container.name = "ChildInContainer"
	child_in_container.position = Vector2(0, 500) # Deep south
	container.add_child(child_in_container)

	var sibling = Sprite2D.new()
	sibling.name = "Sibling"
	sibling.position = Vector2(0, 200) # Between Container(0) and ChildInContainer(500)
	root_2d.add_child(sibling)

	print("Testing y-sort hierarchy...")
	# Let's check RenderingServer canvas item sort
	var rs = RenderingServer
	print("CanvasItem rendering test created successfully")
	quit(0)
