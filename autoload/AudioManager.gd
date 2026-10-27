# AudioManager.gd
# Central Audio & Sound System for Agri-Region Tycoon.
# Manages polyphonic sound effect pools, pitch variation, volume controls,
# and hooks directly into gameplay events across farmers, buildings, and UI.

extends Node

signal sfx_played(sound_name: String)
signal soundtrack_changed(track_name: String)

# ---------------------------------------------------------------------------
# Sound Library Paths
# ---------------------------------------------------------------------------
const SOUND_PATHS: Dictionary = {
	# Farmer actions
	"assign": "res://sounds/farmer actions/assign.wav",
	"chop": "res://sounds/farmer actions/chop.wav",
	"harvest": "res://sounds/farmer actions/harvest.wav",
	"plant": "res://sounds/farmer actions/plant.wav",
	"plow": "res://sounds/farmer actions/plow-final.wav",
	"farmer_select": "res://sounds/farmer actions/select.wav",
	"spray": "res://sounds/farmer actions/spray.wav",
	"water": "res://sounds/farmer actions/water-temp.wav",

	# Buildings
	"building_place": "res://sounds/buildings/place.wav",
	"building_loop": "res://sounds/buildings/build-loop.wav",
	"building_complete": "res://sounds/buildings/complete.wav",
	"building_cancel": "res://sounds/buildings/cancel.wav",
	"building_demolish": "res://sounds/buildings/demolish.wav",
	"building_invalid": "res://sounds/buildings/invalid.wav",

	# Economy
	"earn": "res://sounds/economy/earn.wav",
	"insufficient": "res://sounds/economy/insufficient.wav",
	"market_sell": "res://sounds/economy/market_sell.wav",
	"new_day": "res://sounds/economy/new_day.wav",
	"spend": "res://sounds/economy/spend.wav",

	# Pests & Disasters
	"hazard_cleared": "res://sounds/pest and disasters/cleared.wav",
	"disaster_drought": "res://sounds/pest and disasters/drought.wav",
	"disaster_flood": "res://sounds/pest and disasters/flood.wav",
	"disaster_landslide": "res://sounds/pest and disasters/landslide.wav",
	"hazard_spawn": "res://sounds/pest and disasters/spawn.wav",
	"pest_spread": "res://sounds/pest and disasters/spread.ogg",

	# Time & Tech
	"hire_worker": "res://sounds/time and tech/hire_worker.wav",
	"tech_unlock": "res://sounds/time and tech/tech_unlock.wav",
	"time_pause": "res://sounds/time and tech/time_pause.wav",

	# UI / HUD
	"ui_click": "res://sounds/UI-HUD/click.wav",
	"ui_hover": "res://sounds/UI-HUD/hover.wav",
	"ui_error": "res://sounds/UI-HUD/error.wav",
	"ui_pause": "res://sounds/UI-HUD/pause.wav",
	"tile_select": "res://sounds/UI-HUD/tile select.wav"
}

# ---------------------------------------------------------------------------
# Retro Chiptune Soundtrack Library
# ---------------------------------------------------------------------------
const SOUNDTRACK_PATHS: Dictionary = {
	"countryside_morning": "res://sounds/soundtracks/countryside_morning.wav",
	"pastoral_breeze": "res://sounds/soundtracks/pastoral_breeze.wav",
	"dusk_at_homestead": "res://sounds/soundtracks/dusk_at_homestead.wav"
}

const SOUNDTRACK_TITLES: Dictionary = {
	"countryside_morning": "Awit ng Bukid (Countryside Morning)",
	"pastoral_breeze": "Hanging Habagat (Pastoral Breeze)",
	"dusk_at_homestead": "Takipsilim (Dusk at Homestead)"
}

# Preloaded AudioStream instances
var _streams: Dictionary = {}
var _soundtrack_streams: Dictionary = {}

# Audio Player Pools
const POOL_SIZE: int = 16
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# Dedicated Looping Player for Construction / Upgrades
var _build_loop_player: AudioStreamPlayer = null
var _active_construction_count: int = 0

# Dedicated Looping Background Music (BGM) Player & Soundtrack State
var _bgm_player: AudioStreamPlayer = null
var _current_soundtrack: String = ""
var _soundtrack_playlist: Array[String] = [
	"countryside_morning",
	"pastoral_breeze",
	"dusk_at_homestead"
]
var _soundtrack_index: int = 0
var _bgm_tween: Tween = null

