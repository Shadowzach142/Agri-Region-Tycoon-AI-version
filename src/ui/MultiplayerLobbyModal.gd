# MultiplayerLobbyModal.gd
# Godot High-Level LAN Multiplayer Lobby for Agri-Region Tycoon.
# Backed by /root/MultiplayerManager (ENetMultiplayerPeer + SceneMultiplayer RPCs).
#
# Prototype Rules:
#   - 5 Regions = 5 Teams (1 Player/AI per Region — no teammates, 1 prototype gamemode).
#   - Each player claims a Region/Team and unique Farmer Color (matched in-game).
#   - Custom Season Days (30/60/90 preset or any number typed) + Fast-Paced RTS balancing.
#   - Live Leaderboard config (ON = toggleable standings + view rival farmers, OFF = Surprise Mode).

class_name MultiplayerLobbyModal
extends CanvasLayer

signal lobby_closed

const COL_W_REGION: float = 192.0
const COL_W_SLOT: float   = 180.0
const COL_W_COLOR: float  = 134.0
const COL_GAP: int        = 10
const ROW_H: float        = 34.0

const STYLE_BIG_BOX: StyleBox        = preload("res://assets/sprites/hud/Big-Rectangle-Box/BigPlainBox.tres")
const STYLE_INNER_BOX: StyleBox      = preload("res://assets/sprites/hud/Big-Rectangle-Box/InnerBox2x.tres")

# Wooden Rectangle Button Textures
const STYLE_WOOD_BTN: StyleBox       = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButton.tres")
const STYLE_WOOD_HOV: StyleBox       = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonHover.tres")
const STYLE_WOOD_PRESS: StyleBox     = preload("res://assets/sprites/hud/Buttons/WoodenButton/WoodenButtonPressed.tres")

# Brown Square Button Textures
const STYLE_SQ_BROWN_BTN: StyleBox   = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButton.tres")
const STYLE_SQ_BROWN_HOV: StyleBox   = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonHover.tres")
const STYLE_SQ_BROWN_PRESS: StyleBox = preload("res://assets/sprites/hud/Buttons/Squarebutton/SquareBrownButtonPressed.tres")

const COL_INK_DARK: Color  = Color(0.22, 0.13, 0.07, 1.0)
const COL_INK_MUTED: Color = Color(0.42, 0.28, 0.16, 1.0)
const COL_WC3_GOLD: Color  = Color(1.00, 0.86, 0.35, 1.0)
const COL_WC3_TEXT: Color  = Color(0.96, 0.92, 0.84, 1.0)
const COL_WC3_MUTED: Color = Color(0.76, 0.72, 0.64, 1.0)

const DAYS_PRESETS: Array[int] = [30, 60, 90]
const STARTING_CASH_OPTIONS: Array[Dictionary] = [
	{"cash": 2000, "label": "₱2,000 [Fast Default]"},
	{"cash": 3000, "label": "₱3,000 (Boom Economy)"},
	{"cash": 5000, "label": "₱5,000 (Rich Start)"},
	{"cash": 1000, "label": "₱1,000 (Hardcore)"},
	{"cash": 1500, "label": "₱1,500 (Standard)"}
]
const CROP_GROWTH_OPTIONS: Array[Dictionary] = [
	{"mult": 2.0, "label": "2.0x Fast Growth [Default]"},
	{"mult": 2.5, "label": "2.5x Blitz Growth"},
	{"mult": 3.0, "label": "3.0x Turbo Growth"},
	{"mult": 1.5, "label": "1.5x Moderate"}
]
const BUILD_SPEED_OPTIONS: Array[Dictionary] = [
	{"mult": 2.0, "label": "2.0x Fast [Default]"},
	{"mult": 3.0, "label": "3.0x Turbo Build"},
	{"mult": 1.0, "label": "1.0x Normal"}
]
const WEATHER_OPTIONS: Array[Dictionary] = [
	{"id": "normal",  "label": "Normal PAGASA [Default]"},
	{"id": "calm",    "label": "Calm Skies"},
	{"id": "extreme", "label": "Extreme Typhoon"}
]

var current_step: String = "entry"

var _dim_rect: ColorRect = null
var _main_panel: PanelContainer = null
var _entry_view: Control = null
var _lobby_view: Control = null

# Entry View
var _name_input: LineEdit = null
var _create_port_input: LineEdit = null
var _lan_ip_lbl: Label = null
var _ip_input: LineEdit = null
var _port_input: LineEdit = null
var _entry_status_lbl: Label = null

# Lobby View
var _rows_vbox: VBoxContainer = null
var _chat_log_vbox: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_input: LineEdit = null

# Right Config View
var _game_name_val_lbl: Label = null
var _host_status_val_lbl: Label = null
var _days_input: LineEdit = null
var _days_preset_btn: Button = null
var _cfg_cash_btn: Button = null
var _cfg_growth_btn: Button = null
var _cfg_build_btn: Button = null
var _cfg_weather_btn: Button = null
var _cfg_lb_btn: Button = null
var _reset_defaults_btn: Button = null
var _start_btn: Button = null

func _mp() -> Node:
	return get_node_or_null("/root/MultiplayerManager")

func _ready() -> void:
	layer = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_mp_signals()
	_show_entry_step()

func _exit_tree() -> void:
	var mp := _mp()
	if mp and not bool(mp.get("in_game_active")):
		if mp.has_method("disconnect_multiplayer"):
			mp.disconnect_multiplayer()

func _connect_mp_signals() -> void:
	var mp := _mp()
	if not mp:
		return
	if not mp.lobby_updated.is_connected(_on_mp_lobby_updated):
		mp.lobby_updated.connect(_on_mp_lobby_updated)
	if not mp.chat_received.is_connected(_on_mp_chat_received):
		mp.chat_received.connect(_on_mp_chat_received)
	if not mp.connection_status_changed.is_connected(_on_mp_status_changed):
		mp.connection_status_changed.connect(_on_mp_status_changed)
	if not mp.connection_failed.is_connected(_on_mp_connection_failed):
		mp.connection_failed.connect(_on_mp_connection_failed)
	if not mp.server_disconnected.is_connected(_on_mp_server_disconnected):
		mp.server_disconnected.connect(_on_mp_server_disconnected)

