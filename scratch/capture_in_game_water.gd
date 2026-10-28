extends Node

func _ready() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var main_scene: PackedScene = load("res://scenes/MainGame.tscn")
	var game = main_scene.instantiate()
	add_child(game)

	for i in range(10):
		await get_tree().process_frame

	var camera = game.find_child("GameCamera", true, false)
	if camera:
		# Center camera on the eastern coastline and ocean
		var cam_pos := Vector2(1850, 1250)
		var cam_zoom := Vector2(0.65, 0.65)
		camera.position = cam_pos
		camera.target_position = cam_pos
		camera.zoom = cam_zoom
		camera.target_zoom = cam_zoom

	# Wait a few frames for animations and camera update
	for i in range(10):
		await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var tex := get_viewport().get_texture()
	if tex:
		var img := tex.get_image()
		if img:
			var out_artifact := "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/in_game_beach_water.png"
			var out_scratch := "c:/Users/ADMIN/Documents/agri-region-ai-version/scratch/shot_in_game_beach_water.png"
			img.save_png(out_artifact)
			img.save_png(out_scratch)
			print("Saved in_game_beach_water.png successfully!")

	get_tree().quit(0)