# Volume & mixing calibration
# BGM soundbed offset: sits comfortably -14 dB beneath foreground SFX so game actions always stand out
const BGM_BED_OFFSET_DB: float = -14.0

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 0.85
var music_volume: float = 0.50
var is_muted: bool = false
var is_music_muted: bool = false

# Throttle timers for rapid events (e.g. dragging across 20 tiles)
var _last_play_time: Dictionary = {}
const MIN_INTERVAL: Dictionary = {
	"ui_hover": 0.04,
	"tile_select": 0.06,
	"plow": 0.05,
	"plant": 0.05,
	"harvest": 0.05,
	"water": 0.05,
	"spray": 0.05,
	"chop": 0.08,
	"earn": 0.06,
	"spend": 0.06,
	"insufficient": 0.15,
	"building_invalid": 0.15,
	"hazard_spawn": 0.20,
	"pest_spread": 0.20
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preload_streams()
	_create_player_pools()
	_connect_game_signals()
	_hook_existing_buttons(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

# ---------------------------------------------------------------------------
# Setup & Pool Creation
# ---------------------------------------------------------------------------
func _preload_streams() -> void:
	for key in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream:
				_streams[key] = stream
		else:
			push_warning("[AudioManager] Missing sound file: %s" % path)

	for key in SOUNDTRACK_PATHS:
		var track_path: String = SOUNDTRACK_PATHS[key]
		if ResourceLoader.exists(track_path):
			var track_stream: AudioStream = load(track_path) as AudioStream
			if track_stream:
				_configure_wav_loop(track_stream)
				_soundtrack_streams[key] = track_stream
		else:
			push_warning("[AudioManager] Missing soundtrack file: %s" % track_path)

func _configure_wav_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var total_frames: int = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = total_frames

func _create_player_pools() -> void:
	# General SFX polyphonic pool
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)

	# Dedicated construction loop player
	_build_loop_player = AudioStreamPlayer.new()
	_build_loop_player.name = "BuildLoopPlayer"
	_build_loop_player.bus = "Master"
	_build_loop_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _streams.has("building_loop"):
		_build_loop_player.stream = _streams["building_loop"]
	add_child(_build_loop_player)

	# Dedicated Background Music (BGM) Player (loops continuously, never paused by game pauses)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

# ---------------------------------------------------------------------------
# Core Playback Methods
# ---------------------------------------------------------------------------
func play_sfx(sound_name: String, pitch_jitter: float = 0.06, volume_offset_db: float = 0.0) -> void:
	if is_muted:
		return

	if not _streams.has(sound_name):
		return

	# Rate limiting for spammy actions
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if MIN_INTERVAL.has(sound_name):
		var last_t: float = _last_play_time.get(sound_name, 0.0)
		if (now - last_t) < MIN_INTERVAL[sound_name]:
			return
		_last_play_time[sound_name] = now

	var player: AudioStreamPlayer = _get_available_player()
	if not player:
		return

	player.stream = _streams[sound_name]

	# Subtle random pitch jitter makes farm actions feel organic
	var pitch: float = 1.0
	if pitch_jitter > 0.0:
		pitch = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.pitch_scale = pitch

	# Volume calculation
	var vol: float = sfx_volume * master_volume
	if sound_name.begins_with("ui_") or sound_name == "tile_select":
		vol *= ui_volume
	var db: float = linear_to_db(max(vol, 0.001)) + volume_offset_db
	player.volume_db = clampf(db, -80.0, 6.0)

	player.play()
	sfx_played.emit(sound_name)

func _get_available_player() -> AudioStreamPlayer:
	# Try to find a player that is not currently playing
	for p in _sfx_players:
		if not p.playing:
			return p
	# Fallback to round-robin stealing oldest player
	var p: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % POOL_SIZE
	return p

# ---------------------------------------------------------------------------
# Semantic Playback API
# ---------------------------------------------------------------------------
func play_ui(sound_name: String) -> void:
	match sound_name:
		"click", "ui_click":
			play_sfx("ui_click", 0.04, -2.0)
		"hover", "ui_hover":
			play_sfx("ui_hover", 0.05, -6.0)
		"error", "ui_error":
			play_sfx("ui_error", 0.02, 0.0)
		"pause", "ui_pause":
			if _streams.has("time_pause"):
				play_sfx("time_pause", 0.0, 0.0)
			else:
				play_sfx("ui_pause", 0.0, 0.0)
		"tile_select":
			play_sfx("tile_select", 0.05, -1.0)
		_:
			play_sfx(sound_name, 0.03, 0.0)

func play_farmer(action_name: String) -> void:
	match action_name:
		"assign":
			play_sfx("assign", 0.04, 0.0)
		"chop", "clear", "clear_obstacle":
			play_sfx("chop", 0.06, 1.0)
		"harvest":
			play_sfx("harvest", 0.06, 1.0)
		"plant":
			play_sfx("plant", 0.05, 0.0)
		"plow":
			play_sfx("plow", 0.05, 0.0)
		"select", "farmer_select":
			play_sfx("farmer_select", 0.04, 0.0)
		"spray", "spray_pest":
			play_sfx("spray", 0.05, 0.0)
		"water":
			play_sfx("water", 0.05, 0.0)
		_:
			if SOUND_PATHS.has(action_name):
				play_sfx(action_name, 0.05, 0.0)

func play_building(event_name: String) -> void:
	match event_name:
		"place", "building_place":
			play_sfx("building_place", 0.03, 0.0)
		"complete", "building_complete":
			play_sfx("building_complete", 0.0, 2.0)
		"cancel", "building_cancel":
			play_sfx("building_cancel", 0.04, 0.0)
		"demolish", "building_demolish":
			play_sfx("building_demolish", 0.03, 1.0)
		"invalid", "building_invalid":
			play_sfx("building_invalid", 0.02, 0.0)
		"loop", "building_loop":
			start_build_loop()
		_:
			if SOUND_PATHS.has(event_name):
				play_sfx(event_name, 0.03, 0.0)

func play_economy(event_name: String) -> void:
	match event_name:
		"earn", "cash_earned":
			play_sfx("earn", 0.04, 0.0)
		"spend", "cash_spent":
			play_sfx("spend", 0.04, -1.0)
		"insufficient", "insufficient_funds":
			play_sfx("insufficient", 0.02, 0.0)
		"market_sell", "sell":
			play_sfx("market_sell", 0.03, 1.0)
		"new_day", "day":
			play_sfx("new_day", 0.0, 1.0)
		_:
			if SOUND_PATHS.has(event_name):
				play_sfx(event_name, 0.04, 0.0)

func play_disaster(hazard_or_event: String) -> void:
	match hazard_or_event:
		"flood", "flash_flood", "la_nina":
			play_sfx("disaster_flood", 0.03, 2.0)
		"drought", "heatwave", "el_nino":
			play_sfx("disaster_drought", 0.03, 2.0)
		"landslide":
			play_sfx("disaster_landslide", 0.03, 2.0)
		"warning", "hazard_warning", "spawn", "pest_spawn", "hazard_spawn":
			play_sfx("hazard_spawn", 0.04, 1.0)
		"cleared", "disaster_cleared", "pest_cleared", "hazard_cleared":
			play_sfx("hazard_cleared", 0.03, 0.0)
		"spread", "pest_spread":
			play_sfx("pest_spread", 0.05, 0.0)
		_:
			if SOUND_PATHS.has(hazard_or_event):
				play_sfx(hazard_or_event, 0.03, 0.0)

func play_tech(event_name: String) -> void:
	match event_name:
		"unlock", "tech_unlock":
			play_sfx("tech_unlock", 0.0, 2.0)
		"hire", "hire_worker":
			play_sfx("hire_worker", 0.04, 0.0)
		"pause", "time_pause":
			play_sfx("time_pause", 0.0, 0.0)
		_:
			if SOUND_PATHS.has(event_name):
				play_sfx(event_name, 0.03, 0.0)

# ---------------------------------------------------------------------------
# Looping Construction Ambient
# ---------------------------------------------------------------------------
func register_active_construction() -> void:
	_active_construction_count += 1
	if _active_construction_count > 0 and not _build_loop_player.playing:
		start_build_loop()

func unregister_active_construction() -> void:
	_active_construction_count = max(0, _active_construction_count - 1)
	if _active_construction_count == 0 and _build_loop_player.playing:
		stop_build_loop()

func start_build_loop() -> void:
	if is_muted or not _build_loop_player:
		return
	if not _build_loop_player.playing:
		var db: float = linear_to_db(sfx_volume * master_volume * 0.7)
		_build_loop_player.volume_db = clampf(db, -80.0, 6.0)
		_build_loop_player.play()

func stop_build_loop() -> void:
	if _build_loop_player and _build_loop_player.playing:
		_build_loop_player.stop()

# ---------------------------------------------------------------------------
# Background Music & Soundtracks API
# ---------------------------------------------------------------------------
func play_soundtrack(track_name: String = "", crossfade_duration: float = 1.2) -> void:
	if track_name.is_empty():
		track_name = _soundtrack_playlist[_soundtrack_index]

	if not _soundtrack_streams.has(track_name):
		if SOUNDTRACK_PATHS.has(track_name):
			var stream = load(SOUNDTRACK_PATHS[track_name]) as AudioStream
			if stream:
				_configure_wav_loop(stream)
				_soundtrack_streams[track_name] = stream
		if not _soundtrack_streams.has(track_name):
			push_warning("[AudioManager] Soundtrack not found: %s" % track_name)
			return

	if _current_soundtrack == track_name and _bgm_player and _bgm_player.playing:
		return

	_current_soundtrack = track_name
	var target_stream: AudioStream = _soundtrack_streams[track_name]
	var target_vol: float = _get_target_music_db()

	var idx = _soundtrack_playlist.find(track_name)
	if idx >= 0:
		_soundtrack_index = idx

	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()

	if _bgm_player.playing and crossfade_duration > 0.0:
		_bgm_tween = create_tween().set_parallel(false)
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, crossfade_duration * 0.4)
		_bgm_tween.tween_callback(func():
			_bgm_player.stream = target_stream
			_bgm_player.play()
		)
		_bgm_tween.tween_property(_bgm_player, "volume_db", target_vol, crossfade_duration * 0.6)
	else:
		_bgm_player.stream = target_stream
		_bgm_player.volume_db = target_vol
		_bgm_player.play()

	soundtrack_changed.emit(track_name)

