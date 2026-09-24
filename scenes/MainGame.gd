# MainGame.gd
# Root script for the main gameplay scene.
# Responsible for spawning the AdminPanel if admin mode was enabled on the main menu.

extends Node2D

const ADMIN_FLAG_GROUP: String = "admin_mode_enabled"
const ADMIN_PANEL_SCRIPT: String = "res://src/AdminPanel.gd"

var _admin_panel: Node = null

func _ready() -> void:
	var flag_nodes: Array = get_tree().get_nodes_in_group(ADMIN_FLAG_GROUP)
	var admin_enabled: bool = flag_nodes.size() > 0

	if admin_enabled:
		_spawn_admin_panel()

func _spawn_admin_panel() -> void:
	var script: GDScript = load(ADMIN_PANEL_SCRIPT)
	if script == null:
		push_error("[MainGame] Failed to load AdminPanel script!")
		return

	_admin_panel = CanvasLayer.new()
	_admin_panel.set_script(script)
	_admin_panel.name = "AdminPanel"
	add_child(_admin_panel)
	_admin_panel.is_enabled = true

	# Show a brief hint so the player knows it is active
	_show_admin_hint()

func _show_admin_hint() -> void:
	var hint_label := Label.new()
	hint_label.text = "🛠️  Admin Mode ON  —  Press  `  to open panel"
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 0.3, 0.92))
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left   = 12
	hint_label.offset_bottom = -8
	hint_label.offset_top    = -36
	hint_label.offset_right  = 400
	hint_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var hint_layer := CanvasLayer.new()
	hint_layer.layer = 199
	hint_layer.add_child(hint_label)
	add_child(hint_layer)

	# Auto-hide after 5 in-game real seconds
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func(): if is_instance_valid(hint_layer): hint_layer.queue_free())
