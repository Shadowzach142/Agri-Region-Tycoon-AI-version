# MultiplayerManager.gd
# High-level LAN Multiplayer Singleton for Agri-Region Tycoon using Godot's
# ENetMultiplayerPeer & SceneMultiplayer RPC pipeline.
#
# Prototype Rules:
#   - 1 Team per Region (5 Regions = 5 Teams, 1 Player or AI per Region, no teammates).
#   - Players individually choose their Region/Team and unique Farmer Color (variants 0..7).
#   - Shared fast-paced RTS clock synced by Host (no Pause / no 1x-3x speed).
#   - Live periodic farm & farmer snapshots synced so players can view each other's farmers
#     from the toggleable Leaderboard HUD (or disable Leaderboard in Lobby for surprises).

extends Node

signal lobby_updated()
signal chat_received(sender_name: String, message: String, color: Color)
signal connection_status_changed(status_text: String, is_error: bool)
signal server_disconnected()
signal connection_failed()
signal match_started()
signal snapshots_updated()
signal spectate_changed(slot_id: String)
signal match_ended(final_standings: Array)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 8
const SNAPSHOT_INTERVAL: float = 0.35
const CLOCK_SYNC_INTERVAL: float = 1.0

# Each of the 5 regions corresponds 1:1 to a competing team (no teammates / co-op)
const REGION_TEAMS: Array[Dictionary] = [
	{"team": 1, "id": "cotabato",       "name": "Cotabato Basin",  "short": "Cotabato"},
	{"team": 2, "id": "south_cotabato", "name": "South Cotabato",  "short": "S. Cotabato"},
	{"team": 3, "id": "sarangani",      "name": "Sarangani Coast", "short": "Sarangani"},
	{"team": 4, "id": "sultan_kudarat", "name": "Sultan Kudarat",  "short": "S. Kudarat"},
	{"team": 5, "id": "general_santos", "name": "General Santos",  "short": "GenSan"}
]

# Farmer color variants 0..7 matching Farmer.gd VARIANT_NAMES exactly
const FARMER_COLORS: Array[Color] = [
	Color(0.18, 0.46, 0.94), # 0: Denim Blue
	Color(0.90, 0.20, 0.20), # 1: Ruby Red
	Color(0.20, 0.72, 0.26), # 2: Forest Green
	Color(0.54, 0.24, 0.84), # 3: Indigo Violet
	Color(0.96, 0.78, 0.16), # 4: Harvest Amber
	Color(0.10, 0.80, 0.72), # 5: Tropical Teal
	Color(0.94, 0.42, 0.68), # 6: Coral Rose
	Color(0.76, 0.64, 0.44)  # 7: Khaki Earth
]

const FARMER_COLOR_NAMES: Array[String] = [
	"Denim Blue",
	"Ruby Red",
	"Forest Green",
	"Indigo Violet",
	"Harvest Amber",
	"Tropical Teal",
	"Coral Rose",
	"Khaki Earth"
]

const SLOT_STATUS_CYCLE: Array[String] = [
	"Computer (Normal)",
	"Computer (Hard)",
	"Computer (Easy)",
	"Open",
	"Closed"
]

var is_active: bool = false
var is_host: bool = false
var is_network_connected: bool = false
var in_game_active: bool = false
var local_peer_id: int = 1
var local_player_name: String = "Ka Kanor"
var my_slot_id: String = "cotabato"

# Keyed by region_id ("cotabato", "south_cotabato", "sarangani", "sultan_kudarat", "general_santos")
var region_slots: Dictionary = {}

# Shared match settings (configured by Host in Lobby)
var match_settings: Dictionary = {}

# In-game synced farm/farmer state per region slot_id
var snapshots: Dictionary = {}
var ai_sim_states: Dictionary = {}
var spectating_slot_id: String = ""
var final_standings: Array = []

var _snapshot_timer: float = 0.0
var _clock_timer: float = 0.0
var _ai_sim_timer: float = 0.0
var _has_emitted_season_end: bool = false
var _cached_farm_grid: Node = null

func _get_farm_grid() -> Node:
	if is_instance_valid(_cached_farm_grid) and _cached_farm_grid.is_inside_tree():
		return _cached_farm_grid
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		_cached_farm_grid = get_tree().root.find_child("FarmGrid", true, false)
	return _cached_farm_grid

func _ready() -> void:
	reset_match_settings()
	init_default_lobby(local_player_name)
	_connect_multiplayer_signals()

func _connect_multiplayer_signals() -> void:
	var mp := multiplayer
	if mp == null:
		return
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)
	if not mp.connected_to_server.is_connected(_on_connected_ok):
		mp.connected_to_server.connect(_on_connected_ok)
	if not mp.connection_failed.is_connected(_on_connected_fail):
		mp.connection_failed.connect(_on_connected_fail)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)

func reset_match_settings() -> void:
	match_settings = {
		"mode": "rivalry",
		"days": 30,
		"cash": 2000,
		"crop_growth": 2.0,
		"build_speed": 2.0,
		"weather": "normal",
		"leaderboard_enabled": true
	}

func init_default_lobby(player_name: String = "Ka Kanor") -> void:
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Ka Kanor"

	region_slots.clear()
	for i in range(REGION_TEAMS.size()):
		var reg: Dictionary = REGION_TEAMS[i]
		var rid: String = str(reg["id"])
		if i == 0:
			region_slots[rid] = {
				"slot_id": rid,
				"team": int(reg["team"]),
				"region": rid,
				"region_name": str(reg["name"]),
				"region_short": str(reg["short"]),
				"type": "player",
				"peer_id": 1,
				"name": local_player_name,
				"status": "Player",
				"color_idx": i
			}
			my_slot_id = rid
		elif i == 1:
			region_slots[rid] = {
				"slot_id": rid,
				"team": int(reg["team"]),
				"region": rid,
				"region_name": str(reg["name"]),
				"region_short": str(reg["short"]),
				"type": "bot",
				"peer_id": -i,
				"name": "Computer (Normal)",
				"status": "Computer (Normal)",
				"color_idx": i
			}
		else:
			region_slots[rid] = {
				"slot_id": rid,
				"team": int(reg["team"]),
				"region": rid,
				"region_name": str(reg["name"]),
				"region_short": str(reg["short"]),
				"type": "open",
				"peer_id": 0,
				"name": "Open",
				"status": "Open",
				"color_idx": i
			}

	lobby_updated.emit()

# ---------------------------------------------------------------------------
# LAN Host / Join Lifecycle (Godot High-Level ENetMultiplayerPeer)
# ---------------------------------------------------------------------------
func host_lobby(port: int = DEFAULT_PORT, player_name: String = "Ka Kanor") -> int:
	disconnect_multiplayer()
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Ka Kanor"

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_network_connected = true
		connection_status_changed.emit("Hosting LAN Server on Port %d" % port, false)
	else:
		# Still allow local solo MP lobby vs AI bots even if port bind failed (e.g. offline/port busy)
		is_network_connected = false
		connection_status_changed.emit("Local Lobby (AI Skirmish Mode — port %d unavailable)" % port, false)

	is_active = true
	is_host = true
	local_peer_id = 1
	init_default_lobby(local_player_name)
	return err

func join_lobby(ip: String, port: int = DEFAULT_PORT, player_name: String = "Farmer Guest") -> int:
	disconnect_multiplayer()
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Farmer Guest"

	var target_ip: String = ip.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target_ip, port)
	if err != OK:
		connection_status_changed.emit("⚠️ Failed to connect to %s:%d" % [target_ip, port], true)
		return err

	multiplayer.multiplayer_peer = peer
	is_active = true
	is_host = false
	is_network_connected = false
	local_peer_id = 0
	connection_status_changed.emit("Connecting to %s:%d..." % [target_ip, port], false)
	return OK

func disconnect_multiplayer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_active = false
	is_host = false
	is_network_connected = false
	in_game_active = false
	spectating_slot_id = ""
	snapshots.clear()
	ai_sim_states.clear()
	final_standings.clear()
	_has_emitted_season_end = false
	var data_mgr = get_node_or_null("/root/Data")
	if data_mgr:
		data_mgr.is_multiplayer_match = false

func get_local_lan_ips() -> Array[String]:
	var ips: Array[String] = []
	for addr in IP.get_local_addresses():
		var s := str(addr)
		if "." in s and not s.begins_with("127.") and not s.begins_with("169.254."):
			ips.append(s)
	if ips.is_empty():
		ips.append("127.0.0.1")
	return ips

func _has_remote_peers() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.get_peers().size() > 0

func _on_peer_connected(_id: int) -> void:
	# Wait for client's rpc_client_register so we get their chosen Farmer Name
	pass

func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	var disconnected_name := "Player %d" % id
	for rid in region_slots.keys():
		var slot: Dictionary = region_slots[rid]
		if str(slot.get("type", "")) == "player" and int(slot.get("peer_id", 0)) == id:
			disconnected_name = str(slot.get("name", disconnected_name))
			if not in_game_active:
				slot["type"] = "open"
				slot["peer_id"] = 0
				slot["name"] = "Open"
				slot["status"] = "Open"
			else:
				slot["status"] = "Disconnected"
			break
	if not in_game_active:
		_broadcast_lobby_state()
		broadcast_chat("System", "%s left the lobby." % disconnected_name, Color(1.0, 0.65, 0.45))

func _on_connected_ok() -> void:
	is_network_connected = true
	local_peer_id = multiplayer.get_unique_id()
	connection_status_changed.emit("Connected to Host! (Peer #%d)" % local_peer_id, false)
	rpc_id(1, "rpc_client_register", local_player_name)

func _on_connected_fail() -> void:
	disconnect_multiplayer()
	connection_status_changed.emit("⚠️ Could not reach host at that LAN IP / Port.", true)
	connection_failed.emit()

func _on_server_disconnected() -> void:
	var was_in_game := in_game_active
	disconnect_multiplayer()
	connection_status_changed.emit("⚠️ Host closed the server.", true)
	server_disconnected.emit()
	if was_in_game and is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ---------------------------------------------------------------------------
# Color & Region Team Management (Server Authoritative)
# ---------------------------------------------------------------------------
func get_used_colors(exclude_slot_id: String = "") -> Array[int]:
	var used: Array[int] = []
	for rid in region_slots.keys():
		if rid == exclude_slot_id:
			continue
		var slot: Dictionary = region_slots[rid]
		if str(slot.get("type", "")) == "closed":
			continue
		used.append(posmod(int(slot.get("color_idx", 0)), FARMER_COLORS.size()))
	return used

func pick_unique_color_idx(exclude_slot_id: String = "") -> int:
	var used: Array[int] = get_used_colors(exclude_slot_id)
	for i in range(FARMER_COLORS.size()):
		if not (i in used):
			return i
	return 0

func get_slot_for_peer(peer_id: int) -> String:
	for reg in REGION_TEAMS:
		var rid := str(reg["id"])
		if region_slots.has(rid) and str(region_slots[rid].get("type", "")) == "player" and int(region_slots[rid].get("peer_id", 0)) == peer_id:
			return rid
	return ""

func set_local_player_name(new_name: String) -> void:
	var clean := new_name.strip_edges()
	if clean.is_empty():
		clean = "Farmer"
	local_player_name = clean
	if is_host:
		if region_slots.has(my_slot_id):
			region_slots[my_slot_id]["name"] = clean
		lobby_updated.emit()
		_broadcast_lobby_state()
	elif is_network_connected:
		rpc_id(1, "rpc_client_rename", clean)