func _get_target_music_db() -> float:
	if is_music_muted or is_muted or music_volume <= 0.001:
		return -80.0
	# Calibrated background music soundbed: sits comfortably underneath all SFX
	var linear_val: float = clampf(music_volume * master_volume, 0.0001, 1.0)
	var db: float = linear_to_db(linear_val) + BGM_BED_OFFSET_DB
	return clampf(db, -80.0, -10.0) # Hard ceiling ensures music is NEVER louder than SFX

func stop_soundtrack(fade_duration: float = 1.0) -> void:
	if not _bgm_player or not _bgm_player.playing:
		return
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()

	if fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_duration)
		_bgm_tween.tween_callback(func():
			_bgm_player.stop()
			_current_soundtrack = ""
		)
	else:
		_bgm_player.stop()
		_current_soundtrack = ""

func next_soundtrack() -> void:
	if _soundtrack_playlist.is_empty():
		return
	_soundtrack_index = (_soundtrack_index + 1) % _soundtrack_playlist.size()
	play_soundtrack(_soundtrack_playlist[_soundtrack_index], 1.0)

func prev_soundtrack() -> void:
	if _soundtrack_playlist.is_empty():
		return
	_soundtrack_index = (_soundtrack_index - 1 + _soundtrack_playlist.size()) % _soundtrack_playlist.size()
	play_soundtrack(_soundtrack_playlist[_soundtrack_index], 1.0)

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if _bgm_player and _bgm_player.playing:
		_bgm_player.volume_db = _get_target_music_db()

