extends Node

func _ready() -> void:
	print("--- Diagnostic: Testing all 3 soundtracks loop settings ---")
	var tracks = [
		"res://sounds/soundtracks/countryside_morning.wav",
		"res://sounds/soundtracks/pastoral_breeze.wav",
		"res://sounds/soundtracks/dusk_at_homestead.wav"
	]
	
	for path in tracks:
		var stream = load(path) as AudioStreamWAV
		var frames = int(stream.get_length() * stream.mix_rate)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
		print("Track: %s | length=%.2fs | mix_rate=%d | frames=%d | loop_end=%d" % [
			path.get_file(), stream.get_length(), stream.mix_rate, frames, stream.loop_end
		])
	
	print("All 3 tracks configured with loop_end successfully.")
	get_tree().quit(0)