func request_claim_region(target_region_id: String) -> void:
	if not region_slots.has(target_region_id):
		return
	if is_host:
		_server_move_peer_to_region(1, target_region_id)
	elif is_network_connected:
		rpc_id(1, "rpc_request_claim_region", target_region_id)

func request_cycle_slot_status(region_id: String) -> void:
	if not is_host or not region_slots.has(region_id):
		return
	var slot: Dictionary = region_slots[region_id]
	if str(slot.get("type", "")) == "player":
		return
	var cur: String = str(slot.get("status", "Open"))
	var idx: int = SLOT_STATUS_CYCLE.find(cur)
	var next_status: String = SLOT_STATUS_CYCLE[(idx + 1) % SLOT_STATUS_CYCLE.size()]
	slot["status"] = next_status
	slot["name"] = next_status
	if next_status == "Open":
		slot["type"] = "open"
		slot["peer_id"] = 0
	elif next_status == "Closed":
		slot["type"] = "closed"
		slot["peer_id"] = 0
	else:
		slot["type"] = "bot"
		slot["peer_id"] = -int(slot.get("team", 1))
	lobby_updated.emit()
	_broadcast_lobby_state()

func request_cycle_color(region_id: String) -> void:
	if not region_slots.has(region_id):
		return
	if is_host:
		_server_cycle_color(1, region_id)
	elif is_network_connected:
		rpc_id(1, "rpc_request_cycle_color", region_id)

func update_match_settings(new_settings: Dictionary) -> void:
	if not is_host:
		return
	for k in new_settings.keys():
		match_settings[k] = new_settings[k]
	match_settings["days"] = clampi(int(match_settings.get("days", 30)), 5, 365)
	lobby_updated.emit()
	_broadcast_lobby_state()

func broadcast_chat(sender_name: String, text: String, col: Color = Color(0.95, 0.92, 0.84)) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	if _has_remote_peers():
		rpc("rpc_send_chat", sender_name, clean, col)
	else:
		chat_received.emit(sender_name, clean, col)

func _server_move_peer_to_region(peer_id: int, target_rid: String) -> void:
	if not region_slots.has(target_rid):
		return
	var from_rid := get_slot_for_peer(peer_id)
	if from_rid.is_empty() or from_rid == target_rid:
		return

	var target_slot: Dictionary = region_slots[target_rid]
	if str(target_slot.get("type", "")) == "player":
		if peer_id == 1:
			broadcast_chat("System", "%s is already claimed by %s." % [str(target_slot["region_name"]), str(target_slot["name"])], Color(1.0, 0.72, 0.45))
		return

	var from_slot: Dictionary = region_slots[from_rid]
	var prev_target_type := str(target_slot.get("type", "open"))
	var prev_target_name := str(target_slot.get("name", "Open"))
	var prev_target_status := str(target_slot.get("status", "Open"))
	var prev_target_color := int(target_slot.get("color_idx", 0))

	var player_name_val := str(from_slot.get("name", "Player"))
	var player_color_val := int(from_slot.get("color_idx", 0))

	# Move human into target region slot
	target_slot["type"] = "player"
	target_slot["peer_id"] = peer_id
	target_slot["name"] = player_name_val
	target_slot["status"] = "Player"
	target_slot["color_idx"] = player_color_val

	# Restore previous slot as previous non-human type (if it was closed, make it Open so lobby keeps open slot)
	if prev_target_type == "closed":
		from_slot["type"] = "open"
		from_slot["name"] = "Open"
		from_slot["status"] = "Open"
		from_slot["peer_id"] = 0
	else:
		from_slot["type"] = prev_target_type
		from_slot["name"] = prev_target_name
		from_slot["status"] = prev_target_status
		from_slot["peer_id"] = -int(from_slot["team"]) if prev_target_type == "bot" else 0
	from_slot["color_idx"] = prev_target_color

	# Guarantee uniqueness across all slots
	if prev_target_color == player_color_val:
		from_slot["color_idx"] = pick_unique_color_idx(target_rid)

	if peer_id == local_peer_id:
		my_slot_id = target_rid

	broadcast_chat("System", "%s selected %s (Team %d)." % [player_name_val, str(target_slot["region_name"]), int(target_slot["team"])], FARMER_COLORS[posmod(player_color_val, FARMER_COLORS.size())])
	lobby_updated.emit()
	_broadcast_lobby_state()

func _server_cycle_color(requester_peer_id: int, slot_id: String) -> void:
	if not region_slots.has(slot_id):
		return
	var slot: Dictionary = region_slots[slot_id]
	var slot_owner := int(slot.get("peer_id", 0))
	if requester_peer_id != 1 and slot_owner != requester_peer_id:
		return

	var cur: int = posmod(int(slot.get("color_idx", 0)), FARMER_COLORS.size())
	var used: Array[int] = get_used_colors(slot_id)
	var chosen: int = cur
	for step in range(1, FARMER_COLORS.size() + 1):
		var cand: int = (cur + step) % FARMER_COLORS.size()
		if not (cand in used):
			chosen = cand
			break
	slot["color_idx"] = chosen
	lobby_updated.emit()
	_broadcast_lobby_state()

func _broadcast_lobby_state() -> void:
	if is_host and _has_remote_peers():
		rpc("rpc_sync_lobby", region_slots.duplicate(true), match_settings.duplicate(true))

# ---------------------------------------------------------------------------
# Match Launch
# ---------------------------------------------------------------------------
func start_match() -> void:
	if not is_host:
		return
	var final_slots: Dictionary = {}
	for reg in REGION_TEAMS:
		var rid := str(reg["id"])
		if not region_slots.has(rid):
			continue
		var s: Dictionary = region_slots[rid].duplicate(true)
		var stype := str(s.get("type", "open"))
		if stype == "open" or stype == "closed":
			continue
		final_slots[rid] = s

	var mkt_mgr = get_node_or_null("/root/MarketManager")
	var initial_markets: Dictionary = {}
	if mkt_mgr and mkt_mgr.has_method("reset_for_new_session"):
		mkt_mgr.reset_for_new_session()
		initial_markets = mkt_mgr.export_all_markets()

	if _has_remote_peers():
		rpc("rpc_launch_match", final_slots, match_settings.duplicate(true), initial_markets)
	else:
		_commit_launch_match(final_slots, match_settings.duplicate(true), initial_markets)

var _last_synced_market_day: int = 1

func _commit_launch_match(final_slots: Dictionary, final_settings: Dictionary, initial_markets: Dictionary = {}) -> void:
	in_game_active = true
	_has_emitted_season_end = false
	_last_synced_market_day = 1
	spectating_slot_id = ""
	snapshots.clear()
	ai_sim_states.clear()
	final_standings.clear()
	match_settings = final_settings.duplicate(true)

	# Locate our assigned region slot
	var my_slot: Dictionary = {}
	for rid in final_slots.keys():
		var s: Dictionary = final_slots[rid]
		if str(s.get("type", "")) == "player" and int(s.get("peer_id", 0)) == local_peer_id:
			my_slot = s
			my_slot_id = rid
			break

	if my_slot.is_empty():
		for rid in final_slots.keys():
			my_slot = final_slots[rid]
			my_slot_id = rid
			break

	var chosen_region: String = str(my_slot.get("region", "cotabato"))
	var chosen_team: int = int(my_slot.get("team", 1))
	var chosen_color: int = posmod(int(my_slot.get("color_idx", 0)), FARMER_COLORS.size())
	var days_val: int = clampi(int(match_settings.get("days", 30)), 5, 365)
	var cash_val: int = int(match_settings.get("cash", 2000))

	var data_mgr = get_node_or_null("/root/Data")
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	var tm_mgr = get_node_or_null("/root/TimeManager")
	var weather_mgr = get_node_or_null("/root/WeatherManager")
	var mkt_mgr = get_node_or_null("/root/MarketManager")

	if data_mgr:
		data_mgr.is_multiplayer_match = true
		data_mgr.is_tutorial_mode = false
		data_mgr.is_auto_mode = false
		data_mgr.game_mode = "campaign"
		data_mgr.multiplayer_team = chosen_team
		data_mgr.multiplayer_slot_id = my_slot_id
		data_mgr.multiplayer_player_color_idx = chosen_color
		data_mgr.multiplayer_roster = final_slots.values()
		data_mgr.multiplayer_game_type = "rivalry"
		data_mgr.multiplayer_leaderboard_enabled = bool(match_settings.get("leaderboard_enabled", true))
		data_mgr.current_region = chosen_region
		data_mgr.selected_season_days = days_val
		data_mgr.reset_all_session_state(1.0)
		data_mgr.custom_crop_growth_multiplier = float(match_settings.get("crop_growth", 2.0))
		data_mgr.custom_build_speed_multiplier = float(match_settings.get("build_speed", 2.0))
		data_mgr.custom_weather_intensity = str(match_settings.get("weather", "normal"))

	if mkt_mgr:
		if not initial_markets.is_empty() and mkt_mgr.has_method("import_all_markets"):
			mkt_mgr.import_all_markets(initial_markets)
		if mkt_mgr.has_method("set_active_region"):
			mkt_mgr.set_active_region(chosen_region)

	if eco_mgr:
		if eco_mgr.has_method("set_cash"):
			eco_mgr.set_cash(cash_val)
		else:
			eco_mgr.cash = cash_val

	if tm_mgr:
		tm_mgr.is_freeplay_mode = false
		tm_mgr.current_day = 1
		tm_mgr.current_hour = tm_mgr.STARTING_HOUR
		tm_mgr.reset_for_new_session(1.0)

	if weather_mgr and weather_mgr.has_method("init_fresh_queue"):
		weather_mgr.init_fresh_queue(1)

	# Initialize snapshots (and server AI simulation for bot rivals)
	for rid in final_slots.keys():
		var s: Dictionary = final_slots[rid]
		snapshots[rid] = _create_empty_snapshot(s, cash_val)
		if is_host and str(s.get("type", "")) == "bot":
			ai_sim_states[rid] = _init_ai_sim(s, cash_val)

	match_started.emit()

	var target_scene := "res://scenes/MainGame.tscn"
	if data_mgr and data_mgr.has_method("get_region_scene_path"):
		target_scene = data_mgr.get_region_scene_path(chosen_region)

	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(target_scene)

# ---------------------------------------------------------------------------
# In-Game Snapshot Collection, AI Rival Simulation & Clock Sync
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not in_game_active:
		return
	var data_mgr = get_node_or_null("/root/Data")
	if not data_mgr or not bool(data_mgr.get("is_multiplayer_match")):
		return
	if _get_farm_grid() == null:
		return

	_snapshot_timer += delta
	_clock_timer += delta
	_ai_sim_timer += delta

	if is_host and _ai_sim_timer >= 0.20:
		var ai_dt := _ai_sim_timer
		_ai_sim_timer = 0.0
		_tick_ai_rivals(ai_dt)

	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		var local_snap := _capture_local_snapshot()
		if not local_snap.is_empty():
			if is_host:
				snapshots[my_slot_id] = local_snap
				if _has_remote_peers():
					rpc("rpc_broadcast_snapshots", snapshots)
				snapshots_updated.emit()
			elif is_network_connected:
				rpc_id(1, "rpc_client_submit_snapshot", local_snap)

	if is_host and _has_remote_peers() and _clock_timer >= CLOCK_SYNC_INTERVAL:
		_clock_timer = 0.0
		var tm_mgr = get_node_or_null("/root/TimeManager")
		if tm_mgr:
			rpc("rpc_sync_match_clock", tm_mgr.current_day, tm_mgr.current_hour, tm_mgr._elapsed)
			if int(tm_mgr.current_day) != _last_synced_market_day:
				_last_synced_market_day = int(tm_mgr.current_day)
				var mkt_sync = get_node_or_null("/root/MarketManager")
				if mkt_sync and mkt_sync.has_method("export_all_markets"):
					rpc("rpc_sync_markets", mkt_sync.export_all_markets())

