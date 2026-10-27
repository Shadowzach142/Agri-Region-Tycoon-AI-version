# PauseMenu.gd
# A CanvasLayer pause overlay triggered by ESC or the HUD settings icon.
# Fully centered to eliminate any bottom/edge clipping on 720p screens.
# Includes: Resume, Save Farm, Load Farm, Personal Records (J), Farm Chronicle (L), Main Menu, Quit Game.

extends CanvasLayer

signal resumed
signal quit_to_menu

var _visible: bool = false

# -- Colours -------------------------------------------------------------------
const BG_COLOR      := Color(0.02, 0.04, 0.02, 0.72)
const PANEL_COLOR   := Color(0.10, 0.15, 0.08, 1.0) # 100% opaque to prevent background bleed-through
const TITLE_COLOR   := Color(0.78, 0.96, 0.42, 1.0)
const BTN_NORMAL    := Color(0.18, 0.32, 0.14, 1.0)
const BTN_HOVER     := Color(0.26, 0.46, 0.18, 1.0)
const BTN_RESUME    := Color(0.15, 0.52, 0.20, 1.0)
const BTN_RESUME_HO := Color(0.20, 0.68, 0.28, 1.0)
const BTN_DANGER    := Color(0.50, 0.14, 0.14, 1.0)
const BTN_DANGER_HO := Color(0.70, 0.18, 0.18, 1.0)

const SaveLoadModalScript = preload("res://src/ui/SaveLoadModal.gd")

var _dim: ColorRect
var _panel: PanelContainer

var _resume_btn: Button
var _save_btn: Button
var _load_btn: Button
var _records_btn: Button
var _log_btn: Button
var _debug_btn: Button
var _menu_btn: Button
var _quit_btn: Button
var _music_track_label: Label = null
var _music_mute_btn: Button = null

# -- Setup ---------------------------------------------------------------------
func _ready() -> void:
	layer = 200
	visible = false

	# 1. Dark semi-transparent dim backdrop
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_on_resume()
	)
	add_child(_dim)

	# 2. Main Centered Window
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -215.0
	_panel.offset_top    = -285.0
	_panel.offset_right  =  215.0
	_panel.offset_bottom =  285.0
	_panel.custom_minimum_size = Vector2(430, 570)

	var ps = preload("res://assets/sprites/StartMenu/BigRectangleLogs.tres")
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.pivot_offset = Vector2(215.0, 285.0)
	add_child(_panel)

	if AudioManager.has_signal("soundtrack_changed"):
		AudioManager.soundtrack_changed.connect(func(_t): _update_music_ui())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   42)
	margin.add_theme_constant_override("margin_right",  42)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Agri-Region Tycoon"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.38, 0.26, 0.16, 0.95))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.45, 0.35, 0.22, 0.7))
	vbox.add_child(sep)

	# Buttons with authentic pixel art button textures
	_resume_btn = _make_gold_button("▶ Resume")
	_resume_btn.pressed.connect(_on_resume)
	vbox.add_child(_resume_btn)

	_save_btn = _make_brown_button("💾 Save Farm")
	_save_btn.pressed.connect(_on_save_game)
	vbox.add_child(_save_btn)

	_load_btn = _make_brown_button("📂 Load Farm")
	_load_btn.pressed.connect(_on_load_game)
	vbox.add_child(_load_btn)

	# Dedicated Personal Records button moved here from the HUD
	_records_btn = _make_brown_button("🏆 Personal Records (J)")
	_records_btn.pressed.connect(_on_records)
	vbox.add_child(_records_btn)

	_log_btn = _make_brown_button("📜 Farm Chronicle (L)")
	_log_btn.pressed.connect(_on_backlog)
	vbox.add_child(_log_btn)

	_debug_btn = _make_brown_button("🛠️ Debug Console (`)")
	_debug_btn.pressed.connect(_on_debug_console)
	vbox.add_child(_debug_btn)

	_menu_btn = _make_brown_button("🏠 Main Menu")
	_menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(_menu_btn)

	_quit_btn = _make_brown_button("🚪 Quit Game", Color(1.0, 0.65, 0.60))
	_quit_btn.pressed.connect(_on_quit)
	vbox.add_child(_quit_btn)

	# Cozy Soundtrack Controller Row
	var music_box := HBoxContainer.new()
	music_box.alignment = BoxContainer.ALIGNMENT_CENTER
	music_box.add_theme_constant_override("separation", 6)
	vbox.add_child(music_box)

	_music_track_label = Label.new()
	_music_track_label.text = "🎵 " + AudioManager.get_soundtrack_title()
	_music_track_label.add_theme_font_size_override("font_size", 11)
	_music_track_label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 0.95))
	music_box.add_child(_music_track_label)

	var next_track_btn := Button.new()
	next_track_btn.text = "⏭️ Next"
	next_track_btn.custom_minimum_size = Vector2(58, 22)
	next_track_btn.pressed.connect(func():
		AudioManager.next_soundtrack()
		_update_music_ui()
	)
	music_box.add_child(next_track_btn)

	_music_mute_btn = Button.new()
	_music_mute_btn.text = "🔇" if AudioManager.is_music_muted else "🔊"
	_music_mute_btn.custom_minimum_size = Vector2(32, 22)
	_music_mute_btn.pressed.connect(func():
		AudioManager.set_music_muted(not AudioManager.is_music_muted)
		_update_music_ui()
	)
	music_box.add_child(_music_mute_btn)

	var hint := Label.new()
	hint.text = "Press ESC to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15, 0.95))
	vbox.add_child(hint)