# ---------------------------------------------------------------------------
# Button Helpers
# ---------------------------------------------------------------------------
func _apply_wood_rect_button(btn: Button, font_sz: int = 12, font_col: Color = COL_WC3_TEXT) -> void:
	btn.add_theme_stylebox_override("normal", STYLE_WOOD_BTN)
	btn.add_theme_stylebox_override("hover", STYLE_WOOD_HOV)
	btn.add_theme_stylebox_override("pressed", STYLE_WOOD_PRESS)
	btn.add_theme_stylebox_override("focus", STYLE_WOOD_HOV)
	btn.add_theme_stylebox_override("disabled", STYLE_WOOD_BTN)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_WC3_MUTED)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

func _apply_brown_square_button(btn: Button, font_sz: int = 12, font_col: Color = COL_WC3_TEXT) -> void:
	btn.add_theme_stylebox_override("normal", STYLE_SQ_BROWN_BTN)
	btn.add_theme_stylebox_override("hover", STYLE_SQ_BROWN_HOV)
	btn.add_theme_stylebox_override("pressed", STYLE_SQ_BROWN_PRESS)
	btn.add_theme_stylebox_override("focus", STYLE_SQ_BROWN_HOV)
	btn.add_theme_stylebox_override("disabled", STYLE_SQ_BROWN_BTN)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_WC3_MUTED)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

func _apply_table_cell_button(btn: Button, font_sz: int = 11, font_col: Color = COL_WC3_TEXT, border_col: Color = Color(0.42, 0.34, 0.22, 0.80)) -> void:
	var norm := _make_flat_box(Color(0.14, 0.12, 0.10, 0.90), border_col, 1)
	var hov  := _make_flat_box(Color(0.22, 0.18, 0.13, 0.96), COL_WC3_GOLD, 1)
	var prs  := _make_flat_box(Color(0.10, 0.08, 0.06, 0.98), COL_WC3_GOLD, 1)
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("focus", hov)
	btn.add_theme_stylebox_override("disabled", norm)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_WC3_GOLD)
	btn.add_theme_color_override("font_disabled_color", font_col)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

func _set_panel_centered_size(w: float, h: float) -> void:
	if not _main_panel:
		return
	_main_panel.custom_minimum_size = Vector2(w, h)
	_main_panel.size = Vector2(w, h)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_main_panel.anchor_left     = 0.5
	_main_panel.anchor_top      = 0.5
	_main_panel.anchor_right    = 0.5
	_main_panel.anchor_bottom   = 0.5
	_main_panel.offset_left     = -w * 0.5
	_main_panel.offset_top      = -h * 0.5
	_main_panel.offset_right    =  w * 0.5
	_main_panel.offset_bottom   =  h * 0.5

# ---------------------------------------------------------------------------
# Step Navigation
# ---------------------------------------------------------------------------
func _show_entry_step() -> void:
	current_step = "entry"
	var mp := _mp()
	if mp and mp.has_method("disconnect_multiplayer"):
		mp.disconnect_multiplayer()
	if _entry_view:
		_entry_view.visible = true
	if _lobby_view:
		_lobby_view.visible = false
	_set_panel_centered_size(780.0, 460.0)
	_refresh_lan_ip_label()

func _show_lobby_step() -> void:
	current_step = "lobby"
	if _entry_view:
		_entry_view.visible = false
	if _lobby_view:
		_lobby_view.visible = true
	_set_panel_centered_size(1120.0, 620.0)
	_refresh_all_lobby_ui()

