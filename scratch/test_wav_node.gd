extends Node

var _player: AudioStreamPlayer
var _frames: int = 0

func _ready() -> void:
	print("--- Diagnostic: AudioStreamWAV with LOOP_DISABLED ---")
	var stream = load("res://sounds/soundtracks/countryside_morning.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.finished.connect(func():
		print("!!! PLAYER FINISHED SIGNAL EMITTED at frame %d, pos=%.3f, playing=%s !!!" % [
			_frames, _player.get_playback_position(), _player.playing
		])
	)
	add_child(_player)
	_player.play()
	print("Player started! is_playing=%s" % [_player.playing])

func _process(delta: float) -> void:
	_frames += 1
	if _frames % 10 == 0:
		print("Frame %d: pos=%.3f | playing=%s" % [_frames, _player.get_playback_position(), _player.playing])
	
	if _frames >= 60:
		print("Test completed.")
		get_tree().quit(0)
