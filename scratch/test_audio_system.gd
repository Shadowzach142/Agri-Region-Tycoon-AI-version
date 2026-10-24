# scratch/test_audio_system.gd
extends Node

func _ready() -> void:
	print("\n==================================================")
	print("Starting Comprehensive Audio System Verification")
	print("==================================================")

	var audio_mgr = AudioManager
	assert(audio_mgr != null, "AudioManager must be active")

	# ----------------------------------------------------
	# 1. Verify All Sound Streams Loaded in Memory
	# ----------------------------------------------------
	var expected_keys = [
		# Farmer actions
		"assign", "chop", "harvest", "plant", "plow", "farmer_select", "spray", "water",
		# Buildings
		"building_place", "building_loop", "building_complete",
		"building_cancel", "building_demolish", "building_invalid",
		# Economy
		"earn", "insufficient", "market_sell", "new_day", "spend",
		# Pests & Disasters
		"hazard_cleared", "disaster_drought", "disaster_flood", "disaster_landslide",
		"hazard_spawn", "pest_spread",
		# Time & Tech
		"hire_worker", "tech_unlock", "time_pause",
		# UI / HUD
		"ui_click", "ui_hover", "ui_error", "ui_pause", "tile_select"
	]

	print("\n1. Verifying audio streams loaded in AudioManager._streams (%d expected):" % expected_keys.size())
	var missing: Array = []
	for k in expected_keys:
		if not audio_mgr._streams.has(k) or audio_mgr._streams[k] == null:
			missing.append(k)
		else:
			var s: AudioStream = audio_mgr._streams[k]
			assert(s.get_length() > 0.0, "Stream length for %s must be > 0s" % k)
	
	if missing.size() > 0:
		print("❌ Missing streams: ", missing)
		assert(false, "Some sound streams failed to load!")
	else:
		print("✔ All %d sound streams loaded successfully!" % expected_keys.size())

	# ----------------------------------------------------
	# 2. Test Semantic Playback Methods & Signal Emission
	# ----------------------------------------------------
	print("\n2. Testing Semantic Audio API:")
	var played_sounds: Array[String] = []
	audio_mgr.sfx_played.connect(func(snd): played_sounds.append(snd))

	# Buildings
	played_sounds.clear()
	audio_mgr.play_building("cancel")
	assert("building_cancel" in played_sounds, "play_building(cancel) must play building_cancel")

	played_sounds.clear()
	audio_mgr.play_building("demolish")
	assert("building_demolish" in played_sounds, "play_building(demolish) must play building_demolish")

	played_sounds.clear()
	audio_mgr.play_building("invalid")
	assert("building_invalid" in played_sounds, "play_building(invalid) must play building_invalid")

	print("✔ Building audio API verified (cancel, demolish, invalid).")

	# Economy
	played_sounds.clear()
	audio_mgr.play_economy("earn")
	assert("earn" in played_sounds, "play_economy(earn) must play earn")

	played_sounds.clear()
	audio_mgr.play_economy("spend")
	assert("spend" in played_sounds, "play_economy(spend) must play spend")

	played_sounds.clear()
	audio_mgr.play_economy("insufficient")
	assert("insufficient" in played_sounds, "play_economy(insufficient) must play insufficient")

	played_sounds.clear()
	audio_mgr.play_economy("market_sell")
	assert("market_sell" in played_sounds, "play_economy(market_sell) must play market_sell")

	played_sounds.clear()
	audio_mgr.play_economy("new_day")
	assert("new_day" in played_sounds, "play_economy(new_day) must play new_day")

	print("✔ Economy audio API verified (earn, spend, insufficient, market_sell, new_day).")

	# Pests & Disasters
	played_sounds.clear()
	audio_mgr.play_disaster("flood")
	assert("disaster_flood" in played_sounds, "play_disaster(flood) must play disaster_flood")

	played_sounds.clear()
	audio_mgr.play_disaster("drought")
	assert("disaster_drought" in played_sounds, "play_disaster(drought) must play disaster_drought")

	played_sounds.clear()
	audio_mgr.play_disaster("landslide")
	assert("disaster_landslide" in played_sounds, "play_disaster(landslide) must play disaster_landslide")

	played_sounds.clear()
	audio_mgr.play_disaster("warning")
	assert("hazard_spawn" in played_sounds, "play_disaster(warning) must play hazard_spawn")

	played_sounds.clear()
	audio_mgr.play_disaster("cleared")
	assert("hazard_cleared" in played_sounds, "play_disaster(cleared) must play hazard_cleared")

	played_sounds.clear()
	audio_mgr.play_disaster("spread")
	assert("pest_spread" in played_sounds, "play_disaster(spread) must play pest_spread")

	print("✔ Pest & Disaster audio API verified (flood, drought, landslide, warning, cleared, spread).")

	# Tech & Time
	played_sounds.clear()
	audio_mgr.play_tech("unlock")
	assert("tech_unlock" in played_sounds, "play_tech(unlock) must play tech_unlock")

	played_sounds.clear()
	audio_mgr.play_tech("hire")
	assert("hire_worker" in played_sounds, "play_tech(hire) must play hire_worker")

	played_sounds.clear()
	audio_mgr.play_tech("pause")
	assert("time_pause" in played_sounds, "play_tech(pause) must play time_pause")

	print("✔ Time & Tech audio API verified (unlock, hire, pause).")

	# ----------------------------------------------------
	# 3. Test Signal Integration Across Autoloads
	# ----------------------------------------------------
	print("\n3. Testing Autoload Signal Integration:")

	# Test EconomyManager spend / earn / insufficient
	EconomyManager.cash = 1000
	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	var ok_deduct = EconomyManager.deduct_cash(100)
	assert(ok_deduct, "deduct_cash must succeed")
	assert("spend" in played_sounds, "deduct_cash must trigger spend sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	EconomyManager.add_cash(500)
	assert("earn" in played_sounds, "add_cash must trigger earn sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	var fail_deduct = EconomyManager.deduct_cash(999999)
	assert(not fail_deduct, "deduct_cash exceeding funds must fail")
	assert("insufficient" in played_sounds, "insufficient funds must trigger insufficient sound")

	# Test BuildingManager worker hired & tech unlocked
	played_sounds.clear()
	BuildingManager.worker_hired.emit(2)
	assert("hire_worker" in played_sounds, "worker_hired signal must trigger hire_worker sound")

	played_sounds.clear()
	BuildingManager.tech_unlocked.emit("field_survey_kit")
	assert("tech_unlock" in played_sounds, "tech_unlocked signal must trigger tech_unlock sound")

	# Test TimeManager day_changed
	played_sounds.clear()
	TimeManager.day_changed.emit(2)
	assert("new_day" in played_sounds, "day_changed signal must trigger new_day sound")

	# Test MarketManager sale_completed
	played_sounds.clear()
	MarketManager.sale_completed.emit("palay", 1000, 950, "Tacurong", 0.0)
	assert("market_sell" in played_sounds, "sale_completed signal must trigger market_sell sound")

	# Test WeatherManager signals
	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	WeatherManager.disaster_warning.emit("flash_flood", 5.0)
	assert("hazard_spawn" in played_sounds, "disaster_warning signal must trigger hazard_spawn sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	WeatherManager.disaster_struck.emit("flash_flood")
	assert("disaster_flood" in played_sounds, "disaster_struck(flash_flood) must trigger disaster_flood sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	WeatherManager.disaster_cleared.emit("flash_flood")
	assert("hazard_cleared" in played_sounds, "disaster_cleared signal must trigger hazard_cleared sound")

	# Test PestManager signals
	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	PestManager.pest_spawned.emit("kuhol", Vector2i(1, 1))
	assert("hazard_spawn" in played_sounds, "pest_spawned signal must trigger hazard_spawn sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	PestManager.pest_cleared.emit("kuhol", Vector2i(1, 1))
	assert("hazard_cleared" in played_sounds, "pest_cleared signal must trigger hazard_cleared sound")

	played_sounds.clear()
	audio_mgr._last_play_time.clear()
	PestManager.pest_spread.emit(3)
	assert("pest_spread" in played_sounds, "pest_spread signal must trigger pest_spread sound")

	print("✔ All autoload signal integrations verified!")

	print("\n==================================================")
	print("🎉 ALL 17 NEW SOUNDS IMPLEMENTED & VERIFIED 100%! 🎉")
	print("==================================================")
	get_tree().quit(0)
