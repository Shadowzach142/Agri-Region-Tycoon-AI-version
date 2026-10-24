extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.22, 0.14) # grass green background
	vp.add_child(bg)

	var popup_scene = load("res://scenes/BuildingCardPopup.tscn")
	var popup = popup_scene.instantiate()
	vp.add_child(popup)

	var silo = Building.new()
	silo.building_type = "bodega"
	silo.state = Building.BuildingState.ACTIVE
	silo.level = 1
	vp.add_child(silo)
	silo._setup_ui()

	popup.open_for_building(silo)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var img = vp.get_texture().get_image()
	if img:
		img.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/building_popup_current.png")
		print("✔ Captured building_popup_current.png")

	get_tree().quit(0)
