# MainGame.gd
# Root script for the main gameplay scene.
# Responsible for spawning the AdminPanel if admin mode was enabled on the main menu,
# and for creating the PauseMenu (ESC or menu icon).

extends Node2D

const ADMIN_FLAG_GROUP: String  = "admin_mode_enabled"
const ADMIN_PANEL_SCRIPT: String = "res://src/ui/AdminPanel.gd"
const PAUSE_MENU_SCRIPT: String  = "res://src/ui/PauseMenu.gd"
const BACKLOG_PANEL_SCRIPT: String = "res://src/ui/BacklogPanel.gd"
const LEADERBOARD_PANEL_SCRIPT: String = "res://src/ui/LeaderboardPanel.gd"

var _admin_panel: Node = null
var _pause_menu: CanvasLayer = null
var _backlog_panel: CanvasLayer = null
var _leaderboard_panel: CanvasLayer = null

func _ready() -> void:
	_spawn_admin_panel()
	_spawn_pause_menu()
	_spawn_backlog_panel()
	_spawn_leaderboard_panel()
	_start_background_soundtrack()

func _start_background_soundtrack() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_soundtrack"):
		audio_mgr.play_soundtrack("countryside_morning")

# ---------------------------------------------------------------------------
# Backlog Panel
# ---------------------------------------------------------------------------
func _spawn_backlog_panel() -> void:
	var script: GDScript = load(BACKLOG_PANEL_SCRIPT)
	if script == null:
		push_error("[MainGame] Failed to load BacklogPanel script!")
		return

	_backlog_panel = CanvasLayer.new()
	_backlog_panel.set_script(script)
	_backlog_panel.name = "BacklogPanel"
	_backlog_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_backlog_panel)

# ---------------------------------------------------------------------------
# Leaderboard Panel
# ---------------------------------------------------------------------------
func _spawn_leaderboard_panel() -> void:
	var script: GDScript = load(LEADERBOARD_PANEL_SCRIPT)
	if script == null:
		push_error("[MainGame] Failed to load LeaderboardPanel script!")
		return

	_leaderboard_panel = CanvasLayer.new()
	_leaderboard_panel.set_script(script)
	_leaderboard_panel.name = "LeaderboardPanel"
	_leaderboard_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_leaderboard_panel)

# ---------------------------------------------------------------------------
# Pause Menu
# ---------------------------------------------------------------------------
func _spawn_pause_menu() -> void:
	var script: GDScript = load(PAUSE_MENU_SCRIPT)
	if script == null:
		push_error("[MainGame] Failed to load PauseMenu script!")
		return

	_pause_menu = CanvasLayer.new()
	_pause_menu.set_script(script)
	_pause_menu.name = "PauseMenu"
	# Must process even when tree is paused so the resume button works
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)

# ---------------------------------------------------------------------------
# Admin Panel
# ---------------------------------------------------------------------------
func _spawn_admin_panel() -> void:
	var script: GDScript = load(ADMIN_PANEL_SCRIPT)
	if script == null:
		push_error("[MainGame] Failed to load AdminPanel script!")
		return

	_admin_panel = CanvasLayer.new()
	_admin_panel.set_script(script)
	_admin_panel.name = "AdminPanel"
	_admin_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_admin_panel)
	_admin_panel.is_enabled = true