func _create_empty_snapshot(slot: Dictionary, cash_val: int) -> Dictionary:
	return {
		"slot_id": str(slot.get("slot_id", "")),
		"team": int(slot.get("team", 1)),
		"name": str(slot.get("name", "Player")),
		"region": str(slot.get("region", "cotabato")),
		"region_short": str(slot.get("region_short", "Cotabato")),
		"color_idx": posmod(int(slot.get("color_idx", 0)), FARMER_COLORS.size()),
		"type": str(slot.get("type", "player")),
		"score": 0,
		"cash": cash_val,
		"units_sold": 0,
		"farmers": [{"id": 1, "x": 768.0, "y": 320.0, "anim": "idle", "frame": 0, "flip": false, "name": "Worker 1"}],
		"drones": [],
		"buildings": [{"type": "bahay_kubo", "gx": 0, "gy": 0, "lvl": 1}, {"type": "bodega", "gx": 2, "gy": 0, "lvl": 1}],
		"unlocked_parcels": ["homestead"],
		"tiles": []
	}

func _capture_local_snapshot() -> Dictionary:
	var slot: Dictionary = region_slots.get(my_slot_id, {})
	var prev: Dictionary = snapshots.get(my_slot_id, {})
	var lbm = get_node_or_null("/root/LeaderboardManager")
	var eco = get_node_or_null("/root/EconomyManager")
	var data_mgr = get_node_or_null("/root/Data")

	var snap: Dictionary = {
		"slot_id": my_slot_id,
		"team": int(slot.get("team", prev.get("team", 1))),
		"name": str(slot.get("name", prev.get("name", local_player_name))),
		"region": str(slot.get("region", prev.get("region", data_mgr.current_region if data_mgr else "cotabato"))),
		"region_short": str(slot.get("region_short", prev.get("region_short", "Cotabato"))),
		"color_idx": int(data_mgr.multiplayer_player_color_idx) if data_mgr else 0,
		"type": str(slot.get("type", prev.get("type", "player"))),
		"score": int(lbm.current_points) if lbm else 0,
		"units_sold": int(lbm.run_units_sold) if lbm else 0,
		"cash": int(eco.cash) if eco else 0
	}

	# Collect farmers
	var farmers_arr: Array = []
	for f in get_tree().get_nodes_in_group("farmers"):
		if not is_instance_valid(f):
			continue
		farmers_arr.append({
			"id": int(f.get("worker_id")),
			"x": snappedf(f.global_position.x, 0.5),
			"y": snappedf(f.global_position.y, 0.5),
			"anim": str(f.get("_current_anim")),
			"frame": int(f.get("_anim_frame_idx")),
			"flip": bool(f.get("_is_facing_left")),
			"name": str(f.get("worker_name"))
		})
	snap["farmers"] = farmers_arr

	var fg = _get_farm_grid()
	# Collect active drones cleanly
	var drones_arr: Array = []
	if fg and "drones" in fg and fg.drones is Array:
		for d in fg.drones:
			if is_instance_valid(d) and d.visible:
				drones_arr.append({
					"id": int(d.drone_index) if "drone_index" in d else 1,
					"x": snappedf(d.global_position.x, 0.5),
					"y": snappedf(d.global_position.y, 0.5),
					"level": d.get_level() if d.has_method("get_level") else 1,
					"active": true
				})
	snap["drones"] = drones_arr

	# Collect buildings
	var bm = get_node_or_null("/root/BuildingManager")
	var bld_arr: Array = []
	if bm and "placed_buildings" in bm:
		for b in bm.placed_buildings:
			if is_instance_valid(b):
				var gp: Vector2i = b.get("grid_pos") if "grid_pos" in b else Vector2i(8, 8)
				bld_arr.append({
					"type": str(b.get("building_type")),
					"gx": gp.x,
					"gy": gp.y,
					"lvl": int(b.get("level")) if "level" in b else 1
				})
	snap["buildings"] = bld_arr

	# Collect non-empty active farm tiles & unlocked parcels (32x32 grid)
	var tile_arr: Array = []
	var parcels_arr: Array = ["homestead"]
	if fg:
		if "unlocked_parcels" in fg and fg.unlocked_parcels is Array:
			parcels_arr = fg.unlocked_parcels.duplicate()
		if "tiles" in fg and fg.tiles is Array and fg.tiles.size() >= 32:
			for x in range(32):
				var col = fg.tiles[x]
				if not (col is Array):
					continue
				for y in range(32):
					if y >= col.size():
						break
					var t = col[y]
					if t == null:
						continue
					# TileState: EMPTY=0, OBSTACLE=7, BUILDING=8, LOCKED=9
					var st := int(t.state)
					if st == 0 or st == 9:
						continue
					tile_arr.append([x, y, st, str(t.crop_type), snappedf(float(t.growth_progress), 0.05), str(t.obstacle_type)])
	snap["unlocked_parcels"] = parcels_arr
	snap["tiles"] = tile_arr
	return snap

# ---------------------------------------------------------------------------
# Competitive Server-Side AI Rival Simulation (AutoBooth-Level Strategy + PvP Rivalry)
# ---------------------------------------------------------------------------
const AI_HOMESTEAD_PLOTS: Array[Vector2i] = [] # Populated deterministically per sim
const AI_GROVE_SLOTS: Array[Dictionary] = [
	{"parcel": "homestead", "pos": Vector2i(12, 5)},
	{"parcel": "homestead", "pos": Vector2i(12, 8)},
	{"parcel": "east_meadows", "pos": Vector2i(24, 12)},
	{"parcel": "south_plains", "pos": Vector2i(4, 26)},
	{"parcel": "highland_plateau", "pos": Vector2i(26, 18)},
]

func _init_ai_sim(slot: Dictionary, cash_val: int) -> Dictionary:
	var diff_str := str(slot.get("status", "Computer (Normal)"))
	var difficulty: String = "normal"
	var rate: float = 0.88
	var start_workers: int = 2
	var max_workers: int = 4
	var target_drone_lvl: int = 2
	var max_drones: int = 2
	var max_plots: int = 36
	var decision_interval: float = 1.8
	var grade_a_base: float = 0.56
	var uses_processing: bool = true
	var builds_seaport: bool = true

	if "Hard" in diff_str:
		difficulty = "hard"
		rate = 1.06
		start_workers = 2
		max_workers = 5
		target_drone_lvl = 3
		max_drones = 3
		max_plots = 52
		decision_interval = 1.0
		grade_a_base = 0.72
		uses_processing = true
		builds_seaport = true
	elif "Easy" in diff_str:
		difficulty = "easy"
		rate = 0.65
		start_workers = 1
		max_workers = 2
		target_drone_lvl = 1
		max_drones = 1
		max_plots = 18
		decision_interval = 3.2
		grade_a_base = 0.42
		uses_processing = false
		builds_seaport = false

	var reg := str(slot.get("region", "south_cotabato"))
	var data_mgr = get_node_or_null("/root/Data")
	var mkt_mgr = get_node_or_null("/root/MarketManager")
	var r_mods: Dictionary = data_mgr.get_region_modifiers(reg) if data_mgr else {}
	var starter_pref := "palay"
	var spec_crops: Array = r_mods.get("specialty_crops", [])
	for sc in spec_crops:
		if str(sc) in ["palay", "yellow_corn"]:
			starter_pref = str(sc)
			break

	var plot_coords: Array[Vector2i] = []
	for py in range(3, 12):
		for px in range(3, 10):
			plot_coords.append(Vector2i(px, py))

	var ai_tiles: Array = []
	for idx in range(6):
		var pt := plot_coords[idx]
		var init_c := starter_pref if (idx % 3 != 2) else ("yellow_corn" if starter_pref == "palay" else "palay")
		ai_tiles.append({
			"gx": pt.x,
			"gy": pt.y,
			"crop": init_c,
			"prog": 0.14 + idx * 0.08,
			"state": 3,
			"moisture": 62.0,
			"health": 1.0,
			"pest": "",
			"is_2x2": false
		})

	var workers: Array = []
	for w in range(start_workers):
		var target_pt := plot_coords[w % plot_coords.size()]
		var px_pos := FarmerMovement.grid_to_pixel_center(target_pt, null)
		workers.append({
			"id": w + 1,
			"x": px_pos.x,
			"y": px_pos.y,
			"tx": px_pos.x,
			"ty": px_pos.y,
			"target_idx": (w + 1) % ai_tiles.size(),
			"anim": "till",
			"frame": 0,
			"flip": false,
			"timer": 0.6 + float(w) * 0.6,
			"name": "AI Worker %d" % (w + 1)
		})

	# Deduct fair starter seed cost for non-initial extras? Keep initial cash identical to player
	return {
		"slot": slot.duplicate(true),
		"difficulty": difficulty,
		"rate": rate,
		"max_workers": max_workers,
		"target_drone_lvl": target_drone_lvl,
		"max_drones": max_drones,
		"max_plots": max_plots,
		"decision_interval": decision_interval,
		"decision_timer": randf_range(0.5, decision_interval),
		"grade_a_base": grade_a_base,
		"uses_processing": uses_processing,
		"builds_seaport": builds_seaport,
		"crop": starter_pref,
		"unlocked_crops": ["palay", "yellow_corn"],
		"cash": cash_val,
		"score": 0,
		"combo": 0,
		"last_day_paid": 1,
		"last_process_hour": -1,
		"last_spoil_hour": -1,
		"units_sold": 0,
		"plot_coords": plot_coords,
		"tiles": ai_tiles,
		"workers": workers,
		"drones": [],
		"inventory": {}, # item_key -> Array[{qty:int, grade:String, freshness:float}]
		"anim_tick": 0.0,
		"buildings": [
			{"type": "bahay_kubo", "gx": 0, "gy": 0, "lvl": 1},
			{"type": "bodega", "gx": 2, "gy": 0, "lvl": 1}
		],
		"unlocked_parcels": ["homestead"],
		"storage_cap": 350,
		"has_cold_storage": false,
		"solar_dryer_lvl": 0,
		"water_tower_lvl": 0,
		"weather_station_lvl": 0,
		"drone_station_lvl": 0,
		"drone_slots": 0,
		"sprinkler_count": 0,
		"bayanihan_center": false,
		"tacurong_mill": false,
		"koronadal_wholesale": false,
		"gensan_seaport": false,
		"mills": []
	}