func _refresh_lan_ip_label() -> void:
	if not _lan_ip_lbl:
		return
	var mp := _mp()
	var ips: Array[String] = mp.get_local_lan_ips() if mp else ["127.0.0.1"]
	_lan_ip_lbl.text = "Your LAN IP: %s" % ", ".join(ips)

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_dim_rect = ColorRect.new()
	_dim_rect.name = "LobbyDimRect"
	_dim_rect.color = Color(0.03, 0.04, 0.03, 0.84)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim_rect)
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_panel = PanelContainer.new()
	_main_panel.name = "LobbyMainPanel"
	_main_panel.add_theme_stylebox_override("panel", STYLE_BIG_BOX)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_main_panel)
	_set_panel_centered_size(780.0, 460.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_panel.add_child(margin)

	_entry_view = _build_entry_view()
	margin.add_child(_entry_view)

	_lobby_view = _build_lobby_view()
	margin.add_child(_lobby_view)

# ---------------------------------------------------------------------------
# STEP 1: CREATE OR JOIN LAN SERVER
# ---------------------------------------------------------------------------
func _build_entry_view() -> Control:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 3)
	header.add_child(title_vb)

	var title := Label.new()
	title.text = "⚔️ LAN MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COL_INK_DARK)
	title_vb.add_child(title)

	var sub := Label.new()
	sub.text = "Host a custom RTS region lobby on your local network or join a friend's LAN IP"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_INK_MUTED)
	title_vb.add_child(sub)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_brown_square_button(close_btn, 14)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Player Nickname Bar
	var name_bar := PanelContainer.new()
	name_bar.add_theme_stylebox_override("panel", STYLE_INNER_BOX)
	root.add_child(name_bar)

	var nm_margin := MarginContainer.new()
	nm_margin.add_theme_constant_override("margin_left", 16)
	nm_margin.add_theme_constant_override("margin_right", 16)
	nm_margin.add_theme_constant_override("margin_top", 10)
	nm_margin.add_theme_constant_override("margin_bottom", 10)
	name_bar.add_child(nm_margin)

	var nm_hbox := HBoxContainer.new()
	nm_hbox.add_theme_constant_override("separation", 14)
	nm_margin.add_child(nm_hbox)

	var nm_lbl := Label.new()
	nm_lbl.text = "👤 Your Farmer Name:"
	nm_lbl.add_theme_font_size_override("font_size", 14)
	nm_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	nm_hbox.add_child(nm_lbl)

	var mp := _mp()
	_name_input = LineEdit.new()
	_name_input.text = str(mp.local_player_name) if mp else "Ka Kanor"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.custom_minimum_size = Vector2(220, 32)
	_name_input.text_changed.connect(func(txt: String):
		var m := _mp()
		if m:
			m.set_local_player_name(txt)
	)
	nm_hbox.add_child(_name_input)

	# Two Balanced Cards: CREATE LOBBY vs JOIN LOBBY
	var cards_hbox := HBoxContainer.new()
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.add_theme_constant_override("separation", 18)
	root.add_child(cards_hbox)

	# --- Card 1: CREATE LOBBY ---
	var create_card := PanelContainer.new()
	create_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_card.add_theme_stylebox_override("panel", STYLE_INNER_BOX)
	cards_hbox.add_child(create_card)

	var cc_margin := MarginContainer.new()
	cc_margin.add_theme_constant_override("margin_left", 22)
	cc_margin.add_theme_constant_override("margin_right", 22)
	cc_margin.add_theme_constant_override("margin_top", 18)
	cc_margin.add_theme_constant_override("margin_bottom", 18)
	create_card.add_child(cc_margin)

	var cc_vbox := VBoxContainer.new()
	cc_vbox.add_theme_constant_override("separation", 10)
	cc_margin.add_child(cc_vbox)

	var cc_title := Label.new()
	cc_title.text = "🏠 HOST LAN MATCH"
	cc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc_title.add_theme_font_size_override("font_size", 18)
	cc_title.add_theme_color_override("font_color", COL_WC3_GOLD)
	cc_vbox.add_child(cc_title)

	var cc_desc := Label.new()
	cc_desc.text = "Start a Godot ENet LAN server. Each of the 5 Regions is a competing team with unique farmer colors."
	cc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cc_desc.add_theme_font_size_override("font_size", 12)
	cc_desc.add_theme_color_override("font_color", COL_WC3_TEXT)
	cc_vbox.add_child(cc_desc)

	_lan_ip_lbl = Label.new()
	_lan_ip_lbl.text = "Your LAN IP: 127.0.0.1"
	_lan_ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lan_ip_lbl.add_theme_font_size_override("font_size", 12)
	_lan_ip_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 0.68))
	cc_vbox.add_child(_lan_ip_lbl)

	var cc_spacer_top := Control.new()
	cc_spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc_vbox.add_child(cc_spacer_top)

	var host_port_row := HBoxContainer.new()
	host_port_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_port_row.add_theme_constant_override("separation", 10)
	cc_vbox.add_child(host_port_row)

	var hp_lbl := Label.new()
	hp_lbl.text = "Host Port:"
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	host_port_row.add_child(hp_lbl)

	_create_port_input = LineEdit.new()
	_create_port_input.text = "7777"
	_create_port_input.custom_minimum_size = Vector2(110, 30)
	_create_port_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	host_port_row.add_child(_create_port_input)

	var cc_spacer_bot := Control.new()
	cc_spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc_vbox.add_child(cc_spacer_bot)

	var create_btn := Button.new()
	create_btn.text = "➕ CREATE LOBBY  >"
	create_btn.custom_minimum_size = Vector2(0, 44)
	_apply_wood_rect_button(create_btn, 15, COL_WC3_GOLD)
	create_btn.pressed.connect(_on_create_lobby_clicked)
	cc_vbox.add_child(create_btn)

	# --- Card 2: JOIN LOBBY ---
	var join_card := PanelContainer.new()
	join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	join_card.add_theme_stylebox_override("panel", STYLE_INNER_BOX)
	cards_hbox.add_child(join_card)

	var jc_margin := MarginContainer.new()
	jc_margin.add_theme_constant_override("margin_left", 22)
	jc_margin.add_theme_constant_override("margin_right", 22)
	jc_margin.add_theme_constant_override("margin_top", 18)
	jc_margin.add_theme_constant_override("margin_bottom", 18)
	join_card.add_child(jc_margin)

	var jc_vbox := VBoxContainer.new()
	jc_vbox.add_theme_constant_override("separation", 10)
	jc_margin.add_child(jc_vbox)

	var jc_title := Label.new()
	jc_title.text = "🔗 JOIN LAN MATCH"
	jc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jc_title.add_theme_font_size_override("font_size", 18)
	jc_title.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	jc_vbox.add_child(jc_title)

	var jc_desc := Label.new()
	jc_desc.text = "Enter the Host's LAN IP address (shown in their Host panel) and Port to join the match."
	jc_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jc_desc.add_theme_font_size_override("font_size", 12)
	jc_desc.add_theme_color_override("font_color", COL_WC3_TEXT)
	jc_vbox.add_child(jc_desc)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	jc_vbox.add_child(ip_row)

	var ip_lbl := Label.new()
	ip_lbl.text = "Host IP:"
	ip_lbl.custom_minimum_size = Vector2(70, 0)
	ip_lbl.add_theme_font_size_override("font_size", 13)
	ip_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	ip_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.placeholder_text = "e.g. 192.168.1.42"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_input.custom_minimum_size = Vector2(0, 30)
	ip_row.add_child(_ip_input)

	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	jc_vbox.add_child(port_row)

	var port_lbl := Label.new()
	port_lbl.text = "Port:"
	port_lbl.custom_minimum_size = Vector2(70, 0)
	port_lbl.add_theme_font_size_override("font_size", 13)
	port_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	port_row.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = "7777"
	_port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_port_input.custom_minimum_size = Vector2(0, 30)
	port_row.add_child(_port_input)

	_entry_status_lbl = Label.new()
	_entry_status_lbl.text = ""
	_entry_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_status_lbl.add_theme_font_size_override("font_size", 11)
	_entry_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	jc_vbox.add_child(_entry_status_lbl)

	var jc_spacer_bot := Control.new()
	jc_spacer_bot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jc_vbox.add_child(jc_spacer_bot)

	var join_btn := Button.new()
	join_btn.text = "🔗 JOIN SERVER  >"
	join_btn.custom_minimum_size = Vector2(0, 44)
	_apply_wood_rect_button(join_btn, 15, COL_WC3_GOLD)
	join_btn.pressed.connect(_on_join_lobby_clicked)
	jc_vbox.add_child(join_btn)

	return root

