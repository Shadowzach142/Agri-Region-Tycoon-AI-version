extends Node

func _ready() -> void:
	print("--- Diagnostic: Testing MainGame Audio Playback ---")
	var maingame = load("res://scenes/MainGame.tscn").instantiate()
	add_child(maingame)
	print("MainGame instantiated and added to tree.")

func _process(delta: float) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if not audio_mgr:
		return
	var bgm = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	if not bgm:
		return
	
	if Engine.get_process_frames() % 20 == 0:
		print("MainGame Frame %d: track=%s | playing=%s | vol=%.2f dB" % [
			Engine.get_process_frames(),
			audio_mgr.get_current_soundtrack(),
			bgm.playing,
			bgm.volume_db
		])
	
	if Engine.get_process_frames() >= 60:
		print("MainGame audio test verified!")
		get_tree().quit(0)