func _ai_add_inventory(st: Dictionary, item_key: String, qty: int, grade: String, freshness: float) -> void:
	if qty <= 0:
		return
	var cap: int = int(st.get("storage_cap", 350))
	var used: int = _ai_get_storage_used(st)
	var headroom: int = maxi(0, cap - used)
	var add_q: int = mini(qty, headroom)
	if add_q <= 0:
		return
	var inv: Dictionary = st["inventory"]
	if not inv.has(item_key):
		inv[item_key] = []
	(inv[item_key] as Array).append({
		"qty": add_q,
		"grade": grade,
		"freshness": freshness
	})

func _ai_get_storage_used(st: Dictionary) -> int:
	var inv: Dictionary = st.get("inventory", {})
	var tot: int = 0
	for k in inv.keys():
		for batch in inv[k]:
			tot += int(batch.get("qty", 0))
	return tot

func _ai_get_item_units(st: Dictionary, item_key: String) -> int:
	var inv: Dictionary = st.get("inventory", {})
	if not inv.has(item_key):
		return 0
	var tot: int = 0
	for b in inv[item_key]:
		tot += int(b.get("qty", 0))
	return tot

func _ai_consume_item_units(st: Dictionary, item_key: String, req_qty: int) -> bool:
	if _ai_get_item_units(st, item_key) < req_qty:
		return false
	var inv: Dictionary = st["inventory"]
	var arr: Array = inv[item_key]
	var rem: int = req_qty
	while rem > 0 and not arr.is_empty():
		var b: Dictionary = arr[0]
		var bq: int = int(b.get("qty", 0))
		if bq <= rem:
			rem -= bq
			arr.remove_at(0)
		else:
			b["qty"] = bq - rem
			rem = 0
	if arr.is_empty():
		inv.erase(item_key)
	return true

func _ai_recalc_building_bonuses(st: Dictionary) -> void:
	var cap: int = 0
	var cold: bool = false
	var dryer_lvl: int = 0
	var water_lvl: int = 0
	var weather_lvl: int = 0
	var drone_lvl: int = 0
	var drone_slots: int = 0
	var spr_cnt: int = 0
	var mills: Array = []

	for b in st.get("buildings", []):
		var bt := str(b.get("type", ""))
		var lvl := int(b.get("lvl", 1))
		match bt:
			"bodega":
				cap += 350 * lvl
			"cold_storage":
				cap += 2000 * lvl
				cold = true
			"climate_silo":
				cap += 5000 * lvl
				cold = true
			"solar_dryer":
				dryer_lvl = maxi(dryer_lvl, lvl)
			"water_tower":
				water_lvl = maxi(water_lvl, lvl)
			"weather_station":
				weather_lvl = maxi(weather_lvl, lvl)
			"drone_station":
				drone_lvl = maxi(drone_lvl, lvl)
				drone_slots += 1
			"drone_pad":
				drone_slots += 1
			"sprinkler":
				spr_cnt += 1
			"bayanihan_center":
				st["bayanihan_center"] = true
			"tacurong_mill":
				st["tacurong_mill"] = true
			"koronadal_wholesale":
				st["koronadal_wholesale"] = true
			"gensan_seaport":
				st["gensan_seaport"] = true
			"rice_mill", "sugar_mill", "copra_dryer", "coffee_roastery":
				if not mills.has(bt):
					mills.append(bt)

	st["storage_cap"] = maxi(350, cap)
	st["has_cold_storage"] = cold
	st["solar_dryer_lvl"] = dryer_lvl
	st["water_tower_lvl"] = water_lvl
	st["weather_station_lvl"] = weather_lvl
	st["drone_station_lvl"] = drone_lvl
	st["drone_slots"] = drone_slots
	st["sprinkler_count"] = spr_cnt
	st["mills"] = mills

	# Keep simulated drones synced to drone_slots (only while drone_station is built)
	var target_drones: int = drone_slots if drone_lvl > 0 else 0
	var drones: Array = st.get("drones", [])
	while drones.size() < target_drones:
		var did: int = drones.size() + 1
		var home_pt := Vector2i(6 + (did - 1) * 2, 0)
		var px := FarmerMovement.grid_to_pixel_center(home_pt, null)
		drones.append({
			"id": did,
			"x": px.x,
			"y": px.y,
			"tx": px.x,
			"ty": px.y,
			"target_idx": (did * 2) % maxi(1, (st.get("tiles", []) as Array).size()),
			"timer": 0.4 * float(did),
			"level": drone_lvl,
			"active": true
		})
	for d in drones:
		d["level"] = drone_lvl

func _ai_find_building(st: Dictionary, btype: String) -> Dictionary:
	for b in st.get("buildings", []):
		if str(b.get("type", "")) == btype:
			return b
	return {}

func _ai_count_building(st: Dictionary, btype: String) -> int:
	var c := 0
	for b in st.get("buildings", []):
		if str(b.get("type", "")) == btype:
			c += 1
	return c

func _ai_get_worker_speed_mult(st: Dictionary, r_mods: Dictionary) -> float:
	var mult := float(r_mods.get("worker_speed_mult", 1.0))
	if _ai_count_building(st, "drone_station") > 0:
		mult *= 1.15
	if bool(st.get("bayanihan_center", false)):
		mult *= 1.25
	return mult

func _ai_get_unlocked_hubs(st: Dictionary) -> Array[String]:
	var hubs: Array[String] = ["local_biyahero"]
	if bool(st.get("tacurong_mill", false)):
		hubs.append("tacurong")
	if bool(st.get("koronadal_wholesale", false)):
		hubs.append("koronadal")
	if bool(st.get("gensan_seaport", false)):
		hubs.append("gensan_port")
	return hubs

func _ai_score_crop(crop_key: String, st: Dictionary, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node) -> float:
	if data_mgr == null:
		return 10.0
	var c_data: Dictionary = data_mgr.get_crop(crop_key)
	if c_data.is_empty():
		return -1.0
	var r_mods: Dictionary = data_mgr.get_region_modifiers(reg)
	var fp: Vector2i = c_data.get("footprint", Vector2i(1, 1))
	var fp_area: float = float(maxi(1, fp.x * fp.y))
	var g_days: float = maxf(1.0, float(c_data.get("growth_days", 6)))
	if bool(c_data.get("is_perennial", false)) and float(c_data.get("regrowth_days", 0)) > 0.0:
		g_days = (g_days + float(c_data.get("regrowth_days", 3)) * 2.0) / 3.0
	var reg_g: float = float(r_mods.get("specialty_growth_mult", 1.0)) if data_mgr.is_regional_specialty_crop(crop_key, reg) else 1.0
	var reg_y: float = float(r_mods.get("specialty_yield_mult", 1.0)) if data_mgr.is_regional_specialty_crop(crop_key, reg) else 1.0
	var y_qty: float = float(c_data.get("yield_quantity", 50)) * reg_y

	# Evaluate realistic market price at best unlocked hub
	var best_p: float = float(c_data.get("base_price", 12)) * 0.8
	if mkt_mgr:
		var hubs := _ai_get_unlocked_hubs(st)
		var top_h := hubs[hubs.size() - 1]
		best_p = mkt_mgr.calculate_unit_price_for_region(crop_key, "Grade A", 92.0, top_h, reg, false)

	# Processing synergy multiplier if AI owns matching mill (or can build one)
	var proc_mult := 1.0
	var mills: Array = st.get("mills", [])
	if (crop_key == "palay" and "rice_mill" in mills) or (crop_key == "sugarcane" and "sugar_mill" in mills) or (crop_key == "coconut" and "copra_dryer" in mills) or (crop_key == "arabica_coffee" and "coffee_roastery" in mills):
		proc_mult = 1.45

	# Climate fit adjustment
	var climate_mult := 1.0
	if weather_mgr:
		var cl := int(weather_mgr.current_climate)
		if cl == 1: # EL_NINO
			if crop_key in ["yellow_corn", "pineapple", "coconut"]:
				climate_mult = 1.25
			elif crop_key == "palay" and int(st.get("water_tower_lvl", 0)) == 0:
				climate_mult = 0.72
		elif cl == 2: # LA_NINA
			if crop_key in ["palay", "sugarcane"]:
				climate_mult = 1.20
			elif crop_key in ["yellow_corn", "pineapple"] and int(st.get("water_tower_lvl", 0)) < 2:
				climate_mult = 0.82

	var seed_cost: float = float(mkt_mgr.get_seed_buy_price(crop_key, reg)) if mkt_mgr else float(c_data.get("seed_cost", 35))
	if bool(c_data.get("is_perennial", false)):
		seed_cost *= 0.35 # Amortized over multiple harvests

	var net_per_tile_day: float = ((y_qty * best_p * proc_mult * climate_mult - seed_cost) / fp_area) / maxf(1.0, g_days / reg_g)
	return net_per_tile_day

func _ai_pick_best_crop(st: Dictionary, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node, only_2x2: bool = false) -> String:
	var unlocked: Array = st.get("unlocked_crops", ["palay", "yellow_corn"])
	var candidates: Array[String] = []
	for k in unlocked:
		var ck := str(k)
		var fp: Vector2i = data_mgr.get_crop(ck).get("footprint", Vector2i(1, 1)) if data_mgr else Vector2i(1, 1)
		if only_2x2:
			if fp.x >= 2 and fp.y >= 2:
				candidates.append(ck)
		else:
			if fp.x == 1 and fp.y == 1:
				candidates.append(ck)
	if candidates.is_empty():
		return "" if only_2x2 else "palay"

	var best_c: String = candidates[0]
	var best_s: float = -1e9
	for c in candidates:
		var sc := _ai_score_crop(c, st, reg, mkt_mgr, data_mgr, weather_mgr)
		# Easy AI picks less aggressively; Hard AI picks optimal ROI reliably
		if str(st.get("difficulty", "normal")) == "easy":
			sc *= randf_range(0.65, 1.35)
		elif str(st.get("difficulty", "normal")) == "normal":
			sc *= randf_range(0.88, 1.12)
		if sc > best_s:
			best_s = sc
			best_c = c
	return best_c

func _ai_pick_best_license(st: Dictionary, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node) -> String:
	var unlocked: Array = st.get("unlocked_crops", ["palay", "yellow_corn"])
	var all_keys := ["sugarcane", "pineapple", "arabica_coffee", "banana", "coconut"]
	var best_c: String = ""
	var best_ratio: float = -1.0
	for k in all_keys:
		if k in unlocked:
			continue
		var l_cost: float = float(data_mgr.get_crop_license_cost(k)) if data_mgr else 250.0
		if l_cost <= 0.0:
			continue
		var roi: float = _ai_score_crop(k, st, reg, mkt_mgr, data_mgr, weather_mgr)
		var metric := roi / sqrt(l_cost)
		if metric > best_ratio:
			best_ratio = metric
			best_c = k
	return best_c

