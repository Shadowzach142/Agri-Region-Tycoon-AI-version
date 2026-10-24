extends Node

func _ready() -> void:
	var popup_scene = load("res://scenes/BuildingCardPopup.tscn")
	var popup = popup_scene.instantiate()
	add_child(popup)
	
	var silo = Building.new()
	silo.building_type = "bodega"
	silo.state = Building.BuildingState.ACTIVE
	silo.level = 1
	add_child(silo)
	silo._setup_ui()
	
	popup.open_for_building(silo)
	print("Popup opened for bodega. Size: ", popup.panel.size, " min_size: ", popup.panel.custom_minimum_size)
	
	# Let's inspect children in StorageSection
	var storage_sec = popup.storage_section
	print("Storage section visible: ", storage_sec.visible)
	var grid = popup.crop_buttons_grid
	print("Crop grid class: ", grid.get_class(), " children: ", grid.get_child_count())
	for c in grid.get_children():
		print(" - ", c.name, " text: '", c.text, "' size: ", c.size, " min_size: ", c.custom_minimum_size)
	
	get_tree().quit(0)