# ---------------------------------------------------------------------------
# STEP 2: CLEAN 5-REGION PROTOTYPE LOBBY
# ---------------------------------------------------------------------------
func _build_lobby_view() -> Control:
	var split_hbox := HBoxContainer.new()
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 14)
	split_hbox.visible = false

	# =========================================================================
	# LEFT COLUMN (Top: 5 Region Teams, Bottom: LAN Chat)
	# =========================================================================
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.60
	left_col.add_theme_constant_override("separation", 12)
	split_hbox.add_child(left_col)

	var slots_panel := PanelContainer.new()
	slots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.08, 0.09, 0.11, 0.96), Color(0.55, 0.44, 0.25, 1.0), 2))
	left_col.add_child(slots_panel)

	var sp_margin := MarginContainer.new()
	sp_margin.add_theme_constant_override("margin_left", 16)
	sp_margin.add_theme_constant_override("margin_top", 14)
	sp_margin.add_theme_constant_override("margin_right", 16)
	sp_margin.add_theme_constant_override("margin_bottom", 14)
	slots_panel.add_child(sp_margin)

	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 10)
	sp_margin.add_child(sp_vbox)

	# Header
	var sp_header := VBoxContainer.new()
	sp_header.add_theme_constant_override("separation", 2)
	sp_vbox.add_child(sp_header)

	var sp_title := Label.new()
	sp_title.text = "⚔️ REGION TEAMS (1 PLAYER PER REGION)"
	sp_title.add_theme_font_size_override("font_size", 15)
	sp_title.add_theme_color_override("font_color", COL_WC3_GOLD)
	sp_header.add_child(sp_title)

	var sp_sub := Label.new()
	sp_sub.text = "Click a Region row to switch teams • Click Farmer Color swatch to change your unique farmer color"
	sp_sub.add_theme_font_size_override("font_size", 11)
	sp_sub.add_theme_color_override("font_color", COL_WC3_MUTED)
	sp_header.add_child(sp_sub)

	# Column Headers
	var col_hdr := HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", COL_GAP)
	sp_vbox.add_child(col_hdr)

	col_hdr.add_child(_make_col_header_label("Team / Region", COL_W_REGION, false, HORIZONTAL_ALIGNMENT_LEFT))
	col_hdr.add_child(_make_col_header_label("Player / AI Slot", COL_W_SLOT, true, HORIZONTAL_ALIGNMENT_LEFT))
	col_hdr.add_child(_make_col_header_label("Farmer Color", COL_W_COLOR, false, HORIZONTAL_ALIGNMENT_CENTER))

	var hdr_sep := HSeparator.new()
	sp_vbox.add_child(hdr_sep)

	# Fixed 5-Row Container (no scrolling or cramped buttons!)
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 10)
	sp_vbox.add_child(_rows_vbox)

	# --- BOTTOM-LEFT PANEL: Lobby Chat ---
	var chat_panel := PanelContainer.new()
	chat_panel.custom_minimum_size = Vector2(0, 128)
	chat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_panel.size_flags_vertical = Control.SIZE_FILL
	chat_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.06, 0.07, 0.09, 0.96), Color(0.50, 0.40, 0.22, 1.0), 2))
	left_col.add_child(chat_panel)

	var cp_margin := MarginContainer.new()
	cp_margin.add_theme_constant_override("margin_left", 12)
	cp_margin.add_theme_constant_override("margin_top", 10)
	cp_margin.add_theme_constant_override("margin_right", 12)
	cp_margin.add_theme_constant_override("margin_bottom", 10)
	chat_panel.add_child(cp_margin)

	var cp_vbox := VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 6)
	cp_margin.add_child(cp_vbox)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cp_vbox.add_child(_chat_scroll)

	_chat_log_vbox = VBoxContainer.new()
	_chat_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log_vbox.add_theme_constant_override("separation", 3)
	_chat_scroll.add_child(_chat_log_vbox)

	var chat_input_row := HBoxContainer.new()
	chat_input_row.add_theme_constant_override("separation", 8)
	cp_vbox.add_child(chat_input_row)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Type a message to lobby..."
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size = Vector2(0, 30)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input_row.add_child(_chat_input)

	var send_btn := Button.new()
	send_btn.text = "Send"
	send_btn.custom_minimum_size = Vector2(76, 30)
	_apply_wood_rect_button(send_btn, 12)
	send_btn.pressed.connect(func(): _on_chat_submitted(_chat_input.text if _chat_input else ""))
	chat_input_row.add_child(send_btn)

	# =========================================================================
	# RIGHT COLUMN (Top: RTS Match Config, Bottom: Start / Cancel)
	# =========================================================================
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(390, 0)
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 12)
	split_hbox.add_child(right_col)

	var cfg_panel := PanelContainer.new()
	cfg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cfg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cfg_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.08, 0.09, 0.11, 0.96), Color(0.55, 0.44, 0.25, 1.0), 2))
	right_col.add_child(cfg_panel)

	var cfg_margin := MarginContainer.new()
	cfg_margin.add_theme_constant_override("margin_left", 16)
	cfg_margin.add_theme_constant_override("margin_top", 12)
	cfg_margin.add_theme_constant_override("margin_right", 16)
	cfg_margin.add_theme_constant_override("margin_bottom", 12)
	cfg_panel.add_child(cfg_margin)

	var cfg_vbox := VBoxContainer.new()
	cfg_vbox.add_theme_constant_override("separation", 8)
	cfg_margin.add_child(cfg_vbox)

	# Lobby Info + Close Square Button
	var gn_row := HBoxContainer.new()
	gn_row.add_theme_constant_override("separation", 8)
	cfg_vbox.add_child(gn_row)

	var gn_lbl := Label.new()
	gn_lbl.text = "Game Mode:"
	gn_lbl.add_theme_font_size_override("font_size", 12)
	gn_lbl.add_theme_color_override("font_color", COL_WC3_GOLD)
	gn_row.add_child(gn_lbl)

	_game_name_val_lbl = Label.new()
	_game_name_val_lbl.text = "⚔️ RTS Region Rivalry"
	_game_name_val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_name_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_game_name_val_lbl.add_theme_font_size_override("font_size", 12)
	_game_name_val_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	gn_row.add_child(_game_name_val_lbl)

	var lobby_close_sq := Button.new()
	lobby_close_sq.text = "✕"
	lobby_close_sq.tooltip_text = "Close Multiplayer Lobby"
	lobby_close_sq.custom_minimum_size = Vector2(30, 30)
	_apply_brown_square_button(lobby_close_sq, 12)
	lobby_close_sq.pressed.connect(_on_close_pressed)
	gn_row.add_child(lobby_close_sq)

	var hs_row := HBoxContainer.new()
	cfg_vbox.add_child(hs_row)

	var hs_lbl := Label.new()
	hs_lbl.text = "Network:"
	hs_lbl.add_theme_font_size_override("font_size", 12)
	hs_lbl.add_theme_color_override("font_color", COL_WC3_GOLD)
	hs_row.add_child(hs_lbl)

	_host_status_val_lbl = Label.new()
	_host_status_val_lbl.text = "Hosting LAN"
	_host_status_val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_status_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_host_status_val_lbl.add_theme_font_size_override("font_size", 11)
	_host_status_val_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 0.65))
	hs_row.add_child(_host_status_val_lbl)

	var cfg_sep := HSeparator.new()
	cfg_vbox.add_child(cfg_sep)

	# Config Title + Default Reset
	var rules_hdr := HBoxContainer.new()
	rules_hdr.add_theme_constant_override("separation", 8)
	cfg_vbox.add_child(rules_hdr)

	var rules_title := Label.new()
	rules_title.text = "⚙️ RTS MATCH CONFIG"
	rules_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_title.add_theme_font_size_override("font_size", 14)
	rules_title.add_theme_color_override("font_color", COL_WC3_GOLD)
	rules_hdr.add_child(rules_title)

	_reset_defaults_btn = Button.new()
	_reset_defaults_btn.text = "🔄 Default"
	_reset_defaults_btn.tooltip_text = "Reset match configuration to balanced fast RTS defaults"
	_reset_defaults_btn.custom_minimum_size = Vector2(98, 28)
	_apply_wood_rect_button(_reset_defaults_btn, 11, COL_WC3_GOLD)
	_reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)
	rules_hdr.add_child(_reset_defaults_btn)

	# Season Days Row (Custom numeric input OR 30/60/90 quick preset cycle)
	var days_row := HBoxContainer.new()
	days_row.add_theme_constant_override("separation", 8)
	cfg_vbox.add_child(days_row)

	var days_lbl := Label.new()
	days_lbl.text = "Season Days:"
	days_lbl.custom_minimum_size = Vector2(126, 0)
	days_lbl.add_theme_font_size_override("font_size", 12)
	days_lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	days_row.add_child(days_lbl)

	_days_input = LineEdit.new()
	_days_input.text = "30"
	_days_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_days_input.tooltip_text = "Type any number of days (5–365) or click 30/60/90"
	_days_input.custom_minimum_size = Vector2(68, 28)
	_days_input.text_submitted.connect(_on_days_submitted)
	_days_input.focus_exited.connect(func(): _on_days_submitted(_days_input.text if _days_input else "30"))
	days_row.add_child(_days_input)

	_days_preset_btn = Button.new()
	_days_preset_btn.text = "30 / 60 / 90"
	_days_preset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_days_preset_btn.custom_minimum_size = Vector2(0, 28)
	_apply_wood_rect_button(_days_preset_btn, 11, COL_WC3_GOLD)
	_days_preset_btn.pressed.connect(_cycle_days_preset)
	days_row.add_child(_days_preset_btn)

	_cfg_cash_btn    = _add_config_row(cfg_vbox, "Money Start:", _cycle_starting_cash)
	_cfg_growth_btn  = _add_config_row(cfg_vbox, "Crop Growth:", _cycle_crop_growth)
	_cfg_build_btn   = _add_config_row(cfg_vbox, "Build Speed:", _cycle_build_speed)
	_cfg_weather_btn = _add_config_row(cfg_vbox, "Weather / Hazard:", _cycle_weather)
	_cfg_lb_btn      = _add_config_row(cfg_vbox, "Live Leaderboard:", _toggle_leaderboard_config)

	var cfg_spacer := Control.new()
	cfg_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cfg_vbox.add_child(cfg_spacer)

	# Pace & Leaderboard Note Box
	var desc_box := PanelContainer.new()
	desc_box.add_theme_stylebox_override("panel", _make_flat_box(Color(0.11, 0.13, 0.16, 0.95), Color(0.36, 0.32, 0.22, 1.0), 1))
	cfg_vbox.add_child(desc_box)

	var desc_margin := MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 10)
	desc_margin.add_theme_constant_override("margin_top", 8)
	desc_margin.add_theme_constant_override("margin_right", 10)
	desc_margin.add_theme_constant_override("margin_bottom", 8)
	desc_box.add_child(desc_margin)

	var desc_lbl := Label.new()
	desc_lbl.text = "⚔️ Calm Shared RTS Clock (1.0x Pace — Pause & 1x/2x/3x speed disabled) with Fast Crop Growth default. Click rivals on the Leaderboard to watch their farmers live!"
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", COL_WC3_MUTED)
	desc_margin.add_child(desc_lbl)

	# --- BOTTOM-RIGHT PANEL: Start / Cancel ---
	var action_panel := PanelContainer.new()
	action_panel.custom_minimum_size = Vector2(0, 128)
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_panel.size_flags_vertical = Control.SIZE_FILL
	action_panel.add_theme_stylebox_override("panel", _make_flat_box(Color(0.08, 0.09, 0.11, 0.96), Color(0.55, 0.44, 0.25, 1.0), 2))
	right_col.add_child(action_panel)

	var act_margin := MarginContainer.new()
	act_margin.add_theme_constant_override("margin_left", 16)
	act_margin.add_theme_constant_override("margin_top", 14)
	act_margin.add_theme_constant_override("margin_right", 16)
	act_margin.add_theme_constant_override("margin_bottom", 14)
	action_panel.add_child(act_margin)

	var act_vbox := VBoxContainer.new()
	act_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	act_vbox.add_theme_constant_override("separation", 10)
	act_margin.add_child(act_vbox)

	_start_btn = Button.new()
	_start_btn.text = "🚀 Start Game"
	_start_btn.custom_minimum_size = Vector2(0, 44)
	_apply_wood_rect_button(_start_btn, 15, COL_WC3_GOLD)
	_start_btn.pressed.connect(_on_start_match_pressed)
	act_vbox.add_child(_start_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 38)
	_apply_wood_rect_button(cancel_btn, 13)
	cancel_btn.pressed.connect(_show_entry_step)
	act_vbox.add_child(cancel_btn)

	_append_chat_message("System", "Welcome! Each player chooses a Region & unique Farmer Color. Configure days, economy pace, or Surprise Mode on the right.", Color(0.85, 0.85, 0.78))

	return split_hbox