func set_music_muted(muted: bool) -> void:
	is_music_muted = muted
	if _bgm_player and _bgm_player.playing:
		_bgm_player.volume_db = _get_target_music_db()

func get_current_soundtrack() -> String:
	return _current_soundtrack

func get_soundtrack_title(track_name: String = "") -> String:
	if track_name.is_empty():
		track_name = _current_soundtrack
	return SOUNDTRACK_TITLES.get(track_name, track_name.capitalize())

func _on_soundtrack_finished() -> void:
	# If stream completes its run or advances, cycle naturally through the peaceful playlist
	next_soundtrack()

func _on_time_period_changed(period_name: String, is_night_time: bool) -> void:
	# Context-aware soundtrack transitions: play Takipsilim (dusk lullaby) at night,
	# and Countryside Morning or Pastoral Breeze during sunny day hours
	if is_night_time or period_name in ["Dusk", "Night", "Late Night"]:
		if _current_soundtrack != "dusk_at_homestead" and (_bgm_player and _bgm_player.playing):
			play_soundtrack("dusk_at_homestead", 2.5)
	elif period_name in ["Dawn", "Morning", "Midday", "Afternoon"]:
		if _current_soundtrack == "dusk_at_homestead" and (_bgm_player and _bgm_player.playing):
			play_soundtrack("countryside_morning", 2.5)

