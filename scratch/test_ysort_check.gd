extends SceneTree

func _init() -> void:
	var n = Node2D.new()
	print("Node2D has y_sort_origin: ", "y_sort_origin" in n)
	if "y_sort_origin" in n:
		print("Default y_sort_origin: ", n.y_sort_origin)
	quit(0)