func _make_col_header_label(txt: String, col_w: float, expand: bool, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size = Vector2(col_w, 20)
	l.horizontal_alignment = align
	l.clip_text = true
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		l.size_flags_horizontal = Control.SIZE_FILL
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_WC3_GOLD)
	return l

func _add_config_row(parent: VBoxContainer, label_txt: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(126, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COL_WC3_TEXT)
	row.add_child(lbl)

	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 28)
	btn.clip_text = true
	_apply_wood_rect_button(btn, 11)
	btn.pressed.connect(callback)
	row.add_child(btn)
	return btn

# ---------------------------------------------------------------------------
# Refresh Lobby Roster & Config UI
# ---------------------------------------------------------------------------
func _refresh_all_lobby_ui() -> void:
	_refresh_roster_rows()
	_refresh_config_ui()

func _refresh_roster_rows() -> void:
	if not _rows_vbox:
		return
	while _rows_vbox.get_child_count() > 0:
		var ch := _rows_vbox.get_child(0)
		_rows_vbox.remove_child(ch)
		ch.queue_free()

	var mp := _mp()
	if not mp:
		return

	var am_host: bool = bool(mp.is_host)
	var my_pid: int = int(mp.local_peer_id)
	var slots: Dictionary = mp.region_slots

	for reg in mp.REGION_TEAMS:
		var rid := str(reg["id"])
		if not slots.has(rid):
			continue
		var slot: Dictionary = slots[rid]
		var stype := str(slot.get("type", "open"))
		var pid := int(slot.get("peer_id", 0))
		var is_me: bool = (stype == "player" and pid == my_pid)
		var is_human: bool = (stype == "player")
		var c_idx := posmod(int(slot.get("color_idx", 0)), mp.FARMER_COLORS.size())
		var farmer_col: Color = mp.FARMER_COLORS[c_idx]
		var farmer_cname: String = mp.FARMER_COLOR_NAMES[c_idx]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", COL_GAP)
		_rows_vbox.add_child(row)

		# 1. Region / Team Column (Click any non-human region to move into that team!)
		var reg_btn := Button.new()
		reg_btn.custom_minimum_size = Vector2(COL_W_REGION, ROW_H)
		reg_btn.size_flags_horizontal = Control.SIZE_FILL
		reg_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		reg_btn.clip_text = true
		var reg_prefix := "★ " if is_me else ""
		reg_btn.text = "%sT%d • %s" % [reg_prefix, int(slot.get("team", 1)), str(slot.get("region_name", ""))]
		var border_col := farmer_col if is_me else Color(0.42, 0.34, 0.22, 0.80)
		_apply_table_cell_button(reg_btn, 12, COL_WC3_GOLD if is_me else COL_WC3_TEXT, border_col)
		var r_data: Dictionary = Data.get_region(rid)
		var r_mods: Dictionary = Data.get_region_modifiers(rid)
		var r_pros: Array = r_data.get("pros", [])
		var r_cons: Array = r_data.get("cons", [])
		var spec_names: Array[String] = []
		for sc in r_mods.get("specialty_crops", []):
			spec_names.append(str(Data.get_crop(str(sc)).get("display_name", str(sc))).split("(")[0].strip_edges())
		var info_lines: Array[String] = []
		info_lines.append("Specialties: %s  |  Baseline Moisture: %.0f%%" % [", ".join(spec_names), float(r_data.get("soil_moisture", 55.0))])
		if not r_pros.is_empty():
			info_lines.append("PROS: " + " • ".join(PackedStringArray(r_pros)))
		if not r_cons.is_empty():
			info_lines.append("CONS: " + " • ".join(PackedStringArray(r_cons)))
		var reg_info_tip: String = "\n".join(info_lines)

		if is_me:
			reg_btn.tooltip_text = "Your active Region & Team\n" + reg_info_tip
		elif is_human:
			reg_btn.tooltip_text = "Occupied by %s\n%s" % [str(slot.get("name", "Player")), reg_info_tip]
		else:
			reg_btn.tooltip_text = "Click to play as %s (Team %d)\n%s" % [str(slot.get("region_name", "")), int(slot.get("team", 1)), reg_info_tip]
			reg_btn.pressed.connect(func(): _on_region_row_clicked(rid))
		row.add_child(reg_btn)

		# 2. Player / Slot Column
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(COL_W_SLOT, ROW_H)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.clip_text = true
		if is_me:
			slot_btn.text = "👑 %s (You)" % str(slot.get("name", "You"))
			slot_btn.tooltip_text = "Click another Region row on the left to switch Regions"
			_apply_wood_rect_button(slot_btn, 12, COL_WC3_GOLD)
		elif is_human:
			slot_btn.text = "🌐 %s" % str(slot.get("name", "Player"))
			slot_btn.tooltip_text = "Connected LAN Player"
			_apply_wood_rect_button(slot_btn, 12, Color(0.65, 0.90, 1.0))
			slot_btn.disabled = true
		else:
			var status_str := str(slot.get("status", "Open"))
			if am_host:
				slot_btn.text = status_str + " ▾"
				slot_btn.tooltip_text = "Host: Click to cycle Computer / Open / Closed"
				var txt_col := Color(0.95, 0.85, 0.35) if status_str == "Open" else (Color(0.55, 0.55, 0.58) if status_str == "Closed" else COL_WC3_TEXT)
				_apply_table_cell_button(slot_btn, 11, txt_col)
				slot_btn.pressed.connect(func(): _on_slot_status_clicked(rid))
			else:
				slot_btn.text = status_str
				if status_str != "Closed":
					slot_btn.tooltip_text = "Click to move into this Region"
					_apply_table_cell_button(slot_btn, 11, Color(0.95, 0.85, 0.35) if status_str == "Open" else COL_WC3_TEXT)
					slot_btn.pressed.connect(func(): _on_region_row_clicked(rid))
				else:
					_apply_table_cell_button(slot_btn, 11, Color(0.50, 0.50, 0.52))
					slot_btn.disabled = true
		row.add_child(slot_btn)

		# 3. Farmer Color Column (Square swatch frame + Farmer variant name, strictly unique)
		var color_wrap := HBoxContainer.new()
		color_wrap.custom_minimum_size = Vector2(COL_W_COLOR, ROW_H)
		color_wrap.add_theme_constant_override("separation", 6)
		row.add_child(color_wrap)

		var color_btn := Button.new()
		color_btn.custom_minimum_size = Vector2(ROW_H, ROW_H)
		var can_edit_color: bool = is_me or (am_host and not is_human and stype != "closed")
		color_btn.tooltip_text = "Farmer Color: %s (Unique)" % farmer_cname if not can_edit_color else "Farmer Color: %s (Click to cycle unique color)" % farmer_cname
		_apply_brown_square_button(color_btn, 10)
		color_btn.disabled = not can_edit_color
		if can_edit_color:
			color_btn.pressed.connect(func(): _on_color_clicked(rid))

		var swatch := ColorRect.new()
		swatch.color = farmer_col if stype != "closed" else Color(0.22, 0.22, 0.22)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 6
		swatch.offset_top = 6
		swatch.offset_right = -6
		swatch.offset_bottom = -6
		color_btn.add_child(swatch)
		color_wrap.add_child(color_btn)

		var cname_lbl := Label.new()
		cname_lbl.text = farmer_cname if stype != "closed" else "—"
		cname_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cname_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cname_lbl.clip_text = true
		cname_lbl.add_theme_font_size_override("font_size", 11)
		cname_lbl.add_theme_color_override("font_color", COL_WC3_TEXT if stype != "closed" else Color(0.50, 0.50, 0.50))
		color_wrap.add_child(cname_lbl)

