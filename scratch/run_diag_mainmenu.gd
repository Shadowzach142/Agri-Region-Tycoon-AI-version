extends Node

func _ready() -> void:
	print("--- Running MainMenu Diagnostic Runner ---")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.soundtrack_changed.connect(func(track):
			print("[EVENT] soundtrack_changed -> %s | Frame: %d | Time: %.2f" % [
				track, Engine.get_process_frames(), Time.get_ticks_msec() / 1000.0
			])
		)
		var bgm = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
		if bgm:
			bgm.finished.connect(func():
				print("[EVENT] BGMPlayer FINISHED signal fired! | Frame: %d" % Engine.get_process_frames())
			)
	
	var main_menu = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(main_menu)
	print("MainMenu added to tree!")

func _process(delta: float) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if not audio_mgr:
		return
	var bgm = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	if not bgm:
		return
	
	if Engine.get_process_frames() % 20 == 0:
		print("Frame %d: stream=%s | playing=%s | vol=%.2f | current_track=%s" % [
			Engine.get_process_frames(),
			bgm.stream.resource_path.get_file() if bgm.stream else "null",
			bgm.playing,
			bgm.volume_db,
			audio_mgr.get_current_soundtrack()
		])
	
	if Engine.get_process_frames() > 100:
		print("Diagnostic check complete.")
		get_tree().quit(0)