func _ai_try_unlock_parcel(st: Dictionary, reg: String, data_mgr: Node, cash_keep: int) -> bool:
	if data_mgr == null:
		return false
	var parcels_unlocked: Array = st.get("unlocked_parcels", ["homestead"])
	var parcel_order := ["east_meadows", "south_plains", "highland_plateau"]
	var p_list: Array = data_mgr.get_parcels(reg)
	for pid in parcel_order:
		if pid in parcels_unlocked:
			continue
		var base_cost: int = 1500
		for p in p_list:
			if str(p.get("id", "")) == pid:
				base_cost = int(p.get("cost", 1500))
				break
		var eff_cost: int = data_mgr.get_effective_land_cost(base_cost, reg)
		if int(st["cash"]) >= eff_cost + cash_keep:
			st["cash"] = int(st["cash"]) - eff_cost
			parcels_unlocked.append(pid)
			var coords: Array = st["plot_coords"]
			match pid:
				"east_meadows":
					for py in range(2, 11):
						for px in range(17, 23):
							coords.append(Vector2i(px, py))
				"south_plains":
					for py in range(17, 24):
						for px in range(3, 10):
							coords.append(Vector2i(px, py))
				"highland_plateau":
					for py in range(18, 25):
						for px in range(18, 25):
							coords.append(Vector2i(px, py))
			return true
	return false

