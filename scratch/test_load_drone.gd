extends Node

func _ready() -> void:
	print("--- TEST LOAD DRONE ---")
	var scr = load("res://src/drone/FarmDrone.gd")
	print("scr: ", scr)
	var d = scr.new()
	print("d: ", d)
	get_tree().quit(0)
