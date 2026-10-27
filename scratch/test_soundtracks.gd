extends SceneTree

func _init() -> void:
	print("--- Testing Soundtrack Audio Loading ---")
	var tracks = [
		"res://sounds/soundtracks/countryside_morning.wav",
		"res://sounds/soundtracks/pastoral_breeze.wav",
		"res://sounds/soundtracks/dusk_at_homestead.wav"
	]
	
	for path in tracks:
		if not FileAccess.file_exists(path):
			push_error("File not found on disk: " + path)
			quit(1)
			return
		
		var stream = load(path)
		if stream == null:
			push_error("Failed to load stream: " + path)
			quit(1)
			return
		
		print("Loaded: %s | Type: %s | Length: %.2fs" % [
			path.get_file(),
			stream.get_class(),
			stream.get_length() if stream.has_method("get_length") else 0.0
		])
	
	print("[SUCCESS] All 3 soundtrack files exist and load as valid Godot AudioStreams!")
	quit(0)
