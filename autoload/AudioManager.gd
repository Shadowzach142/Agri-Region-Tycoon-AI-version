# AudioManager.gd
# Central Audio & Sound System for Agri-Region Tycoon.
# Manages polyphonic sound effect pools, pitch variation, volume controls,
# and hooks directly into gameplay events across farmers, buildings, and UI.

extends Node

signal sfx_played(sound_name: String)

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

	# UI / HUD
	"ui_click": "res://sounds/UI-HUD/click.wav",
	"ui_hover": "res://sounds/UI-HUD/hover.wav",
	"ui_error": "res://sounds/UI-HUD/error.wav",
	"ui_pause": "res://sounds/UI-HUD/pause.wav",
	"tile_select": "res://sounds/UI-HUD/tile select.wav"
}

# Preloaded AudioStream instances
var _streams: Dictionary = {}

# Audio Player Pools
const POOL_SIZE: int = 16
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# Dedicated Looping Player for Construction / Upgrades
var _build_loop_player: AudioStreamPlayer = null
var _active_construction_count: int = 0

# Volume & settings
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 0.85
var is_muted: bool = false

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
	"chop": 0.08
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
		"loop", "building_loop":
			start_build_loop()
		_:
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
# Global Game Event Listeners
# ---------------------------------------------------------------------------
func _connect_game_signals() -> void:
	# 1. Building Manager
	var b_mgr = get_node_or_null("/root/BuildingManager")
	if b_mgr:
		if b_mgr.has_signal("building_placed"):
			b_mgr.building_placed.connect(func(_b): play_building("place"))

	# 2. Task Manager (Farmer selection & assignments)
	var t_mgr = get_node_or_null("/root/TaskManager")
	if t_mgr:
		if t_mgr.has_signal("selection_changed"):
			t_mgr.selection_changed.connect(func(selected):
				if selected.size() > 0:
					play_farmer("select")
			)

	# 3. Time Manager (Pause toggle)
	var time_mgr = get_node_or_null("/root/TimeManager")
	if time_mgr:
		# Check speed changes for pause sound
		pass

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
