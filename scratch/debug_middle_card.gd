extends Node

func _ready() -> void:
	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	var desc = mm.get_node("%DescLabel")
	desc.custom_minimum_size = Vector2(800, 36)
	var pros = mm.get_node("%ProsText")
	pros.custom_minimum_size = Vector2(380, 60)
	var cons = mm.get_node("%ConsText")
	cons.custom_minimum_size = Vector2(380, 60)
	add_child(mm)
	var mc = mm.get_node("MiddleCard")
	print("With custom min sizes: MC offset_top: %f, offset_bottom: %f, diff: %f" % [mc.offset_top, mc.offset_bottom, mc.offset_bottom - mc.offset_top])
	get_tree().quit(0)