func _refresh_config_ui() -> void:
	var mp := _mp()
	if not mp:
		return
	var am_host: bool = bool(mp.is_host)
	var cfg: Dictionary = mp.match_settings
	var days_val: int = int(cfg.get("days", 30))
	var cash_val: int = int(cfg.get("cash", 2000))
	var growth_val: float = float(cfg.get("crop_growth", 2.0))
	var build_val: float = float(cfg.get("build_speed", 2.0))
	var weather_val: String = str(cfg.get("weather", "normal"))
	var lb_on: bool = bool(cfg.get("leaderboard_enabled", true))

	if _host_status_val_lbl:
		var ips: Array[String] = mp.get_local_lan_ips()
		var p_port: int = int(_create_port_input.text) if _create_port_input else 7777
		if am_host:
			_host_status_val_lbl.text = "Host LAN: %s:%d" % [ips[0], p_port]
			_host_status_val_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 0.65))
		else:
			_host_status_val_lbl.text = "Joined LAN Client"
			_host_status_val_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))

	if _days_input and not _days_input.has_focus():
		_days_input.text = str(days_val)
	if _days_input:
		_days_input.editable = am_host

	if _days_preset_btn:
		_days_preset_btn.disabled = not am_host
		_days_preset_btn.text = "%dd (30/60/90)" % days_val

	if _cfg_cash_btn:
		_cfg_cash_btn.disabled = not am_host
		_cfg_cash_btn.text = "₱%d" % cash_val
		for opt in STARTING_CASH_OPTIONS:
			if int(opt["cash"]) == cash_val:
				_cfg_cash_btn.text = str(opt["label"])
				break

	if _cfg_growth_btn:
		_cfg_growth_btn.disabled = not am_host
		_cfg_growth_btn.text = "%.1fx" % growth_val
		for opt in CROP_GROWTH_OPTIONS:
			if is_equal_approx(float(opt["mult"]), growth_val):
				_cfg_growth_btn.text = str(opt["label"])
				break

	if _cfg_build_btn:
		_cfg_build_btn.disabled = not am_host
		_cfg_build_btn.text = "%.1fx" % build_val
		for opt in BUILD_SPEED_OPTIONS:
			if is_equal_approx(float(opt["mult"]), build_val):
				_cfg_build_btn.text = str(opt["label"])
				break

	if _cfg_weather_btn:
		_cfg_weather_btn.disabled = not am_host
		for opt in WEATHER_OPTIONS:
			if opt["id"] == weather_val:
				_cfg_weather_btn.text = str(opt["label"])
				break

	if _cfg_lb_btn:
		_cfg_lb_btn.disabled = not am_host
		_cfg_lb_btn.text = "👁 ON (View & Toggle)" if lb_on else "🎁 OFF (Surprise Mode)"

	if _reset_defaults_btn:
		_reset_defaults_btn.visible = am_host

	if _start_btn:
		_start_btn.disabled = not am_host
		_start_btn.text = "🚀 Start Game" if am_host else "⏳ Waiting for Host..."

