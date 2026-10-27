extends SceneTree

func _init() -> void:
	print("--- Diagnostic Test: MainMenu Music Playback ---")

func _process(delta: float) -> bool:
	var audio_mgr = root.get_node_or_null("AudioManager")
	if not audio_mgr:
		print("AudioManager not found yet...")
		return false
	
	var bgm = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	if not bgm:
		print("BGMPlayer not found in AudioManager!")
		quit(1)
		return true

	print("Frame check: BGM stream=%s | playing=%s | volume_db=%.2f | bus=%s" % [
		bgm.stream.resource_path if bgm.stream else "null",
		bgm.playing,
		bgm.volume_db,
		bgm.bus
	])
	
	# Wait for 3 seconds to observe volume tween
	if Time.get_ticks_msec() > 3000:
		print("3 seconds passed. Final volume: %.2f" % bgm.volume_db)
		quit(0)
		return true
	
	return false
