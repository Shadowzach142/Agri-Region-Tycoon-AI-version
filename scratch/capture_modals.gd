extends Node

func _ready() -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mm = load("res://scenes/MainMenu.tscn").instantiate()
	vp.add_child(mm)
	mm._show_mode_select(false)

	# Open multiplayer modal
	mm._open_multiplayer_modal()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img1 = vp.get_texture().get_image()
	if img1:
		img1.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/multiplayer_modal.png")
		print("✔ Captured multiplayer_modal.png")

	# Close modal
	for c in mm.get_children():
		if c is CanvasLayer:
			c.queue_free()

	await get_tree().process_frame

	# Open options modal
	mm._open_options_modal()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img2 = vp.get_texture().get_image()
	if img2:
		img2.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/options_modal.png")
		print("✔ Captured options_modal.png")

	# Close modal
	for c in mm.get_children():
		if c is CanvasLayer:
			c.queue_free()

	await get_tree().process_frame

	# Open guide modal
	mm._open_guide_modal()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img3 = vp.get_texture().get_image()
	if img3:
		img3.save_png("C:/Users/ADMIN/.gemini/antigravity-ide/brain/bf1aec29-35f3-4398-8b83-35e7fecd62b4/scratch/guide_modal.png")
		print("✔ Captured guide_modal.png")

	get_tree().quit(0)