# ---------------------------------------------------------------------------
# User Actions
# ---------------------------------------------------------------------------
func _on_create_lobby_clicked() -> void:
	var mp := _mp()
	if not mp:
		return
	var p_name: String = _name_input.text if _name_input else "Ka Kanor"
	var port: int = int(_create_port_input.text) if _create_port_input else 7777
	if port <= 0:
		port = 7777
	mp.host_lobby(port, p_name)
	_play_sfx("tech_unlock")
	_show_lobby_step()

func _on_join_lobby_clicked() -> void:
	var mp := _mp()
	if not mp:
		return
	var p_name: String = _name_input.text if _name_input else "Farmer Guest"
	var ip: String = _ip_input.text.strip_edges() if _ip_input else "127.0.0.1"
	var port: int = int(_port_input.text) if _port_input else 7777
	if ip.is_empty():
		ip = "127.0.0.1"
	if port <= 0:
		port = 7777
	var err: int = mp.join_lobby(ip, port, p_name)
	if err == OK:
		_play_sfx("click")
		_show_lobby_step()

func _on_region_row_clicked(rid: String) -> void:
	var mp := _mp()
	if mp:
		_play_sfx("click")
		mp.request_claim_region(rid)

func _on_slot_status_clicked(rid: String) -> void:
	var mp := _mp()
	if mp:
		_play_sfx("click")
		mp.request_cycle_slot_status(rid)