func _ai_process_buildings_and_expansion(st: Dictionary, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node) -> void:
	if data_mgr == null:
		return
	var diff: String = str(st.get("difficulty", "normal"))
	var tiles: Array = st["tiles"]
	var reserve: int = clampi(tiles.size() * 14, 100, 480)
	var cash: int = int(st["cash"])
	var r_mods: Dictionary = data_mgr.get_region_modifiers(reg)

	# 1. Early Survival & Irrigation in Drought Regions or when fields grow
	if int(st.get("water_tower_lvl", 0)) == 0 and tiles.size() >= 8:
		var wt_cost: int = data_mgr.get_effective_building_cost("water_tower", reg)
		var drought_bias: float = float(r_mods.get("hazard_probs", {}).get("drought", 0.08))
		if (drought_bias >= 0.09 or diff != "easy") and cash >= wt_cost + reserve:
			st["cash"] = cash - wt_cost
			st["buildings"].append({"type": "water_tower", "gx": 12, "gy": 2, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# 2. Solar Dryer (+25% value) for fast early income snowball
	if int(st.get("solar_dryer_lvl", 0)) == 0 and int(st["units_sold"]) >= 150:
		var sd_cost: int = data_mgr.get_effective_building_cost("solar_dryer", reg)
		if cash >= sd_cost + reserve:
			st["cash"] = cash - sd_cost
			st["buildings"].append({"type": "solar_dryer", "gx": 0, "gy": 6, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# 3. Halfway Target: Drone Command Hangar (+1 starter Drone!) -> upgradeable to Lv.3
	if int(st.get("drone_station_lvl", 0)) == 0 and int(st["units_sold"]) >= 250:
		var ds_cost: int = data_mgr.get_effective_building_cost("drone_station", reg)
		if cash >= ds_cost + reserve:
			st["cash"] = cash - ds_cost
			st["buildings"].append({"type": "drone_station", "gx": 6, "gy": 0, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# 4. Expand Workforce (housing + hire) when active fields justify more hands
	var workers: Array = st["workers"]
	if workers.size() < int(st.get("max_workers", 3)) and tiles.size() >= workers.size() * 5:
		var hire_cost: int = data_mgr.get_effective_hire_cost(200, reg)
		var housing_cap: int = 0
		var upgradeable_kubo: Dictionary = {}
		for b in st.get("buildings", []):
			if str(b.get("type", "")) == "bahay_kubo":
				var bl := int(b.get("lvl", 1))
				housing_cap += bl
				if bl < 3 and upgradeable_kubo.is_empty():
					upgradeable_kubo = b
		if housing_cap <= workers.size():
			if not upgradeable_kubo.is_empty():
				var kl: int = int(upgradeable_kubo.get("lvl", 1))
				var up_k: int = int(data_mgr.get_effective_building_cost("bahay_kubo", reg) * (1.2 + kl * 0.4))
				if cash >= up_k + hire_cost + 80:
					st["cash"] = cash - up_k
					upgradeable_kubo["lvl"] = kl + 1
					housing_cap += 1
					cash = int(st["cash"])
					if housing_cap <= workers.size():
						return
			elif _ai_count_building(st, "bahay_kubo") < 2:
				var new_k_cost: int = data_mgr.get_effective_building_cost("bahay_kubo", reg)
				if cash >= new_k_cost + hire_cost + 80:
					st["cash"] = cash - new_k_cost
					st["buildings"].append({"type": "bahay_kubo", "gx": 4, "gy": 0, "lvl": 1})
					housing_cap += 1
					cash = int(st["cash"])
		if housing_cap > workers.size() and cash >= hire_cost + reserve:
			st["cash"] = cash - hire_cost
			var nid: int = workers.size() + 1
			var spawn_px := FarmerMovement.grid_to_pixel_center(Vector2i(2, 2), null)
			workers.append({
				"id": nid,
				"x": spawn_px.x,
				"y": spawn_px.y,
				"tx": spawn_px.x,
				"ty": spawn_px.y,
				"target_idx": nid % maxi(1, tiles.size()),
				"anim": "idle",
				"frame": 0,
				"flip": false,
				"timer": 0.4,
				"name": "AI Worker %d" % nid
			})
			return

	# 5. Unlock profitable crop licenses so AI adapts dynamically to high-margin crops
	var lic_target := _ai_pick_best_license(st, reg, mkt_mgr, data_mgr, weather_mgr)
	if not lic_target.is_empty() and (st.get("unlocked_crops", []) as Array).size() < (3 if diff == "easy" else (5 if diff == "normal" else 7)):
		var lic_cost: int = data_mgr.get_crop_license_cost(lic_target)
		if cash >= lic_cost + reserve:
			st["cash"] = cash - lic_cost
			(st["unlocked_crops"] as Array).append(lic_target)
			# Switch future plantings toward best crop
			st["crop"] = _ai_pick_best_crop(st, reg, mkt_mgr, data_mgr, weather_mgr, false)
			return

	# 6. Expand field plots (both 1x1 plots and 2x2 Banana/Coconut groves!)
	var plots: Array = st["plot_coords"]
	var next_c: String = _ai_pick_best_crop(st, reg, mkt_mgr, data_mgr, weather_mgr, false)
	st["crop"] = next_c
	var next_seed: int = mkt_mgr.get_seed_buy_price(next_c, reg) if mkt_mgr else 35
	if tiles.size() < int(st.get("max_plots", 40)):
		if tiles.size() < plots.size() and cash >= next_seed + reserve:
			var npt: Vector2i = plots[tiles.size()]
			tiles.append({
				"gx": npt.x,
				"gy": npt.y,
				"crop": next_c,
				"prog": 0.0,
				"state": 3,
				"moisture": 62.0,
				"health": 1.0,
				"pest": "",
				"is_2x2": false
			})
			st["cash"] = cash - next_seed
			if mkt_mgr:
				mkt_mgr.apply_market_trade(reg, next_c, 0.0, 2.0, false)
			return

	# Plant unlocked 2x2 Banana / Coconut perennials into dedicated grove slots!
	var grove_c: String = _ai_pick_best_crop(st, reg, mkt_mgr, data_mgr, weather_mgr, true)
	if not grove_c.is_empty():
		var unlocked_p: Array = st.get("unlocked_parcels", ["homestead"])
		var g_seed: int = mkt_mgr.get_seed_buy_price(grove_c, reg) if mkt_mgr else 240
		if cash >= g_seed + reserve:
			for slot_g in AI_GROVE_SLOTS:
				if str(slot_g["parcel"]) in unlocked_p:
					var gp: Vector2i = slot_g["pos"]
					var occupied := false
					for existing_t in tiles:
						if Vector2i(int(existing_t["gx"]), int(existing_t["gy"])) == gp:
							occupied = true
							break
					if not occupied:
						tiles.append({
							"gx": gp.x,
							"gy": gp.y,
							"crop": grove_c,
							"prog": 0.0,
							"state": 3,
							"moisture": 65.0,
							"health": 1.0,
							"pest": "",
							"is_2x2": true
						})
						st["cash"] = cash - g_seed
						return

	# 7. Trade Depots (Biyahero -> Tacurong -> Koronadal -> Gensan Seaport) & Cold Storage
	if not bool(st.get("bayanihan_center", false)):
		var bc_cost: int = data_mgr.get_effective_building_cost("bayanihan_center", reg)
		if cash >= bc_cost + reserve:
			st["cash"] = cash - bc_cost
			st["buildings"].append({"type": "bayanihan_center", "gx": 0, "gy": 3, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# Weather station Lv.1-2 for disaster readiness
	if int(st.get("weather_station_lvl", 0)) == 0 and int(st["units_sold"]) >= 350:
		var ws_cost: int = data_mgr.get_effective_building_cost("weather_station", reg)
		if cash >= ws_cost + reserve:
			st["cash"] = cash - ws_cost
			st["buildings"].append({"type": "weather_station", "gx": 0, "gy": 9, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# Upgrade Drone Hangar toward difficulty target + add Drone Landing Pads
	var ds_lvl: int = int(st.get("drone_station_lvl", 0))
	var target_dlvl: int = int(st.get("target_drone_lvl", 2))
	if ds_lvl > 0 and ds_lvl < target_dlvl:
		var up_d_cost: int = int(data_mgr.get_effective_building_cost("drone_station", reg) * (1.2 + ds_lvl * 0.4))
		if cash >= up_d_cost + reserve:
			var ds_b := _ai_find_building(st, "drone_station")
			st["cash"] = cash - up_d_cost
			ds_b["lvl"] = ds_lvl + 1
			_ai_recalc_building_bonuses(st)
			return

	if ds_lvl >= 1 and int(st.get("drone_slots", 0)) < int(st.get("max_drones", 2)):
		var pad_cost: int = data_mgr.get_effective_building_cost("drone_pad", reg)
		if cash >= pad_cost + reserve:
			var p_idx: int = _ai_count_building(st, "drone_pad")
			st["cash"] = cash - pad_cost
			st["buildings"].append({"type": "drone_pad", "gx": 8 + p_idx * 2, "gy": 0, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# Add Rotary Field Sprinklers around plots if Water Tower exists
	var wt_lvl := int(st.get("water_tower_lvl", 0))
	if wt_lvl > 0 and int(st.get("sprinkler_count", 0)) < (3 if wt_lvl == 1 else 6):
		var sp_cost: int = data_mgr.get_effective_building_cost("sprinkler", reg)
		if cash >= sp_cost + reserve:
			var sp_spots := [Vector2i(5, 2), Vector2i(8, 2), Vector2i(10, 5), Vector2i(10, 8), Vector2i(5, 12), Vector2i(8, 12)]
			var si := int(st.get("sprinkler_count", 0))
			if si < sp_spots.size():
				var spp: Vector2i = sp_spots[si]
				st["cash"] = cash - sp_cost
				st["buildings"].append({"type": "sprinkler", "gx": spp.x, "gy": spp.y, "lvl": 1})
				_ai_recalc_building_bonuses(st)
				return

	# Upgrade Bodega or build Cold Storage when capacity gets tight or before long-haul Seaport runs
	if not bool(st.get("has_cold_storage", false)):
		var cs_cost: int = data_mgr.get_effective_building_cost("cold_storage", reg)
		if int(st["units_sold"]) >= 550 and cash >= cs_cost + reserve:
			st["cash"] = cash - cs_cost
			st["buildings"].append({"type": "cold_storage", "gx": 0, "gy": 12, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return
		var bd_b := _ai_find_building(st, "bodega")
		var bd_lvl := int(bd_b.get("lvl", 1))
		if bd_lvl < 3 and int(st.get("storage_cap", 350)) <= 700:
			var up_bd := int(data_mgr.get_effective_building_cost("bodega", reg) * (1.2 + bd_lvl * 0.4))
			if cash >= up_bd + reserve:
				st["cash"] = cash - up_bd
				bd_b["lvl"] = bd_lvl + 1
				_ai_recalc_building_bonuses(st)
				return

	# Land Expansion when homestead plots are mostly utilized or storage needs parcels for mills
	var parcels_n: int = (st.get("unlocked_parcels", ["homestead"]) as Array).size()
	var expand_trigger: int = (24 if diff == "hard" else 30) if parcels_n == 1 else (plots.size() - 8)
	if tiles.size() >= expand_trigger and diff != "easy":
		if _ai_try_unlock_parcel(st, reg, data_mgr, reserve):
			return

	# Regional Trade Hubs (unlock Tacurong -> Koronadal -> GenSan Seaport)
	if not bool(st.get("tacurong_mill", false)):
		var tc_cost: int = data_mgr.get_effective_building_cost("tacurong_mill", reg)
		if cash >= tc_cost + reserve:
			st["cash"] = cash - tc_cost
			st["buildings"].append({"type": "tacurong_mill", "gx": 24, "gy": 2, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# Agro-Industrial Processing Mill matched to rival's best crop/region
	if bool(st.get("uses_processing", true)) and (st.get("unlocked_parcels", []) as Array).size() >= 2 and (st.get("mills", []) as Array).is_empty():
		var pref_mill: String = "rice_mill"
		match reg:
			"sultan_kudarat": pref_mill = "sugar_mill"
			"south_cotabato": pref_mill = "coffee_roastery"
			"sarangani", "general_santos": pref_mill = "copra_dryer"
			_: pref_mill = "rice_mill"
		var pm_cost: int = data_mgr.get_effective_building_cost(pref_mill, reg)
		if cash >= pm_cost + reserve:
			st["cash"] = cash - pm_cost
			st["buildings"].append({"type": pref_mill, "gx": 17, "gy": 12, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	if not bool(st.get("koronadal_wholesale", false)):
		var kc_cost: int = data_mgr.get_effective_building_cost("koronadal_wholesale", reg)
		if cash >= kc_cost + reserve:
			st["cash"] = cash - kc_cost
			st["buildings"].append({"type": "koronadal_wholesale", "gx": 24, "gy": 7, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	if bool(st.get("builds_seaport", true)) and not bool(st.get("gensan_seaport", false)):
		var gp_cost: int = data_mgr.get_effective_building_cost("gensan_seaport", reg)
		if cash >= gp_cost + reserve:
			st["cash"] = cash - gp_cost
			st["buildings"].append({"type": "gensan_seaport", "gx": 28, "gy": 2, "lvl": 1})
			_ai_recalc_building_bonuses(st)
			return

	# Upgrade Solar Dryer & Water Tower later
	var sd_lvl := int(st.get("solar_dryer_lvl", 0))
	if sd_lvl > 0 and sd_lvl < 3:
		var up_sd := int(data_mgr.get_effective_building_cost("solar_dryer", reg) * (1.2 + sd_lvl * 0.4))
		if cash >= up_sd + reserve:
			var sb := _ai_find_building(st, "solar_dryer")
			st["cash"] = cash - up_sd
			sb["lvl"] = sd_lvl + 1
			_ai_recalc_building_bonuses(st)

func _ai_run_industrial_processing(st: Dictionary, data_mgr: Node) -> void:
	if data_mgr == null:
		return
	for mill_id in st.get("mills", []):
		var b_data: Dictionary = data_mgr.get_building(str(mill_id))
		var recipe: Dictionary = b_data.get("recipe", {})
		if recipe.is_empty():
			continue
		var in_crop := str(recipe.get("input_crop", ""))
		var in_qty := int(recipe.get("input_qty", 0))
		var outputs: Array = recipe.get("outputs", [])
		if in_crop.is_empty() or in_qty <= 0 or outputs.is_empty():
			continue
		if _ai_get_item_units(st, in_crop) >= in_qty:
			if _ai_consume_item_units(st, in_crop, in_qty):
				for out_it in outputs:
					_ai_add_inventory(st, str(out_it.get("item", "")), int(out_it.get("qty", 0)), "Grade A", 100.0)

func _ai_evaluate_and_sell(st: Dictionary, reg: String, mkt_mgr: Node, lbm: Node, data_mgr: Node) -> bool:
	var inv: Dictionary = st.get("inventory", {})
	if inv.is_empty() or data_mgr == null:
		return false

	var r_mods: Dictionary = data_mgr.get_region_modifiers(reg)
	var hubs: Array[String] = _ai_get_unlocked_hubs(st)
	var cap: int = maxi(1, int(st.get("storage_cap", 350)))
	var used: int = _ai_get_storage_used(st)
	var fill_ratio: float = float(used) / float(cap)
	var mills: Array = st.get("mills", [])
	var dryer_bonus: float = float(st.get("solar_dryer_lvl", 0)) * 0.08
	var has_cold: bool = bool(st.get("has_cold_storage", false))
	var has_biya: bool = bool(st.get("bayanihan_center", false))
	var market_dirty := false

	for item_key in inv.keys().duplicate():
		var arr: Array = inv[item_key]
		if arr.is_empty():
			continue
		var total_q := _ai_get_item_units(st, str(item_key))
		if total_q <= 0:
			continue

		# Hold a modest raw batch for processing mill if storage has plenty of space
		if fill_ratio < 0.55 and total_q <= 120:
			if (item_key == "palay" and "rice_mill" in mills) or (item_key == "sugarcane" and "sugar_mill" in mills) or (item_key == "coconut" and "copra_dryer" in mills) or (item_key == "arabica_coffee" and "coffee_roastery" in mills):
				continue

		var is_processed: bool = data_mgr.is_processed_good(str(item_key))
		var best_hub := "local_biyahero"
		var best_net := -999999
		var best_arrival_f := 100.0
		var best_grade := str(arr[0].get("grade", "Grade A"))
		var avg_fresh: float = 0.0
		for b in arr:
			avg_fresh += float(b.get("freshness", 100.0)) * float(b.get("qty", 0))
		avg_fresh /= float(maxi(1, total_q))

		for h_id in hubs:
			var hub_d: Dictionary = data_mgr.get_market_hub(h_id)
			var base_rot: float = 0.0 if is_processed else float(hub_d.get("rot_risk_percent", 0.0))
			var eff_rot: float = base_rot * float(r_mods.get("road_rot_mult", 1.0))
			if has_cold and eff_rot > 0.0:
				eff_rot *= 0.25 # Cold Storage slashes road rot risk
			var arrival_f: float = clampf(avg_fresh - eff_rot, 0.0, 100.0)
			if arrival_f <= 0.0:
				continue
			var hub_fuel: float = float(hub_d.get("fuel_cost", 0)) * float(r_mods.get("hub_fuel_overrides", {}).get(h_id, r_mods.get("fuel_cost_mult", 1.0)))
			var depot_bonus := 1.0
			if h_id == "local_biyahero" and has_biya:
				depot_bonus += 0.08
			elif h_id == "tacurong" and bool(st.get("tacurong_mill", false)):
				depot_bonus += 0.06
				hub_fuel *= 0.80
			elif h_id == "koronadal" and bool(st.get("koronadal_wholesale", false)):
				depot_bonus += 0.08
				hub_fuel *= 0.75
			elif h_id == "gensan_port" and bool(st.get("gensan_seaport", false)):
				depot_bonus += 0.12
				hub_fuel *= 0.70
			if int(st["cash"]) < int(round(hub_fuel)):
				continue

			var unit_p: float = mkt_mgr.calculate_unit_price_for_region(str(item_key), best_grade, arrival_f, h_id, reg, false) if mkt_mgr else 10.0
			unit_p *= (depot_bonus + dryer_bonus)
			var net: int = int(round(unit_p * float(total_q))) - int(round(hub_fuel))
			if net > best_net:
				best_net = net
				best_hub = h_id
				best_arrival_f = arrival_f

		if best_net <= 0:
			# Purge spoiled batch or quick dump at instant Biyahero
			var fb_p: float = mkt_mgr.calculate_unit_price_for_region(str(item_key), best_grade, maxf(10.0, avg_fresh), "local_biyahero", reg, false) if mkt_mgr else 6.0
			best_net = maxi(0, int(round(fb_p * float(total_q))))
			best_hub = "local_biyahero"
			best_arrival_f = maxf(10.0, avg_fresh)

		inv.erase(item_key)
		st["cash"] = int(st["cash"]) + maxi(0, best_net)
		st["units_sold"] = int(st["units_sold"]) + total_q

		var pts: int = 100
		if lbm and lbm.has_method("calculate_sale_points"):
			var pts_res: Dictionary = lbm.calculate_sale_points(str(item_key), total_q, best_grade, best_arrival_f, best_hub, reg, int(st.get("combo", 0)))
			pts = int(pts_res.get("total_points", 100))
			if best_grade == "Grade A" or (best_grade == "Grade B" and best_arrival_f >= 70.0):
				st["combo"] = int(st.get("combo", 0)) + 1
			else:
				st["combo"] = 0
		st["score"] = int(st["score"]) + pts

		if mkt_mgr:
			var dest_r: String = str(mkt_mgr.HUB_TO_REGION.get(best_hub, reg))
			mkt_mgr.apply_market_trade(dest_r, str(item_key), float(total_q) * 0.8, 0.0, false)
			market_dirty = true
	return market_dirty

func _ai_complete_plot_harvest(st: Dictionary, tgt_tile: Dictionary, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node, by_drone: bool) -> bool:
	if data_mgr == null:
		return false
	var t_crop: String = str(tgt_tile.get("crop", st["crop"]))
	var c_info: Dictionary = data_mgr.get_crop(t_crop)
	var r_mods: Dictionary = data_mgr.get_region_modifiers(reg)
	var is_perennial: bool = bool(c_info.get("is_perennial", false))
	var regrow_d: float = float(c_info.get("regrowth_days", 0))
	var tot_d: float = float(c_info.get("growth_days", 12))

	var base_yield: int = int(c_info.get("yield_quantity", 50))
	var spec_y: float = float(r_mods.get("specialty_yield_mult", 1.0)) if data_mgr.is_regional_specialty_crop(t_crop, reg) else 1.0
	var health_f: float = clampf(float(tgt_tile.get("health", 1.0)), 0.35, 1.0)
	var qty: int = maxi(1, int(round(float(base_yield) * spec_y * health_f)))

	var roll: float = randf()
	var grade_a_chance: float = float(st.get("grade_a_base", 0.55)) + float(st.get("solar_dryer_lvl", 0)) * 0.07 + (0.08 if by_drone else 0.0)
	var ai_grade: String = "Grade A" if roll < minf(0.92, grade_a_chance) else ("Grade B" if roll < 0.94 else "Grade C")

	var market_dirty := false
	if _ai_get_storage_used(st) + qty > int(st.get("storage_cap", 350)):
		var lbm_ref = get_node_or_null("/root/LeaderboardManager")
		if _ai_evaluate_and_sell(st, reg, mkt_mgr, lbm_ref, data_mgr):
			market_dirty = true

	_ai_add_inventory(st, t_crop, qty, ai_grade, 100.0)

	if is_perennial and regrow_d > 0.0:
		tgt_tile["prog"] = clampf(1.0 - (regrow_d / maxf(tot_d, 1.0)), 0.3, 0.85)
		tgt_tile["state"] = 3
		return market_dirty

	# Re-evaluate best crop when replanting an annual plot!
	var new_crop: String = _ai_pick_best_crop(st, reg, mkt_mgr, data_mgr, weather_mgr, bool(tgt_tile.get("is_2x2", false)))
	if new_crop.is_empty():
		new_crop = t_crop
	var seed_cost: int = mkt_mgr.get_seed_buy_price(new_crop, reg) if mkt_mgr else int(data_mgr.get_crop(new_crop).get("seed_cost", 35))
	if int(st["cash"]) >= seed_cost:
		st["cash"] = int(st["cash"]) - seed_cost
		tgt_tile["crop"] = new_crop
		tgt_tile["prog"] = 0.05
		tgt_tile["state"] = 3
		tgt_tile["health"] = 1.0
		if mkt_mgr:
			mkt_mgr.apply_market_trade(reg, new_crop, 0.0, 2.0, false)
			market_dirty = true
	else:
		tgt_tile["prog"] = 0.02
		tgt_tile["state"] = 3
	return market_dirty

func _ai_tick_drones(st: Dictionary, eff_dt: float, rate: float, reg: String, mkt_mgr: Node, data_mgr: Node, weather_mgr: Node) -> bool:
	var drones: Array = st.get("drones", [])
	var tiles: Array = st.get("tiles", [])
	if drones.is_empty() or tiles.is_empty():
		return false
	var market_dirty := false
	for d in drones:
		var dx: float = float(d["tx"]) - float(d["x"])
		var dy: float = float(d["ty"]) - float(d["y"])
		var dist := sqrt(dx * dx + dy * dy)
		if dist > 6.0:
			var step := minf(dist, 220.0 * rate * eff_dt)
			d["x"] = float(d["x"]) + (dx / dist) * step
			d["y"] = float(d["y"]) + (dy / dist) * step
		else:
			d["timer"] = float(d["timer"]) - eff_dt
			if float(d["timer"]) <= 0.0:
				var tidx := int(d.get("target_idx", 0)) % tiles.size()
				var tgt: Dictionary = tiles[tidx]
				var dlvl := int(d.get("level", 1))
				# Lv.1 hydrates & tills (+small growth boost), Lv.2 cures pests, Lv.3 harvests mature plots
				tgt["moisture"] = clampf(maxf(float(tgt.get("moisture", 60.0)), 66.0), 40.0, 82.0)
				if dlvl >= 2 and str(tgt.get("pest", "")) != "":
					tgt["pest"] = ""
					tgt["state"] = 4 if float(tgt["prog"]) >= 1.0 else 3
				if dlvl >= 3 and float(tgt["prog"]) >= 1.0:
					if _ai_complete_plot_harvest(st, tgt, reg, mkt_mgr, data_mgr, weather_mgr, true):
						market_dirty = true
				# Pick next high-priority tile for Drone (harvestable first if Lv.3, else thirsty/pested/growing)
				var best_idx: int = (tidx + 1) % tiles.size()
				for i in range(tiles.size()):
					var cand: Dictionary = tiles[(tidx + 1 + i) % tiles.size()]
					if dlvl >= 3 and float(cand["prog"]) >= 1.0:
						best_idx = (tidx + 1 + i) % tiles.size()
						break
					if dlvl >= 2 and str(cand.get("pest", "")) != "":
						best_idx = (tidx + 1 + i) % tiles.size()
						break
				d["target_idx"] = best_idx
				var nt: Dictionary = tiles[best_idx]
				var dest := FarmerMovement.grid_to_pixel_center(Vector2i(int(nt["gx"]), int(nt["gy"])), null)
				d["tx"] = dest.x
				d["ty"] = dest.y
				d["timer"] = 0.65
	return market_dirty

func _tick_ai_rivals(dt: float) -> void:
	var tm_mgr = get_node_or_null("/root/TimeManager")
	var mkt_mgr = get_node_or_null("/root/MarketManager")
	var lbm = get_node_or_null("/root/LeaderboardManager")
	var data_mgr = get_node_or_null("/root/Data")
	var weather_mgr = get_node_or_null("/root/WeatherManager")
	var clock_mult: float = tm_mgr.get_speed_scale() if tm_mgr else 1.0
	if clock_mult <= 0.0:
		return
	var eff_dt := dt * clock_mult
	var cur_day: int = int(tm_mgr.current_day) if tm_mgr else 1
	var cur_hour: int = int(tm_mgr.current_hour) if tm_mgr else 7
	var day_seconds: float = float(tm_mgr.DAY_SECONDS) if tm_mgr else 96.0
	var active_dis: String = str(weather_mgr.active_disaster) if weather_mgr else ""
	var ai_market_dirty: bool = false

	for rid in ai_sim_states.keys():
		var st: Dictionary = ai_sim_states[rid]
		var rate: float = float(st["rate"])
		var reg: String = str(st.get("slot", {}).get("region", "cotabato"))
		var r_mods: Dictionary = data_mgr.get_region_modifiers(reg) if data_mgr else {}
		var worker_spd: float = _ai_get_worker_speed_mult(st, r_mods)
		var growth_mult: float = float(match_settings.get("crop_growth", 2.0))
		st["anim_tick"] = float(st["anim_tick"]) + eff_dt

		var workers: Array = st["workers"]
		if cur_day > int(st.get("last_day_paid", 1)):
			st["last_day_paid"] = cur_day
			var wage: int = data_mgr.get_effective_worker_wage(15, reg) if data_mgr else 15
			st["cash"] = maxi(0, int(st["cash"]) - wage * workers.size())

		# Process Industrial Mills every 4 hours & warehouse hourly spoilage (unless Cold Storage active)
		if cur_hour != int(st.get("last_spoil_hour", -1)):
			st["last_spoil_hour"] = cur_hour
			if not bool(st.get("has_cold_storage", false)):
				var inv: Dictionary = st["inventory"]
				for k in inv.keys():
					if data_mgr and data_mgr.is_processed_good(str(k)):
						continue
					for b in inv[k]:
						b["freshness"] = maxf(25.0, float(b.get("freshness", 100.0)) - 3.5)
			if cur_hour % 4 == 0 and cur_hour != int(st.get("last_process_hour", -1)):
				st["last_process_hour"] = cur_hour
				_ai_run_industrial_processing(st, data_mgr)

		# Advance AI crops with real growth_days + irrigation/weather impact + disaster resilience
		var wt_lvl := int(st.get("water_tower_lvl", 0))
		var spr_cnt := int(st.get("sprinkler_count", 0))
		var ws_lvl := int(st.get("weather_station_lvl", 0))
		var evap_rate := float(r_mods.get("evap_mult", 1.0)) * (0.65 if wt_lvl >= 2 else 1.0) * (0.75 if spr_cnt > 0 else 1.0)
		var dis_dmg := 0.0
		if active_dis != "":
			var dis_res := 1.0 - minf(0.65, float(wt_lvl) * 0.10 + float(ws_lvl) * 0.12)
			dis_dmg = eff_dt * 0.025 * dis_res

		var tiles: Array = st["tiles"]
		for t in tiles:
			var t_crop: String = str(t.get("crop", st["crop"]))
			var c_data: Dictionary = data_mgr.get_crop(t_crop) if data_mgr else {}
			var g_days: float = float(c_data.get("growth_days", 6))
			var reg_g: float = float(r_mods.get("specialty_growth_mult", 1.0)) if (data_mgr and data_mgr.is_regional_specialty_crop(t_crop, reg)) else 1.0
			var irr_bonus: float = 1.0 + (0.03 * minf(float(wt_lvl), 3.0)) + (0.03 if spr_cnt > 0 else 0.0)
			if wt_lvl > 0:
				t["moisture"] = maxf(float(t.get("moisture", 60.0)), 52.0 + float(wt_lvl) * 5.0)
			else:
				t["moisture"] = clampf(float(t.get("moisture", 60.0)) - eff_dt * 0.35 * evap_rate, 25.0, 90.0)
			if dis_dmg > 0.0:
				t["health"] = maxf(0.40, float(t.get("health", 1.0)) - dis_dmg)
			var prog_step: float = (eff_dt / maxf(g_days * day_seconds, 1.0)) * rate * growth_mult * reg_g * irr_bonus
			t["prog"] = minf(1.0, float(t["prog"]) + prog_step)
			t["state"] = 6 if (active_dis == "flash_flood" and ws_lvl == 0 and randf() < 0.004) else (4 if float(t["prog"]) >= 1.0 else 3)

		# Animate & process AI Drones
		if _ai_tick_drones(st, eff_dt, rate, reg, mkt_mgr, data_mgr, weather_mgr):
			ai_market_dirty = true

		# Strategic AI Tycoon Decision Tick (Expansion, Upgrades, Licenses & Market Sales)
		st["decision_timer"] = float(st.get("decision_timer", 1.5)) - eff_dt
		if float(st["decision_timer"]) <= 0.0:
			st["decision_timer"] = float(st.get("decision_interval", 1.8))
			_ai_process_buildings_and_expansion(st, reg, mkt_mgr, data_mgr, weather_mgr)
			if _ai_evaluate_and_sell(st, reg, mkt_mgr, lbm, data_mgr):
				ai_market_dirty = true

		# Animate AI farmers moving between plots, irrigating, harvesting & selling
		for w in workers:
			var dx: float = float(w["tx"]) - float(w["x"])
			var dy: float = float(w["ty"]) - float(w["y"])
			var dist := sqrt(dx * dx + dy * dy)
			if dist > 4.0:
				var move_step := minf(dist, 98.0 * rate * worker_spd * eff_dt)
				w["x"] = float(w["x"]) + (dx / dist) * move_step
				w["y"] = float(w["y"]) + (dy / dist) * move_step
				w["flip"] = dx < 0.0
				w["anim"] = "walk"
				w["frame"] = int(float(st["anim_tick"]) * 6.0) % 4
			else:
				w["timer"] = float(w["timer"]) - eff_dt
				var tgt_tile: Dictionary = tiles[int(w["target_idx"]) % tiles.size()]
				if float(tgt_tile["prog"]) >= 1.0:
					w["anim"] = "harvest"
				else:
					w["anim"] = "till"
				w["frame"] = int(float(st["anim_tick"]) * 5.0) % 4

				if float(w["timer"]) <= 0.0:
					tgt_tile["moisture"] = clampf(float(tgt_tile.get("moisture", 55.0)) + 16.0, 40.0, 85.0)
					if float(tgt_tile["prog"]) >= 1.0 or int(tgt_tile.get("state", 3)) == 6:
						if _ai_complete_plot_harvest(st, tgt_tile, reg, mkt_mgr, data_mgr, weather_mgr, false):
							ai_market_dirty = true
						# Fast-sell immediately if storage is near cap so workers never stall
						if _ai_get_storage_used(st) >= int(float(st.get("storage_cap", 350)) * 0.85):
							if _ai_evaluate_and_sell(st, reg, mkt_mgr, lbm, data_mgr):
								ai_market_dirty = true

					# Smart target selection: prefer nearest/mature tiles instead of dumb sequential walk!
					var next_tidx := (int(w["target_idx"]) + 1) % tiles.size()
					var cur_tidx := int(w["target_idx"]) % tiles.size()
					for step_i in range(1, tiles.size()):
						var ci := (cur_tidx + step_i) % tiles.size()
						if float(tiles[ci]["prog"]) >= 1.0 or int(tiles[ci].get("state", 3)) == 6:
							next_tidx = ci
							break
					w["target_idx"] = next_tidx
					var n_tile: Dictionary = tiles[next_tidx]
					var dest := FarmerMovement.grid_to_pixel_center(Vector2i(int(n_tile["gx"]), int(n_tile["gy"])), null)
					w["tx"] = dest.x
					w["ty"] = dest.y
					w["timer"] = randf_range(0.8, 1.5) / maxf(0.8, rate)

		# Write clean AI snapshot for Live Standings & Spectate View
		var slot: Dictionary = st["slot"]
		var snap_workers: Array = []
		for w in workers:
			snap_workers.append({
				"id": int(w["id"]),
				"x": snappedf(float(w["x"]), 0.5),
				"y": snappedf(float(w["y"]), 0.5),
				"anim": str(w["anim"]),
				"frame": int(w["frame"]),
				"flip": bool(w["flip"]),
				"name": str(w["name"])
			})
		var snap_drones: Array = []
		for d in st.get("drones", []):
			snap_drones.append({
				"id": int(d["id"]),
				"x": snappedf(float(d["x"]), 0.5),
				"y": snappedf(float(d["y"]), 0.5),
				"level": int(d["level"]),
				"active": true
			})
		var snap_tiles: Array = []
		for t in tiles:
			snap_tiles.append([int(t["gx"]), int(t["gy"]), int(t["state"]), str(t["crop"]), snappedf(float(t["prog"]), 0.05), ""])

		snapshots[rid] = {
			"slot_id": rid,
			"team": int(slot["team"]),
			"name": str(slot["name"]),
			"region": str(slot["region"]),
			"region_short": str(slot["region_short"]),
			"color_idx": int(slot["color_idx"]),
			"type": "bot",
			"score": int(st["score"]),
			"cash": int(st["cash"]),
			"units_sold": int(st["units_sold"]),
			"farmers": snap_workers,
			"drones": snap_drones,
			"buildings": st["buildings"],
			"unlocked_parcels": st.get("unlocked_parcels", ["homestead"]),
			"tiles": snap_tiles
		}

	if ai_market_dirty and mkt_mgr and _has_remote_peers():
		rpc("rpc_sync_markets", mkt_mgr.export_all_markets())

# ---------------------------------------------------------------------------
# Spectate Helpers & End-of-Season Standings
# ---------------------------------------------------------------------------
func is_spectating() -> bool:
	return in_game_active and not spectating_slot_id.is_empty() and spectating_slot_id != my_slot_id

func request_spectate(slot_id: String) -> void:
	if not in_game_active:
		return
	if slot_id.is_empty() or slot_id == my_slot_id or slot_id == spectating_slot_id:
		spectating_slot_id = ""
	else:
		if snapshots.has(slot_id):
			spectating_slot_id = slot_id
	spectate_changed.emit(spectating_slot_id)

func stop_spectating() -> void:
	if not spectating_slot_id.is_empty():
		spectating_slot_id = ""
		spectate_changed.emit("")

func get_sorted_standings() -> Array:
	var list: Array = []
	# Ensure local snapshot score is up-to-date
	if snapshots.has(my_slot_id):
		var lbm = get_node_or_null("/root/LeaderboardManager")
		var eco = get_node_or_null("/root/EconomyManager")
		if lbm:
			snapshots[my_slot_id]["score"] = int(lbm.current_points)
			snapshots[my_slot_id]["units_sold"] = int(lbm.run_units_sold)
		if eco:
			snapshots[my_slot_id]["cash"] = int(eco.cash)

	for rid in snapshots.keys():
		var s: Dictionary = snapshots[rid]
		# Construct lightweight summary dict (avoids deep-copying 1,024-tile arrays every tick!)
		list.append({
			"slot_id": str(s.get("slot_id", rid)),
			"team": int(s.get("team", 1)),
			"name": str(s.get("name", "Player")),
			"region": str(s.get("region", "cotabato")),
			"region_short": str(s.get("region_short", "")),
			"color_idx": int(s.get("color_idx", 0)),
			"type": str(s.get("type", "player")),
			"score": int(s.get("score", 0)),
			"cash": int(s.get("cash", 0)),
			"units_sold": int(s.get("units_sold", 0)),
			"farmer_count": (s.get("farmers", []) as Array).size(),
			"drone_count": (s.get("drones", []) as Array).size()
		})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("score", 0))
		var sb := int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return int(a.get("cash", 0)) > int(b.get("cash", 0))
	)
	return list

func on_local_season_ended() -> void:
	if _has_emitted_season_end:
		return
	stop_spectating()
	if is_host:
		_has_emitted_season_end = true
		final_standings = get_sorted_standings()
		if _has_remote_peers():
			rpc("rpc_end_match", final_standings)
		else:
			match_ended.emit(final_standings)

# ---------------------------------------------------------------------------
# Godot High-Level RPC Endpoints
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func rpc_send_chat(sender_name: String, message: String, col: Color) -> void:
	chat_received.emit(sender_name, message, col)

@rpc("any_peer", "reliable")
func rpc_client_register(player_name: String) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player %d" % peer_id

	var existing_rid := get_slot_for_peer(peer_id)
	if not existing_rid.is_empty():
		region_slots[existing_rid]["name"] = clean_name
		lobby_updated.emit()
		_broadcast_lobby_state()
		return

	# Assign first Open slot, else first Computer slot, else first non-player slot
	var chosen_rid := ""
	for reg in REGION_TEAMS:
		var rid := str(reg["id"])
		if region_slots.has(rid) and str(region_slots[rid].get("type", "")) == "open":
			chosen_rid = rid
			break
	if chosen_rid.is_empty():
		for reg in REGION_TEAMS:
			var rid := str(reg["id"])
			if region_slots.has(rid) and str(region_slots[rid].get("type", "")) != "player":
				chosen_rid = rid
				break

	if chosen_rid.is_empty():
		broadcast_chat("System", "%s tried to join, but all 5 Region slots are occupied by players." % clean_name, Color(1.0, 0.55, 0.55))
		return

	var col_idx := pick_unique_color_idx(chosen_rid)
	var slot: Dictionary = region_slots[chosen_rid]
	slot["type"] = "player"
	slot["peer_id"] = peer_id
	slot["name"] = clean_name
	slot["status"] = "Player"
	slot["color_idx"] = col_idx

	broadcast_chat("System", "%s joined %s (Team %d)!" % [clean_name, str(slot["region_name"]), int(slot["team"])], FARMER_COLORS[col_idx])
	lobby_updated.emit()
	_broadcast_lobby_state()

@rpc("any_peer", "reliable")
func rpc_client_rename(new_name: String) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var rid := get_slot_for_peer(peer_id)
	if not rid.is_empty():
		var clean := new_name.strip_edges()
		if not clean.is_empty():
			region_slots[rid]["name"] = clean
			lobby_updated.emit()
			_broadcast_lobby_state()

@rpc("any_peer", "reliable")
func rpc_request_claim_region(target_rid: String) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_server_move_peer_to_region(peer_id, target_rid)

@rpc("any_peer", "reliable")
func rpc_request_cycle_color(slot_id: String) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_server_cycle_color(peer_id, slot_id)

@rpc("authority", "call_local", "reliable")
func rpc_sync_lobby(synced_slots: Dictionary, synced_settings: Dictionary) -> void:
	if not is_host:
		region_slots = synced_slots.duplicate(true)
		match_settings = synced_settings.duplicate(true)
		var found := get_slot_for_peer(local_peer_id)
		if not found.is_empty():
			my_slot_id = found
		lobby_updated.emit()

@rpc("authority", "call_local", "reliable")
func rpc_launch_match(final_slots: Dictionary, final_settings: Dictionary, initial_markets: Dictionary = {}) -> void:
	_commit_launch_match(final_slots, final_settings, initial_markets)

func notify_market_trade(region_id: String, crop_name: String, delta_supply: float, delta_demand: float) -> void:
	if not in_game_active:
		return
	var mkt_mgr = get_node_or_null("/root/MarketManager")
	if is_host:
		if _has_remote_peers() and mkt_mgr and mkt_mgr.has_method("export_all_markets"):
			rpc("rpc_sync_markets", mkt_mgr.export_all_markets())
	elif is_network_connected:
		rpc_id(1, "rpc_report_market_trade", region_id, crop_name, delta_supply, delta_demand)

@rpc("any_peer", "reliable")
func rpc_report_market_trade(region_id: String, crop_name: String, delta_supply: float, delta_demand: float) -> void:
	if not is_host or not in_game_active:
		return
	var mkt_mgr = get_node_or_null("/root/MarketManager")
	if mkt_mgr and mkt_mgr.has_method("apply_market_trade"):
		mkt_mgr.apply_market_trade(region_id, crop_name, delta_supply, delta_demand, false)
		if _has_remote_peers():
			rpc("rpc_sync_markets", mkt_mgr.export_all_markets())

@rpc("authority", "call_remote", "reliable")
func rpc_sync_markets(markets_payload: Dictionary) -> void:
	if is_host or not in_game_active:
		return
	var mkt_mgr = get_node_or_null("/root/MarketManager")
	if mkt_mgr and mkt_mgr.has_method("import_all_markets"):
		mkt_mgr.import_all_markets(markets_payload)

@rpc("any_peer", "reliable")
func rpc_client_submit_snapshot(snap: Dictionary) -> void:
	if not is_host or not in_game_active:
		return
	var sid := str(snap.get("slot_id", ""))
	if sid.is_empty():
		sid = get_slot_for_peer(multiplayer.get_remote_sender_id())
	if not sid.is_empty():
		snapshots[sid] = snap
		snapshots_updated.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_broadcast_snapshots(all_snaps: Dictionary) -> void:
	if not in_game_active:
		return
	var my_local: Dictionary = snapshots.get(my_slot_id, {})
	snapshots = all_snaps.duplicate(true)
	if not my_local.is_empty():
		snapshots[my_slot_id] = my_local
	snapshots_updated.emit()

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_sync_match_clock(host_day: int, host_hour: int, host_elapsed: float) -> void:
	if is_host or not in_game_active:
		return
	var tm_mgr = get_node_or_null("/root/TimeManager")
	if tm_mgr and tm_mgr.has_method("apply_network_clock"):
		tm_mgr.apply_network_clock(host_day, host_hour, host_elapsed)

@rpc("authority", "call_local", "reliable")
func rpc_end_match(standings: Array) -> void:
	_has_emitted_season_end = true
	stop_spectating()
	final_standings = standings.duplicate(true)
	var tm_mgr = get_node_or_null("/root/TimeManager")
	var data_mgr = get_node_or_null("/root/Data")
	var lbm = get_node_or_null("/root/LeaderboardManager")
	if tm_mgr:
		tm_mgr.force_stop_for_season_end()
		var target_d: int = int(data_mgr.get("selected_season_days")) if data_mgr else 30
		var cur_pts: int = int(lbm.get("current_points")) if lbm else 0
		tm_mgr.season_ended.emit(target_d, cur_pts)
	match_ended.emit(final_standings)
