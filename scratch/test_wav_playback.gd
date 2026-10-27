extends SceneTree

var _player: AudioStreamPlayer
var _frames: int = 0

func _init() -> void:
	print("--- Diagnostic: AudioStreamWAV Playback & Finished Signal ---")
	var stream = load("res://sounds/soundtracks/countryside_morning.wav") as AudioStreamWAV
	print("Stream format: %d | stereo: %s | mix_rate: %d | loop_mode: %d | loop_begin: %d | loop_end: %d | data size: %d" % [
		stream.format,
		stream.stereo,
		stream.mix_rate,
		stream.loop_mode,
		stream.loop_begin,
		stream.loop_end,
		stream.data.size()
	])
	
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.finished.connect(func():
		print("!!! PLAYER FINISHED SIGNAL EMITTED at frame %d, pos=%.3f, playing=%s !!!" % [
			_frames, _player.get_playback_position(), _player.playing
		])
	)
	root.add_child(_player)
	_player.play()
	print("Player started! is_playing=%s | stream_length=%.2f" % [_player.playing, stream.get_length()])

func _process(delta: float) -> bool:
	_frames += 1
	if _frames % 10 == 0:
		print("Frame %d: pos=%.3f | playing=%s" % [_frames, _player.get_playback_position(), _player.playing])
	
	if _frames >= 60:
		print("Test completed.")
		quit(0)
		return true
	return false