func _on_color_clicked(rid: String) -> void:
	var mp := _mp()
	if mp:
		_play_sfx("click")
		mp.request_cycle_color(rid)

func _on_days_submitted(txt: String) -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var val := clampi(int(txt.strip_edges()), 5, 365)
	if _days_input:
		_days_input.text = str(val)
	mp.update_match_settings({"days": val})

func _cycle_days_preset() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := int(mp.match_settings.get("days", 30))
	var idx := DAYS_PRESETS.find(cur)
	var nxt := DAYS_PRESETS[(idx + 1) % DAYS_PRESETS.size()]
	_play_sfx("click")
	mp.update_match_settings({"days": nxt})

func _cycle_starting_cash() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := int(mp.match_settings.get("cash", 2000))
	var nxt := STARTING_CASH_OPTIONS[0]["cash"]
	for i in range(STARTING_CASH_OPTIONS.size()):
		if int(STARTING_CASH_OPTIONS[i]["cash"]) == cur:
			nxt = int(STARTING_CASH_OPTIONS[(i + 1) % STARTING_CASH_OPTIONS.size()]["cash"])
			break
	_play_sfx("click")
	mp.update_match_settings({"cash": nxt})

func _cycle_crop_growth() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := float(mp.match_settings.get("crop_growth", 2.0))
	var nxt := float(CROP_GROWTH_OPTIONS[0]["mult"])
	for i in range(CROP_GROWTH_OPTIONS.size()):
		if is_equal_approx(float(CROP_GROWTH_OPTIONS[i]["mult"]), cur):
			nxt = float(CROP_GROWTH_OPTIONS[(i + 1) % CROP_GROWTH_OPTIONS.size()]["mult"])
			break
	_play_sfx("click")
	mp.update_match_settings({"crop_growth": nxt})

func _cycle_build_speed() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := float(mp.match_settings.get("build_speed", 2.0))
	var nxt := float(BUILD_SPEED_OPTIONS[0]["mult"])
	for i in range(BUILD_SPEED_OPTIONS.size()):
		if is_equal_approx(float(BUILD_SPEED_OPTIONS[i]["mult"]), cur):
			nxt = float(BUILD_SPEED_OPTIONS[(i + 1) % BUILD_SPEED_OPTIONS.size()]["mult"])
			break
	_play_sfx("click")
	mp.update_match_settings({"build_speed": nxt})

func _cycle_weather() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := str(mp.match_settings.get("weather", "normal"))
	var nxt := str(WEATHER_OPTIONS[0]["id"])
	for i in range(WEATHER_OPTIONS.size()):
		if WEATHER_OPTIONS[i]["id"] == cur:
			nxt = str(WEATHER_OPTIONS[(i + 1) % WEATHER_OPTIONS.size()]["id"])
			break
	_play_sfx("click")
	mp.update_match_settings({"weather": nxt})

func _toggle_leaderboard_config() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	var cur := bool(mp.match_settings.get("leaderboard_enabled", true))
	_play_sfx("click")
	mp.update_match_settings({"leaderboard_enabled": not cur})

func _on_reset_defaults_pressed() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	_play_sfx("click")
	mp.reset_match_settings()
	mp.update_match_settings({})
	_append_chat_message("System", "Match rules reset to Balanced RTS Defaults (1.0x Clock, 2.0x Crop Growth).", COL_WC3_GOLD)

func _on_start_match_pressed() -> void:
	var mp := _mp()
	if not mp or not bool(mp.is_host):
		return
	# Commit any typed days before launching
	if _days_input:
		var val := clampi(int(_days_input.text.strip_edges()), 5, 365)
		mp.update_match_settings({"days": val})
	_play_sfx("tech_unlock")
	mp.start_match()

func _on_chat_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	if _chat_input:
		_chat_input.text = ""
	var mp := _mp()
	if mp:
		var col := COL_WC3_GOLD
		var my_rid := str(mp.my_slot_id)
		if mp.region_slots.has(my_rid):
			var c_idx := posmod(int(mp.region_slots[my_rid].get("color_idx", 0)), mp.FARMER_COLORS.size())
			col = mp.FARMER_COLORS[c_idx].lightened(0.25)
		mp.broadcast_chat(str(mp.local_player_name), clean, col)

func _on_mp_lobby_updated() -> void:
	if current_step == "lobby":
		_refresh_all_lobby_ui()

func _on_mp_chat_received(sender_name: String, message: String, col: Color) -> void:
	_append_chat_message(sender_name, message, col)

func _on_mp_status_changed(status_text: String, is_err: bool) -> void:
	if _entry_status_lbl:
		_entry_status_lbl.text = status_text if is_err else ""

func _on_mp_connection_failed() -> void:
	_show_entry_step()
	if _entry_status_lbl:
		_entry_status_lbl.text = "⚠️ Connection failed — check host IP & Port."

func _on_mp_server_disconnected() -> void:
	_show_entry_step()
	if _entry_status_lbl:
		_entry_status_lbl.text = "⚠️ Host closed the lobby."

func _append_chat_message(sender: String, msg: String, col: Color = COL_WC3_TEXT) -> void:
	if not _chat_log_vbox:
		return
	var lbl := Label.new()
	lbl.text = "[%s]: %s" % [sender, msg]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	_chat_log_vbox.add_child(lbl)
	if _chat_log_vbox.get_child_count() > 50:
		var old := _chat_log_vbox.get_child(0)
		_chat_log_vbox.remove_child(old)
		old.queue_free()
	await get_tree().process_frame
	if _chat_scroll and _chat_scroll.get_v_scroll_bar():
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)

func _on_close_pressed() -> void:
	var mp := _mp()
	if mp and mp.has_method("disconnect_multiplayer"):
		mp.disconnect_multiplayer()
	lobby_closed.emit()
	queue_free()

func _play_sfx(sound_name: String) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return
	var am = get_tree().root.get_node_or_null("AudioManager")
	if am:
		if sound_name == "click" and am.has_method("play_ui"):
			am.play_ui("click")
		elif sound_name == "tech_unlock" and am.has_method("play_tech"):
			am.play_tech("unlock")

func _make_flat_box(bg: Color, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s