# -- Input ---------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

# -- Public API ----------------------------------------------------------------
func toggle() -> void:
	if _visible:
		_hide_menu()
	else:
		_show_menu()

func show_menu() -> void:
	_show_menu()

func hide_menu() -> void:
	_hide_menu()

# -- Internals -----------------------------------------------------------------
func _show_menu() -> void:
	_visible = true
	visible  = true
	get_tree().paused = true
	AudioManager.play_ui("pause")
	_update_music_ui()

	_panel.pivot_offset = Vector2(215.0, 285.0)
	_panel.scale    = Vector2(0.90, 0.90)
	_panel.modulate = Color(1, 1, 1, 0)
	_dim.color      = Color(0, 0, 0, 0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale",    Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "modulate", Color.WHITE, 0.18)
	tw.tween_property(_dim,   "color",    BG_COLOR, 0.18)

func _update_music_ui() -> void:
	if _music_track_label and is_instance_valid(_music_track_label):
		_music_track_label.text = "🎵 " + AudioManager.get_soundtrack_title()
	if _music_mute_btn and is_instance_valid(_music_mute_btn):
		_music_mute_btn.text = "🔇" if AudioManager.is_music_muted else "🔊"

func _hide_menu() -> void:
	_visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale",    Vector2(0.90, 0.90), 0.14).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "modulate", Color(1, 1, 1, 0),   0.14)
	tw.tween_property(_dim,   "color",    Color(0, 0, 0, 0),   0.14)
	tw.chain().tween_callback(func():
		visible = false
		get_tree().paused = false
	)

# -- Button callbacks ----------------------------------------------------------
func _on_records() -> void:
	var panel = get_tree().get_first_node_in_group("leaderboard_panel")
	if panel:
		if panel.has_method("open"):
			panel.open()
		elif panel.has_method("toggle"):
			panel.toggle()

func _on_backlog() -> void:
	var panel = get_tree().get_first_node_in_group("backlog_panel")
	if panel:
		if panel.has_method("open"):
			panel.open()
		elif panel.has_method("toggle"):
			panel.toggle()

func _on_debug_console() -> void:
	_hide_menu()
	var admin = get_tree().root.find_child("AdminPanel", true, false)
	if admin:
		if admin.has_method("open"):
			admin.open()
		else:
			admin.visible = true

func _on_resume() -> void:
	_hide_menu()
	resumed.emit()

func _on_save_game() -> void:
	var modal = SaveLoadModalScript.new(SaveLoadModalScript.Mode.SAVE)
	get_tree().root.add_child(modal)

func _on_load_game() -> void:
	var modal = SaveLoadModalScript.new(SaveLoadModalScript.Mode.LOAD)
	get_tree().root.add_child(modal)

func _on_main_menu() -> void:
	get_tree().paused = false
	quit_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

# -- Helpers -------------------------------------------------------------------
func _make_gold_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal",  preload("res://assets/sprites/hud/Buttons/GoldButton/Goldbutton.tres"))
	btn.add_theme_stylebox_override("hover",   preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonHover.tres"))
	btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/GoldButton/GoldbuttonPresesd.tres"))
	btn.add_theme_color_override("font_color", Color(0.20, 0.12, 0.06, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02, 1.0))
	return btn

func _make_brown_button(label_text: String, text_color: Color = Color(0.96, 0.92, 0.84, 1.0)) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 38)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_stylebox_override("normal",  preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButton.tres"))
	btn.add_theme_stylebox_override("hover",   preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonHover.tres"))
	btn.add_theme_stylebox_override("pressed", preload("res://assets/sprites/hud/Buttons/Brownbutton/BrownButtonPressed.tres"))
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
	return btn