# ---------------------------------------------------------------------------
# Global Game Event Listeners
# ---------------------------------------------------------------------------
func _connect_game_signals() -> void:
	# 1. Building Manager
	var b_mgr = get_node_or_null("/root/BuildingManager")
	if b_mgr:
		if b_mgr.has_signal("building_placed"):
			b_mgr.building_placed.connect(func(_b): play_building("place"))
		if b_mgr.has_signal("worker_hired"):
			b_mgr.worker_hired.connect(func(_w): play_tech("hire_worker"))
		if b_mgr.has_signal("tech_unlocked"):
			b_mgr.tech_unlocked.connect(func(_t): play_tech("tech_unlock"))

	# 2. Task Manager (Farmer selection & assignments)
	var t_mgr = get_node_or_null("/root/TaskManager")
	if t_mgr:
		if t_mgr.has_signal("selection_changed"):
			t_mgr.selection_changed.connect(func(selected):
				if selected.size() > 0:
					play_farmer("select")
			)

	# 3. Time Manager (Day changed -> new day chime; Period changed -> day/night music transitions)
	var time_mgr = get_node_or_null("/root/TimeManager")
	if time_mgr:
		if time_mgr.has_signal("day_changed"):
			time_mgr.day_changed.connect(func(_d): play_economy("new_day"))
		if time_mgr.has_signal("period_changed"):
			time_mgr.period_changed.connect(_on_time_period_changed)

	# 4. Market Manager (Sale completed -> market sell cash register chime)
	var m_mgr = get_node_or_null("/root/MarketManager")
	if m_mgr:
		if m_mgr.has_signal("sale_completed"):
			m_mgr.sale_completed.connect(func(_c, _rev, _net, _hub, _rot): play_economy("market_sell"))

	# 5. Weather Manager (Disaster warning, strike, cleared)
	var w_mgr = get_node_or_null("/root/WeatherManager")
	if w_mgr:
		if w_mgr.has_signal("disaster_warning"):
			w_mgr.disaster_warning.connect(func(_hz, _cd): play_disaster("warning"))
		if w_mgr.has_signal("disaster_struck"):
			w_mgr.disaster_struck.connect(func(hz): play_disaster(hz))
		if w_mgr.has_signal("disaster_cleared"):
			w_mgr.disaster_cleared.connect(func(_hz): play_disaster("cleared"))

	# 6. Pest Manager (Pest spawned, cleared, spread)
	var p_mgr = get_node_or_null("/root/PestManager")
	if p_mgr:
		if p_mgr.has_signal("pest_spawned"):
			p_mgr.pest_spawned.connect(func(_p, _pos): play_disaster("spawn"))
		if p_mgr.has_signal("pest_cleared"):
			p_mgr.pest_cleared.connect(func(_p, _pos): play_disaster("cleared"))
		if p_mgr.has_signal("pest_spread"):
			p_mgr.pest_spread.connect(func(_cnt): play_disaster("spread"))


# ---------------------------------------------------------------------------
# Automatic Button Click & Hover Hooks
# ---------------------------------------------------------------------------
func _hook_existing_buttons(node: Node) -> void:
	if node is Button:
		_hook_button(node)
	for ch in node.get_children():
		_hook_existing_buttons(ch)

func _on_node_added(node: Node) -> void:
	if node is Button:
		_hook_button(node)

func _hook_button(btn: Button) -> void:
	if btn.has_meta("_audio_hooked"):
		return
	btn.set_meta("_audio_hooked", true)

	btn.pressed.connect(func():
		if not btn.has_meta("no_audio"):
			play_ui("click")
	)

	btn.mouse_entered.connect(func():
		if not btn.has_meta("no_audio") and not btn.disabled:
			play_ui("hover")
	)
