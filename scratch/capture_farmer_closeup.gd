extends Node

func _ready() -> void:
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)

	var camera = maingame.find_child("GameCamera", true, false)
	var farmer = maingame.find_child("Farmer", true, false)
	if camera and farmer:
		camera.global_position = farmer.global_position
		camera.zoom = Vector2(2.5, 2.5)

	# Ensure idle state and not wandering
	farmer.is_wandering = false
	farmer.state = FarmerStateMachine.WorkerState.IDLE
	farmer._update_status_label()

	for _i in range(5):
		await get_tree().process_frame

	var viewport = get_viewport()
	var tex = viewport.get_texture()
	var img = tex.get_image()

	var w = viewport.size.x
	var h = viewport.size.y
	var crop_rect = Rect2i(int(w / 2 - 200), int(h / 2 - 150), 400, 300)
	var cropped = img.get_region(crop_rect)

	var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/farmer_overhead_ready.png"
	cropped.save_png(path)
	print("Saved ready closeup capture to: ", path)
	get_tree().quit(0)
