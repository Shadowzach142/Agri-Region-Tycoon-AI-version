extends SceneTree

func _init() -> void:
	print("Cold exists: ", ResourceLoader.exists("res://assets/icons/Tempreture/Cold .png"))
	print("Wave exists: ", ResourceLoader.exists("res://assets/icons/Disaster/Wave.png"))
	print("Warning exists: ", ResourceLoader.exists("res://assets/icons/Disaster/Warning.png"))
	print("Rice exists: ", ResourceLoader.exists("res://assets/icons/Plants/Rice.png"))
	quit(0)
