extends SceneTree

func _init() -> void:
	print("==================================================")
	print("   AGRI-REGION TYCOON: SOUNDTRACK SYSTEM TEST     ")
	print("==================================================")

	var audio_mgr = AudioManager
	if audio_mgr == null:
		push_error("FAIL: AudioManager singleton not found!")
		quit(1)
		return

	# 1. Verify soundtrack paths dictionary
	print("\n[Step 1] Checking SOUNDTRACK_PATHS in AudioManager...")
	var paths = audio_mgr.SOUNDTRACK_PATHS
	var expected_tracks = ["countryside_morning", "pastoral_breeze", "dusk_at_homestead"]
	for track_key in expected_tracks:
		if not paths.has(track_key):
			push_error("FAIL: Missing soundtrack path for key: %s" % track_key)
			quit(1)
			return
		var file_path = paths[track_key]
		if not FileAccess.file_exists(file_path):
			push_error("FAIL: Soundtrack file does not exist on disk: %s" % file_path)
			quit(1)
			return
		print("  ✓ Key '%s' -> %s" % [track_key, file_path])

	# 2. Verify titles
	print("\n[Step 2] Checking soundtrack titles...")
	for track_key in expected_tracks:
		var title = audio_mgr.get_soundtrack_title(track_key)
		print("  ✓ '%s' title: %s" % [track_key, title])
		if title.is_empty():
			push_error("FAIL: Empty title for track: " + track_key)
			quit(1)
			return

	# 3. Test playing each track
	print("\n[Step 3] Testing playback & crossfades for each track...")
	for track_key in expected_tracks:
		audio_mgr.play_soundtrack(track_key, 0.0) # instant switch for test
		if audio_mgr.get_current_soundtrack() != track_key:
			push_error("FAIL: Expected current track to be %s, but got %s" % [track_key, audio_mgr.get_current_soundtrack()])
			quit(1)
			return
		var p = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
		if not p or not p.playing:
			push_error("FAIL: BGMPlayer is not playing for track: " + track_key)
			quit(1)
			return
		var stream = p.stream
		if stream is AudioStreamWAV:
			print("  ✓ Playing '%s' | Stream: %s | Length: %.2fs | LoopMode: %d" % [
				track_key,
				stream.get_class(),
				stream.get_length(),
				stream.loop_mode
			])
		else:
			print("  ✓ Playing '%s' | Stream: %s | Length: %.2fs" % [
				track_key,
				stream.get_class(),
				stream.get_length() if stream.has_method("get_length") else 0.0
			])

	# 4. Test Next & Prev cycling
	print("\n[Step 4] Testing Next & Prev playlist cycling...")
	audio_mgr.play_soundtrack("countryside_morning", 0.0)
	audio_mgr.next_soundtrack()
	print("  After next_soundtrack(): %s" % audio_mgr.get_current_soundtrack())
	if audio_mgr.get_current_soundtrack() != "pastoral_breeze":
		push_error("FAIL: Expected pastoral_breeze after countryside_morning")
		quit(1)
		return

	audio_mgr.next_soundtrack()
	print("  After next_soundtrack(): %s" % audio_mgr.get_current_soundtrack())
	if audio_mgr.get_current_soundtrack() != "dusk_at_homestead":
		push_error("FAIL: Expected dusk_at_homestead after pastoral_breeze")
		quit(1)
		return

	audio_mgr.prev_soundtrack()
	print("  After prev_soundtrack(): %s" % audio_mgr.get_current_soundtrack())
	if audio_mgr.get_current_soundtrack() != "pastoral_breeze":
		push_error("FAIL: Expected pastoral_breeze after prev")
		quit(1)
		return

	# 5. Test volume and mute
	print("\n[Step 5] Testing volume and mute controls...")
	audio_mgr.set_music_volume(0.5)
	audio_mgr.set_music_muted(true)
	var p = audio_mgr.get_node_or_null("BGMPlayer") as AudioStreamPlayer
	if p.volume_db > -79.0:
		push_error("FAIL: Expected muted volume <= -80dB, got: %.1f" % p.volume_db)
		quit(1)
		return
	print("  ✓ Muted successfully (volume_db: %.1f)" % p.volume_db)

	audio_mgr.set_music_muted(false)
	if p.volume_db < -30.0:
		push_error("FAIL: Expected unmuted audible volume, got: %.1f" % p.volume_db)
		quit(1)
		return
	print("  ✓ Unmuted successfully (volume_db: %.1f)" % p.volume_db)

	# 6. Test TimeManager period change integration
	print("\n[Step 6] Testing context-aware day/night transition...")
	audio_mgr._on_time_period_changed("Dusk", true)
	if audio_mgr.get_current_soundtrack() != "dusk_at_homestead":
		push_error("FAIL: Expected transition to dusk_at_homestead at Dusk")
		quit(1)
		return
	print("  ✓ Transition to 'dusk_at_homestead' on Dusk/Night verified!")

	audio_mgr._on_time_period_changed("Morning", false)
	if audio_mgr.get_current_soundtrack() != "countryside_morning":
		push_error("FAIL: Expected transition to countryside_morning in Morning")
		quit(1)
		return
	print("  ✓ Transition to 'countryside_morning' on Morning verified!")

	print("\n==================================================")
	print("  ★ ALL SOUNDTRACK TESTS PASSED PERFECTLY! ★      ")
	print("==================================================")
	quit(0)
