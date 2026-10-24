extends Node

func _ready() -> void:
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)
	
	# Wait for 3 frames for everything to render
	for _i in range(3):
		await get_tree().process_frame
		
	var viewport = get_viewport()
	var tex = viewport.get_texture()
	var img = tex.get_image()
	var path = "C:/Users/ADMIN/.gemini/antigravity-ide/brain/21406458-c30b-4286-8be8-288c1533c852/farmer_ingame_runtime_capture.png"
	img.save_png(path)
	print("Saved in-game runtime capture:", path)
	get_tree().quit(0)
